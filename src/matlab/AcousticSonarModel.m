classdef AcousticSonarModel < handle
%ACOUSTICSONARMODEL  Physics-based acoustic sonar model for AUV Hide-and-Seek.
%
%   Extends the reference project's blackBox.m + phasedArraySonar.m with:
%     - LOS occlusion  (terrain blocking sound propagation)
%     - Gaussian bearing noise (σ = 7.5° azimuth, reference-matched)
%     - Multipath reflections (30% false-bearing probability)
%     - Depth attenuation (deeper = 20% faster signal decay)
%
%   Usage
%   -----
%     sonar = AcousticSonarModel(env);
%     result = sonar.detect(hiderPose, seekerPose, simTime);
%
%   Result struct fields
%   --------------------
%     .detected       logical  — true if ping was heard
%     .bearing        double   — azimuth to source (rad, ENU)
%     .elevation      double   — elevation angle (rad)
%     .signalLevel    double   — 0–100 signal strength
%     .isMultipath    logical  — true if this reading is a multipath ghost

    properties
        % Maximum acoustic range in metres (matches blackBox.m)
        Range           (1,1) double = 125

        % Ping interval in seconds (matches blackBox.m)
        PingInterval    (1,1) double = 10

        % Ping duration / bandwidth in seconds (matches blackBox.m)
        PingBandwidth   (1,1) double = 1

        % Azimuth bearing noise standard deviation (rad, matches reference ±15° → σ≈7.5°)
        BearingNoiseSigma   (1,1) double = 7.5 * pi/180

        % Elevation bearing noise std dev (rad)
        ElevationNoiseSigma (1,1) double = 3.0 * pi/180

        % Probability that a detected ping triggers a multipath ghost reading
        MultipathProbability (1,1) double = 0.30

        % Depth attenuation exponent factor (> 1 = faster falloff with depth)
        DepthAttenuationFactor (1,1) double = 1.20

        % Reference to shared UnderwaterEnvironment
        Env
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = AcousticSonarModel(env)
        %ACOUSTICSONARMODEL  Constructor.
        %   env : UnderwaterEnvironment handle
            if nargin > 0
                obj.Env = env;
            end
        end

        % -------------------------------------------------------------- %
        function result = detect(obj, hiderPose, seekerPose, simTime)
        %DETECT  Compute acoustic detection from Hider's ping at Seeker.
        %
        %   hiderPose  : [1x4] Hider [x y z heading]
        %   seekerPose : [1x4] Seeker [x y z heading]
        %   simTime    : scalar elapsed time (s)
        %
        %   Returns result struct (see class header).

            result = obj.emptyResult();

            posH = hiderPose(1:3);
            posS = seekerPose(1:3);

            % ---------------------------------------------------------- %
            % 1.  Is the Hider currently pinging?
            % ---------------------------------------------------------- %
            pingTime = mod(simTime, obj.PingInterval);
            if pingTime >= obj.PingBandwidth
                return;   % no ping this timestep
            end

            % ---------------------------------------------------------- %
            % 2.  Range check (base model from blackBox.m)
            % ---------------------------------------------------------- %
            dist = norm(posH - posS);
            if dist > obj.Range
                return;
            end

            % ---------------------------------------------------------- %
            % 3.  Depth attenuation
            %     Deeper source decays faster: effective range shrinks
            % ---------------------------------------------------------- %
            avgDepth = abs((posH(3) + posS(3)) / 2);
            depthPenalty = 1 + (avgDepth / 100) * (obj.DepthAttenuationFactor - 1);
            effectiveRange = obj.Range / depthPenalty;
            if dist > effectiveRange
                return;
            end

            % ---------------------------------------------------------- %
            % 4.  LOS check (terrain occlusion)
            % ---------------------------------------------------------- %
            if ~isempty(obj.Env)
                if ~obj.Env.isLOS(posH, posS)
                    return;  % terrain blocks acoustic path
                end
            end

            % ---------------------------------------------------------- %
            % 5.  Signal level (quadratic decay, matches blackBox.m)
            % ---------------------------------------------------------- %
            sigLevel = (effectiveRange^2 - dist^2) / effectiveRange^2 * 100;
            sigLevel = max(0, sigLevel);

            % ---------------------------------------------------------- %
            % 6.  Bearing computation (with noise)
            % ---------------------------------------------------------- %
            dx = posH(1) - posS(1);
            dy = posH(2) - posS(2);
            dz = posH(3) - posS(3);

            trueAzimuth   = atan2(dx, dy);    % matches reference convention
            if trueAzimuth <= 0
                trueAzimuth = trueAzimuth + 2*pi;
            end
            trueElevation = atan(dz / (sqrt(dx^2 + dy^2) + 1e-9));

            % Add Gaussian noise
            measAzimuth   = trueAzimuth   + obj.BearingNoiseSigma   * randn();
            measElevation = trueElevation + obj.ElevationNoiseSigma * randn();

            % Wrap azimuth to [0, 2π]
            measAzimuth = mod(measAzimuth, 2*pi);

            % ---------------------------------------------------------- %
            % 7.  Fill result
            % ---------------------------------------------------------- %
            result.detected    = true;
            result.bearing     = measAzimuth;
            result.elevation   = measElevation;
            result.signalLevel = sigLevel;
            result.isMultipath = false;

            % ---------------------------------------------------------- %
            % 8.  Multipath ghost (30% probability extra spurious return)
            % ---------------------------------------------------------- %
            if rand() < obj.MultipathProbability
                % Ghost bearing is mirrored + random offset
                ghostAzimuth = mod(trueAzimuth + pi + (rand()-0.5)*pi/4, 2*pi);
                result.ghostBearing = ghostAzimuth;
                result.hasGhost     = true;
            else
                result.ghostBearing = NaN;
                result.hasGhost     = false;
            end
        end

        % -------------------------------------------------------------- %
        function r = emptyResult(~)
        %EMPTYRESULT  Returns an empty (no-detection) result struct.
            r.detected    = false;
            r.bearing     = NaN;
            r.elevation   = NaN;
            r.signalLevel = 0;
            r.isMultipath = false;
            r.hasGhost    = false;
            r.ghostBearing = NaN;
        end

    end % methods

end % classdef
