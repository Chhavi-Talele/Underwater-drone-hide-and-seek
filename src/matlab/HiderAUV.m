classdef HiderAUV < AUVAgent
%HIDERUAV  Autonomous hider drone for the Underwater Hide-and-Seek game.
%
%   Behaviour state machine:
%
%     HIDE   — navigate to best hiding spot (terrain-occluded, far, mid-depth)
%     SILENT — stop pinging; drift slowly to avoid acoustic detection
%     EVADE  — emergency dash when Seeker is estimated too close
%
%   Transitions:
%     HIDE  →  (estimated Seeker dist < SilenceRadius)  →  SILENT
%     SILENT → (reached hiding spot AND Seeker far)     →  HIDE
%     Any   →  (estimated Seeker dist < EvadeRadius)    →  EVADE
%     EVADE → (Seeker dist > EvadeRadius * 1.5)         →  HIDE
%
%   The Hider does NOT have a sonar — it infers Seeker proximity only from
%   the game state passed in through step().
%
%   Usage
%   -----
%     env   = UnderwaterEnvironment(); env.init();
%     hider = HiderAUV(env);
%     hider.Pose = [180 180 -55 pi];
%     hider.init();
%     hider.step(dt, simTime, seekerPose);   % seekerPose = best available estimate

    properties
        % Distance at which Hider enters acoustic-silence mode (m)
        SilenceRadius   (1,1) double = 60.0

        % Distance at which Hider enters emergency evasion mode (m)
        EvadeRadius     (1,1) double = 25.0

        % Normal speed (m/s)
        NormalSpeed     (1,1) double = 1.0

        % Evasion speed (m/s)
        EvasionSpeed    (1,1) double = 2.5

        % How often (s) the Hider re-evaluates its hiding spot
        RehideInterval  (1,1) double = 30.0

        % Whether acoustic pinging is currently suppressed
        PingSuppressed  (1,1) logical = false

        % Current behaviour state: 'hide' | 'silent' | 'evade'
        State           (1,:) char = 'hide'

        % Number of terrain-occluded candidates to evaluate each re-hide
        NCandidates     (1,1) double = 50
    end

    properties (SetAccess = private)
        % Current hiding target [1x3]
        HidingTarget    (1,3) double = [NaN NaN NaN]

        % Time since last hiding-spot evaluation
        TimeSinceRehide (1,1) double = 0

        % Seeker's last known / estimated position (given externally)
        SeekerEstimate  (1,3) double = [NaN NaN NaN]

        % Number of times Hider has successfully evaded
        EvasionCount    (1,1) double = 0

        % Has init() been called?
        Ready           (1,1) logical = false
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = HiderAUV(env)
        %HIDERUAV  Constructor.
        %   env : UnderwaterEnvironment handle
            obj@AUVAgent(env);
            obj.Name     = 'Hider';
            obj.Color    = [1.0 0.3 0.2];   % red-orange
            obj.MaxSpeed = obj.NormalSpeed;
        end

        % -------------------------------------------------------------- %
        function init(obj)
        %INIT  Initialise hiding strategy.
            if obj.Ready, return; end

            assert(~isempty(obj.Env) && obj.Env.Initialized, ...
                'HiderAUV:init', 'Environment must be initialised first.');

            % Pick an initial hiding spot
            obj.chooseHidingSpot([0 0 0 0]);   % Seeker start unknown → use origin
            obj.State = 'hide';
            obj.Ready = true;
            fprintf('[HiderAUV] Initialised at pose [%.1f %.1f %.1f].\n', ...
                obj.Pose(1), obj.Pose(2), obj.Pose(3));
        end

        % -------------------------------------------------------------- %
        function step(obj, dt, simTime, seekerPose)
        %STEP  Advance Hider one simulation timestep.
        %
        %   dt         : timestep (s)
        %   simTime    : elapsed game time (s)
        %   seekerPose : [1x4] Seeker's pose (as known to game orchestrator)

            if ~obj.Ready
                error('HiderAUV:notReady', 'Call init() before step().');
            end

            if nargin >= 4 && ~isempty(seekerPose)
                obj.SeekerEstimate = seekerPose(1:3);
            end

            seekerDist = norm(obj.Pose(1:3) - obj.SeekerEstimate);

            % ---- Acoustic silence management ----
            obj.PingSuppressed = (seekerDist < obj.SilenceRadius);

            % ---- State transitions ----
            if seekerDist < obj.EvadeRadius
                if ~strcmp(obj.State, 'evade')
                    obj.EvasionCount = obj.EvasionCount + 1;
                    obj.MaxSpeed     = obj.EvasionSpeed;
                    obj.State        = 'evade';
                    fprintf('[Hider t=%.1fs] Seeker %.1fm away → EVADE!\n', ...
                        simTime, seekerDist);
                    obj.chooseEvasionTarget();
                end
            elseif seekerDist < obj.SilenceRadius
                if strcmp(obj.State, 'hide')
                    obj.State = 'silent';
                    fprintf('[Hider t=%.1fs] Seeker %.1fm → SILENT mode\n', ...
                        simTime, seekerDist);
                end
            else
                if strcmp(obj.State, 'evade') || strcmp(obj.State, 'silent')
                    obj.MaxSpeed = obj.NormalSpeed;
                    obj.State    = 'hide';
                    obj.chooseHidingSpot(seekerPose);
                    fprintf('[Hider t=%.1fs] Seeker retreated → HIDE mode\n', simTime);
                end
            end

            % ---- Periodic re-hide evaluation ----
            obj.TimeSinceRehide = obj.TimeSinceRehide + dt;
            if obj.TimeSinceRehide >= obj.RehideInterval && strcmp(obj.State, 'hide')
                obj.chooseHidingSpot(seekerPose);
                obj.TimeSinceRehide = 0;
            end

            % ---- Movement ----
            switch obj.State
                case 'hide'
                    obj.followWaypoints(dt, simTime);
                    % If reached hiding spot, stop and stay put (minimal drift)
                    if obj.Done
                        obj.drift(dt, simTime);
                    end

                case 'silent'
                    % Slow drift — stay hidden, minimal movement
                    obj.MaxSpeed = 0.3;
                    obj.drift(dt, simTime);

                case 'evade'
                    obj.followWaypoints(dt, simTime);
                    if obj.Done
                        % Reached evasion target — re-evaluate
                        obj.chooseEvasionTarget();
                    end
            end
        end

        % -------------------------------------------------------------- %
        function suppressed = isPingSuppressed(obj)
        %ISPINGSUPPRESSED  Returns true when the Hider has silenced its pings.
            suppressed = obj.PingSuppressed;
        end

        % -------------------------------------------------------------- %
        function s = getState(obj)
        %GETSTATE  Return state struct for logging / visualisation.
            s.pose         = obj.Pose;
            s.state        = obj.State;
            s.hidingTarget = obj.HidingTarget;
            s.pingSuppressed = obj.PingSuppressed;
            s.evasions     = obj.EvasionCount;
        end

    end % public methods

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function chooseHidingSpot(obj, seekerPose)
        %CHOOSEHIDINGSPOT  Select best hiding spot from pre-sampled candidates.
            candidates = obj.Env.getHidingCandidates(seekerPose, obj.NCandidates);
            if isempty(candidates)
                return;
            end

            [bestPt, ~] = selectHidingSpot(candidates, seekerPose, ...
                              obj.Env.OccupancyMap);

            obj.HidingTarget = bestPt;

            % Straight-line waypoints to hiding spot
            nPts = max(4, round(norm(bestPt - obj.Pose(1:3)) / 15));
            t    = linspace(0, 1, nPts)';
            lineWP = obj.Pose(1:3) + t .* (bestPt - obj.Pose(1:3));
            obj.setWaypoints(lineWP);
        end

        % -------------------------------------------------------------- %
        function chooseEvasionTarget(obj)
        %CHOOSEEVASIONTARGET  Sprint to a point far from the Seeker.
            candidates = obj.Env.getHidingCandidates(obj.Pose, 30);
            if isempty(candidates)
                return;
            end

            if ~any(isnan(obj.SeekerEstimate))
                % Maximise distance FROM seeker
                dists = vecnorm(candidates - obj.SeekerEstimate, 2, 2);
                [~, idx] = max(dists);
                target = candidates(idx,:);
            else
                % No seeker info — random deep candidate
                target = candidates(randi(size(candidates,1)), :);
            end

            obj.HidingTarget = target;
            nPts = max(3, round(norm(target - obj.Pose(1:3)) / 15));
            t    = linspace(0,1,nPts)';
            lineWP = obj.Pose(1:3) + t .* (target - obj.Pose(1:3));
            obj.setWaypoints(lineWP);
        end

        % -------------------------------------------------------------- %
        function drift(obj, dt, simTime)
        %DRIFT  Minimal random movement when hiding or being silent.
            % Small perturbation in current direction
            perturbAngle = (rand()-0.5) * pi/6;
            hdg = obj.Pose(4) + perturbAngle;
            driftTarget = obj.Pose(1:3) + 5 * [cos(hdg), sin(hdg), 0];
            driftTarget  = obj.clampToBounds(driftTarget);
            obj.moveTo(driftTarget, dt, simTime);
        end

    end % private methods

end % classdef
