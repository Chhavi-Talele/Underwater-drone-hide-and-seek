classdef SeekerAUV < AUVAgent
%SEEKERUAV  Autonomous seeker drone for the Underwater Hide-and-Seek game.
%
%   Behaviour state machine:
%
%     SEARCH  →  (ping detected)  →  TRACK  →  (close enough)  →  PURSUE
%     PURSUE  →  (lost contact)   →  SEARCH
%     Any     →  (dist < CaptureRadius)      →  CAPTURED
%
%   Search phase  : lawnmower / spiral pattern over the environment
%   Track phase   : particle filter updated on each bearing measurement
%   Pursue phase  : RRT path to particle-filter estimate; replans every ReplanPeriod s
%
%   Usage
%   -----
%     env    = UnderwaterEnvironment();  env.init();
%     seeker = SeekerAUV(env);
%     seeker.Pose = [10 10 -20 0];
%     seeker.init();
%     seeker.step(dt, simTime, sonarResult);

    properties
        % Capture radius in metres — game won when dist < this
        CaptureRadius   (1,1) double = 8.0

        % Acoustic sonar model
        Sonar           AcousticSonarModel

        % Particle filter for Hider belief estimation
        PF              ParticleFilter

        % Current behaviour state: 'search' | 'track' | 'pursue'
        State           (1,:) char = 'search'

        % How many consecutive ticks without a detection before returning to search
        LostContactTicks    (1,1) double = 0
        LostContactLimit    (1,1) double = 30   % ticks

        % Elapsed time since last RRT replan
        TimeSinceReplan     (1,1) double = 0
        ReplanPeriod        (1,1) double = 5.0  % seconds

        % Search grid parameters
        SearchGridSpacing   (1,1) double = 30   % metres between lawnmower rows
        SearchDepths        (1,3) double = [-15, -40, -75]  % layers to sweep

        % Reference to path planner (auvPathPlanner from reference project)
        % Set by init() if Navigation Toolbox is available
        Planner

        % Whether RRT planner was successfully loaded
        PlannerAvailable (1,1) logical = false
    end

    properties (SetAccess = private)
        % Ordered list of search waypoints [Nx3]
        SearchWaypoints (:,3) double = zeros(0,3)

        % Estimated Hider position from particle filter [1x3]
        HiderEstimate   (1,3) double = [NaN NaN NaN]

        % Number of successful detections
        DetectionCount  (1,1) double = 0

        % Has init() been called?
        Ready           (1,1) logical = false
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = SeekerAUV(env)
        %SEEKERUAV  Constructor.
        %   env : UnderwaterEnvironment handle
            obj@AUVAgent(env);
            obj.Name     = 'Seeker';
            obj.Color    = [0.2 0.5 1.0];   % blue
            obj.MaxSpeed = 1.5;             % m/s
        end

        % -------------------------------------------------------------- %
        function init(obj)
        %INIT  Initialise planner, particle filter, and search pattern.
            if obj.Ready, return; end

            assert(~isempty(obj.Env) && obj.Env.Initialized, ...
                'SeekerAUV:init', 'Environment must be initialised first.');

            % Sonar model
            obj.Sonar = AcousticSonarModel(obj.Env);

            % Particle filter — uniform initial belief
            obj.PF = ParticleFilter(obj.Env.Bounds, 50);
            obj.PF.uniformInit();

            % Build lawnmower search pattern
            obj.SearchWaypoints = obj.buildLawnmower();
            obj.setWaypoints(obj.SearchWaypoints);

            % Try to load reference path planner
            obj.tryLoadPlanner();

            obj.State = 'search';
            obj.Ready = true;
            fprintf('[SeekerAUV] Initialised at pose [%.1f %.1f %.1f].\n', ...
                obj.Pose(1), obj.Pose(2), obj.Pose(3));
        end

        % -------------------------------------------------------------- %
        function step(obj, dt, simTime, sonarResult)
        %STEP  Advance Seeker one simulation timestep.
        %
        %   dt         : timestep (s)
        %   simTime    : elapsed game time (s)
        %   sonarResult: result struct from AcousticSonarModel.detect()

            if ~obj.Ready
                error('SeekerAUV:notReady', 'Call init() before step().');
            end

            % ---- Update particle filter with sonar measurement ----
            if nargin >= 4 && ~isempty(sonarResult) && sonarResult.detected
                obj.DetectionCount = obj.DetectionCount + 1;
                obj.LostContactTicks = 0;

                obj.PF.predict(dt, 1.0);
                obj.PF.update(sonarResult.bearing, sonarResult.elevation, obj.Pose);

                % Also update on ghost bearing (lower weight — multipath)
                if sonarResult.hasGhost
                    ghostResult = sonarResult;
                    ghostResult.bearing  = sonarResult.ghostBearing;
                    ghostResult.elevation = sonarResult.elevation + (rand()-0.5)*0.2;
                    % Partial weight update — ghost treated with less trust
                    obj.PF.update(ghostResult.bearing, ghostResult.elevation, obj.Pose);
                end

                obj.HiderEstimate = obj.PF.getEstimate()(1:3);

                % Transition state
                if strcmp(obj.State, 'search')
                    obj.State = 'track';
                    fprintf('[Seeker t=%.1fs] Ping detected → TRACK mode\n', simTime);
                end
            else
                % No ping this tick
                obj.PF.predict(dt, 1.0);
                obj.LostContactTicks = obj.LostContactTicks + 1;

                if obj.LostContactTicks > obj.LostContactLimit && ~strcmp(obj.State, 'search')
                    obj.State = 'search';
                    obj.setWaypoints(obj.SearchWaypoints);
                    fprintf('[Seeker t=%.1fs] Lost contact → SEARCH mode\n', simTime);
                end
            end

            % ---- State machine movement ----
            switch obj.State

                case 'search'
                    obj.followWaypoints(dt, simTime);
                    % Loop search pattern
                    if obj.Done
                        obj.setWaypoints(obj.SearchWaypoints);
                    end

                case 'track'
                    % Move toward estimate; replan periodically
                    obj.TimeSinceReplan = obj.TimeSinceReplan + dt;
                    if obj.TimeSinceReplan >= obj.ReplanPeriod || obj.Done
                        obj.planToEstimate(simTime);
                        obj.TimeSinceReplan = 0;
                        uncertainty = obj.PF.getPositionUncertainty();
                        if uncertainty < 25
                            obj.State = 'pursue';
                            fprintf('[Seeker t=%.1fs] Confident (σ=%.1fm) → PURSUE mode\n', ...
                                simTime, uncertainty);
                        end
                    end
                    obj.followWaypoints(dt, simTime);

                case 'pursue'
                    % Aggressive pursuit — replan more frequently
                    obj.TimeSinceReplan = obj.TimeSinceReplan + dt;
                    if obj.TimeSinceReplan >= obj.ReplanPeriod/2 || obj.Done
                        obj.planToEstimate(simTime);
                        obj.TimeSinceReplan = 0;
                    end
                    obj.followWaypoints(dt, simTime);
            end
        end

        % -------------------------------------------------------------- %
        function s = getState(obj)
        %GETSTATE  Return state struct for logging / visualisation.
            s.pose          = obj.Pose;
            s.state         = obj.State;
            s.hiderEstimate = obj.HiderEstimate;
            s.detections    = obj.DetectionCount;
            s.uncertainty   = obj.PF.getPositionUncertainty();
            s.particles     = obj.PF.Particles;
            s.weights       = obj.PF.Weights;
        end

    end % public methods

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function wp = buildLawnmower(obj)
        %BUILDLAWNMOWER  Generate a 3-layer lawnmower search pattern.
            B   = obj.Env.Bounds;
            spacing = obj.SearchGridSpacing;
            depths  = obj.SearchDepths;

            wp = [];
            for d = depths
                xRange = B.X(1)+10 : spacing : B.X(2)-10;
                flip   = false;
                for xi = 1:length(xRange)
                    x = xRange(xi);
                    if flip
                        yVals = [B.Y(2)-10, B.Y(1)+10];
                    else
                        yVals = [B.Y(1)+10, B.Y(2)-10];
                    end
                    wp = [wp; x, yVals(1), d; x, yVals(2), d]; %#ok<AGROW>
                    flip = ~flip;
                end
            end
        end

        % -------------------------------------------------------------- %
        function planToEstimate(obj, ~)
        %PLANTOEESTIMATE  Set waypoints toward current particle filter estimate.
            est = obj.PF.getEstimate();
            if any(isnan(est(1:3)))
                return;
            end

            target = est(1:3);

            % Use straight-line waypoints (RRT fallback if planner unavailable)
            if obj.PlannerAvailable
                % RRT planning via reference auvPathPlanner
                try
                    startPose  = obj.Pose;
                    goalPose   = [target, 0];
                    waypoints  = obj.Planner.step(startPose, goalPose, false);
                    obj.setWaypoints(waypoints(:,1:3));
                    return;
                catch ME
                    warning('SeekerAUV:plannerFailed', ...
                        'RRT failed (%s); using straight-line.', ME.message);
                end
            end

            % Simple straight-line with intermediate points
            nPts = max(3, round(norm(target - obj.Pose(1:3)) / 20));
            t    = linspace(0,1,nPts)';
            lineWP = obj.Pose(1:3) + t .* (target - obj.Pose(1:3));
            obj.setWaypoints(lineWP);
        end

        % -------------------------------------------------------------- %
        function tryLoadPlanner(obj)
        %TRYLOADPLANNER  Attempt to load reference auvPathPlanner.
            refDir = fullfile(fileparts(mfilename('fullpath')), ...
                '..', '..', 'reference_auv', 'Source', 'Planning');
            refDir = fullfile(refDir);   % do NOT use what() — might not be on path yet
            if isfolder(refDir)
                addpath(refDir);
            end

            try
                p = auvPathPlanner();
                setup(p);
                obj.Planner = p;
                obj.PlannerAvailable = true;
                fprintf('[SeekerAUV] Reference auvPathPlanner loaded successfully.\n');
            catch
                obj.PlannerAvailable = false;
                fprintf('[SeekerAUV] auvPathPlanner unavailable; using straight-line planner.\n');
            end
        end

    end % private methods

end % classdef
