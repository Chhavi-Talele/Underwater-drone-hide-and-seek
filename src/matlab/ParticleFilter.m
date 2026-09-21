classdef ParticleFilter < handle
%PARTICLEFILTER  SIR particle filter for Seeker's belief about Hider position.
%
%   Implements Sequential Importance Resampling (SIR) over a 4-D state:
%       [x  y  z  heading]
%
%   Measurement model: azimuth bearing + elevation from AcousticSonarModel.
%   Motion model: constant-velocity random walk with configurable process noise.
%
%   Usage
%   -----
%     pf = ParticleFilter(bounds, 50);
%     pf.init([100 100 -40 0]);       % seed near a guess
%     pf.predict(dt);
%     pf.update(bearing, elevation, seekerPose);
%     estimate = pf.getEstimate();    % [x y z heading]
%
%   Reference
%   ---------
%   Thrun, Burgard, Fox — "Probabilistic Robotics" (2005), Ch. 4

    properties
        % Number of particles
        N   (1,1) double = 50

        % Particles matrix  [N x 4]  (x, y, z, heading)
        Particles (:,4) double

        % Particle weights  [N x 1]  (normalised)
        Weights   (:,1) double

        % Process noise std devs [sigma_x, sigma_y, sigma_z, sigma_hdg] (m, m, m, rad)
        ProcessNoise (1,4) double = [3.0, 3.0, 1.5, 0.1]

        % Measurement noise std dev for bearing (rad)
        BearingNoiseSigma   (1,1) double = 7.5 * pi/180

        % Measurement noise std dev for elevation (rad)
        ElevationNoiseSigma (1,1) double = 3.0 * pi/180

        % Effective sample size ratio threshold for resampling (0–1)
        ResampleThreshold (1,1) double = 0.5

        % Map bounds struct with fields X, Y, Z  each [min max]
        Bounds struct
    end

    properties (SetAccess = private)
        % Estimated state (weighted mean)
        Estimate (1,4) double = [0 0 0 0]

        % Estimate covariance [4x4]
        Covariance (4,4) double = eye(4)

        % Number of times update() was called
        UpdateCount (1,1) double = 0
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = ParticleFilter(bounds, N)
        %PARTICLEFILTER  Constructor.
        %   bounds : struct with X,Y,Z [min max] fields (from env.Bounds)
        %   N      : number of particles (default 50)
            if nargin >= 1 && ~isempty(bounds)
                obj.Bounds = bounds;
            else
                obj.Bounds = struct('X',[0 250],'Y',[0 250],'Z',[-100 0]);
            end
            if nargin >= 2 && ~isempty(N)
                obj.N = N;
            end
            obj.uniformInit();
        end

        % -------------------------------------------------------------- %
        function uniformInit(obj)
        %UNIFORMINIT  Scatter particles uniformly across the map.
            B = obj.Bounds;
            obj.Particles = [ ...
                B.X(1) + rand(obj.N, 1) * diff(B.X), ...
                B.Y(1) + rand(obj.N, 1) * diff(B.Y), ...
                B.Z(1) + rand(obj.N, 1) * diff(B.Z), ...
                rand(obj.N, 1) * 2 * pi ];
            obj.Weights = ones(obj.N, 1) / obj.N;
        end

        % -------------------------------------------------------------- %
        function init(obj, seedPose, spreadSigma)
        %INIT  Seed particles near a known pose with Gaussian spread.
        %   seedPose   : [1x4] initial guess [x y z heading]
        %   spreadSigma: [1x4] spread std devs (default [30 30 15 0.5])
            if nargin < 3 || isempty(spreadSigma)
                spreadSigma = [30, 30, 15, 0.5];
            end
            noise = randn(obj.N, 4) .* spreadSigma;
            obj.Particles = seedPose + noise;
            obj.Particles = obj.clampParticles(obj.Particles);
            obj.Weights   = ones(obj.N, 1) / obj.N;
            obj.UpdateCount = 0;
        end

        % -------------------------------------------------------------- %
        function predict(obj, dt, speed)
        %PREDICT  Propagate particles forward with random-walk motion model.
        %   dt    : timestep (s)
        %   speed : expected Hider speed m/s (default 1.0)
            if nargin < 3, speed = 1.0; end

            % Random velocity perturbation
            sigma = obj.ProcessNoise;
            noise = randn(obj.N, 4) .* sigma * sqrt(dt);

            % Simple constant-velocity drift + noise
            dxy      = speed * dt;
            headings = obj.Particles(:,4);
            dx       = dxy * cos(headings) + noise(:,1);
            dy       = dxy * sin(headings) + noise(:,2);
            dz       = noise(:,3);
            dhdg     = noise(:,4);

            obj.Particles(:,1) = obj.Particles(:,1) + dx;
            obj.Particles(:,2) = obj.Particles(:,2) + dy;
            obj.Particles(:,3) = obj.Particles(:,3) + dz;
            obj.Particles(:,4) = obj.Particles(:,4) + dhdg;
            obj.Particles(:,4) = mod(obj.Particles(:,4), 2*pi);

            obj.Particles = obj.clampParticles(obj.Particles);
        end

        % -------------------------------------------------------------- %
        function update(obj, bearing, elevation, seekerPose)
        %UPDATE  Weight particles by acoustic measurement likelihood.
        %
        %   bearing    : measured azimuth (rad, 0–2π, ENU convention)
        %   elevation  : measured elevation angle (rad)
        %   seekerPose : [1x4] Seeker pose [x y z heading]

            posS = seekerPose(1:3);

            for i = 1:obj.N
                posP = obj.Particles(i, 1:3);

                dx = posP(1) - posS(1);
                dy = posP(2) - posS(2);
                dz = posP(3) - posS(3);
                r  = sqrt(dx^2 + dy^2);

                predAz  = atan2(dx, dy);
                if predAz <= 0, predAz = predAz + 2*pi; end
                predEl  = atan2(dz, r + 1e-9);

                % Angular residuals (wrapped)
                errAz = angDiff(bearing, predAz);
                errEl = elevation - predEl;

                % Gaussian likelihood
                likAz = exp(-0.5*(errAz / obj.BearingNoiseSigma)^2);
                likEl = exp(-0.5*(errEl / obj.ElevationNoiseSigma)^2);

                obj.Weights(i) = obj.Weights(i) * likAz * likEl;
            end

            % Normalise
            wsum = sum(obj.Weights);
            if wsum < 1e-300
                % Weight collapse — reinit uniformly
                obj.uniformInit();
            else
                obj.Weights = obj.Weights / wsum;
            end

            % Systematic resampling when ESS drops below threshold
            Neff = 1 / sum(obj.Weights.^2);
            if Neff < obj.ResampleThreshold * obj.N
                obj.resample();
            end

            obj.computeEstimate();
            obj.UpdateCount = obj.UpdateCount + 1;
        end

        % -------------------------------------------------------------- %
        function est = getEstimate(obj)
        %GETESTIMATE  Return weighted-mean particle estimate [x y z heading].
            est = obj.Estimate;
        end

        % -------------------------------------------------------------- %
        function cov = getCovariance(obj)
        %GETCOVARIANCE  Return 4x4 weighted covariance matrix.
            cov = obj.Covariance;
        end

        % -------------------------------------------------------------- %
        function uncertainty = getPositionUncertainty(obj)
        %GETPOSITIONUNCERTAINTY  RMS of x,y,z standard deviations (m).
            uncertainty = sqrt(trace(obj.Covariance(1:3,1:3)) / 3);
        end

    end % public methods

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function resample(obj)
        %RESAMPLE  Systematic resampling (O(N) unbiased).
            cumW = cumsum(obj.Weights);
            step = 1 / obj.N;
            u0   = rand * step;

            newParticles = zeros(obj.N, 4);
            j = 1;
            for i = 1:obj.N
                u = u0 + (i-1)*step;
                while j < obj.N && cumW(j) < u
                    j = j + 1;
                end
                newParticles(i,:) = obj.Particles(j,:);
            end
            obj.Particles = newParticles;
            obj.Weights   = ones(obj.N, 1) / obj.N;
        end

        % -------------------------------------------------------------- %
        function computeEstimate(obj)
        %COMPUTEESTIMATE  Weighted mean and covariance of particles.
            W = obj.Weights;
            P = obj.Particles;

            % Weighted mean (special handling for heading circular mean)
            mu    = sum(W .* P, 1);         % [1x4]
            sinH  = sum(W .* sin(P(:,4)));
            cosH  = sum(W .* cos(P(:,4)));
            mu(4) = atan2(sinH, cosH);
            obj.Estimate = mu;

            % Weighted covariance
            diff_p = P - mu;
            diff_p(:,4) = angDiff(P(:,4), mu(4));   % wrap heading diff
            obj.Covariance = (diff_p .* W)' * diff_p;
        end

        % -------------------------------------------------------------- %
        function P = clampParticles(obj, P)
        %CLAMPPARTICLES  Keep particles within map bounds.
            B = obj.Bounds;
            P(:,1) = max(B.X(1), min(B.X(2), P(:,1)));
            P(:,2) = max(B.Y(1), min(B.Y(2), P(:,2)));
            P(:,3) = max(B.Z(1), min(B.Z(2), P(:,3)));
        end

    end % private methods

end % classdef

% ---------------------------------------------------------------------------
function d = angDiff(a, b)
%ANGDIFF  Signed angle difference a - b, wrapped to (-π, π].
    d = mod(a - b + pi, 2*pi) - pi;
end
