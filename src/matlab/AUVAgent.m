classdef (Abstract) AUVAgent < handle
%AUVAGENT  Abstract base class for all AUV agents in the Hide-and-Seek game.
%
%   Both SeekerAUV and HiderAUV inherit from this class.  It provides:
%     - Common pose / velocity / trail state
%     - Abstract step() method that subclasses must implement
%     - Shared movement integration with ocean-current correction
%     - Path-following utilities
%
%   Frame convention: ENU (East-North-Up).
%     X = East (m),  Y = North (m),  Z = Up (m, negative = depth)
%
%   Usage
%   -----
%     % (Do not instantiate directly; use SeekerAUV or HiderAUV)
%     seeker = SeekerAUV(env);
%     seeker.Pose = [10 10 -20 0];
%     seeker.step(dt, simTime);

    % ------------------------------------------------------------------ %
    %  Public properties                                                   %
    % ------------------------------------------------------------------ %
    properties
        % Current pose  [x y z heading_rad]  (ENU, heading from +X CW)
        Pose        (1,4) double = [0 0 0 0]

        % Current velocity [vx vy vz] m/s (body frame, before current)
        Velocity    (1,3) double = [0 0 0]

        % Maximum speed in m/s (subclass sets in constructor)
        MaxSpeed    (1,1) double = 1.0

        % Waypoint queue  [Nx4] — each row is [x y z heading]
        Waypoints   (:,4) double = zeros(0,4)

        % Index into Waypoints of current target
        WaypointIdx (1,1) double = 1

        % Waypoint arrival tolerance in metres
        WaypointTol (1,1) double = 5.0

        % Whether agent has reached its final waypoint
        Done        (1,1) logical = false

        % Colour used in visualiser  [R G B] 0-1
        Color       (1,3) double = [0.5 0.5 0.5]

        % Name string for logging / display
        Name        (1,:) char   = 'AUVAgent'
    end

    % ------------------------------------------------------------------ %
    %  Read-only public (set internally)                                  %
    % ------------------------------------------------------------------ %
    properties (SetAccess = protected)
        % Position history  [Mx3] for trail visualisation
        Trail       (:,3) double = zeros(0,3)

        % Reference to shared UnderwaterEnvironment
        Env
    end

    % ------------------------------------------------------------------ %
    %  Abstract interface                                                  %
    % ------------------------------------------------------------------ %
    methods (Abstract)
        %STEP  Called each simulation tick.
        %   Subclass updates its Waypoints / decision logic and moves.
        %
        %   step(obj, dt, simTime)
        %     dt      – timestep in seconds
        %     simTime – elapsed game time in seconds
        step(obj, dt, simTime)

        %GETSTATE  Returns a struct summarising agent state for logging / vis.
        s = getState(obj)
    end

    % ------------------------------------------------------------------ %
    %  Concrete shared methods                                             %
    % ------------------------------------------------------------------ %
    methods

        function obj = AUVAgent(env)
        %AUVAGENT  Constructor — requires a shared UnderwaterEnvironment.
            if nargin > 0
                obj.Env = env;
            end
        end

        % -------------------------------------------------------------- %
        function moveTo(obj, targetPose, dt, simTime)
        %MOVETO  Steer the agent one timestep toward targetPose.
        %
        %   targetPose : [1x3] or [1x4] target [x y z] or [x y z hdg]

            target = targetPose(1:3);
            current = obj.Pose(1:3);

            % Direction vector
            delta = target - current;
            dist  = norm(delta);

            if dist < 1e-3
                return;   % already there
            end

            dir = delta / dist;

            % Desired speed (clamp to MaxSpeed)
            speed = min(obj.MaxSpeed, dist / dt);

            % Ocean current correction
            curr = oceanCurrent(current, simTime);

            % New velocity = desired movement + current
            obj.Velocity = speed * dir + curr;

            % Integrate position
            newPos = current + obj.Velocity * dt;

            % Clamp to map bounds
            newPos = obj.clampToBounds(newPos);

            % Update heading (2-D projection, XY plane)
            if norm(delta(1:2)) > 1e-3
                heading = atan2(delta(2), delta(1));
            else
                heading = obj.Pose(4);
            end

            obj.Pose = [newPos, heading];

            % Append to trail
            obj.Trail(end+1, :) = newPos;
        end

        % -------------------------------------------------------------- %
        function followWaypoints(obj, dt, simTime)
        %FOLLOWWAYPOINTS  Move one step along the current Waypoints queue.

            if isempty(obj.Waypoints) || obj.WaypointIdx > size(obj.Waypoints,1)
                obj.Done = true;
                return;
            end

            target = obj.Waypoints(obj.WaypointIdx, :);
            dist   = norm(obj.Pose(1:3) - target(1:3));

            if dist < obj.WaypointTol
                obj.WaypointIdx = obj.WaypointIdx + 1;
                if obj.WaypointIdx > size(obj.Waypoints, 1)
                    obj.Done = true;
                    return;
                end
                target = obj.Waypoints(obj.WaypointIdx, :);
            end

            obj.moveTo(target, dt, simTime);
        end

        % -------------------------------------------------------------- %
        function setWaypoints(obj, wp)
        %SETWAYPOINTS  Replace the waypoint queue and reset index.
        %   wp : [Nx3] or [Nx4] array of waypoints

            if size(wp, 2) == 3
                wp = [wp, zeros(size(wp,1), 1)];  % append dummy heading col
            end
            obj.Waypoints   = wp;
            obj.WaypointIdx = 1;
            obj.Done        = false;
        end

        % -------------------------------------------------------------- %
        function d = distanceTo(obj, otherPose)
        %DISTANCETO  Euclidean distance from this agent to another pose.
            d = norm(obj.Pose(1:3) - otherPose(1:3));
        end

    end % methods

    % ------------------------------------------------------------------ %
    %  Private helpers                                                     %
    % ------------------------------------------------------------------ %
    methods (Access = protected)

        function pos = clampToBounds(obj, pos)
        %CLAMPTOBOUNDS  Keep position inside map limits (if env available).
            if isempty(obj.Env) || isempty(obj.Env.OccupancyMap)
                return;
            end
            omap = obj.Env.OccupancyMap;
            xl   = omap.XWorldLimits;
            yl   = omap.YWorldLimits;
            zl   = omap.ZWorldLimits;
            pos(1) = max(xl(1), min(xl(2), pos(1)));
            pos(2) = max(yl(1), min(yl(2), pos(2)));
            pos(3) = max(zl(1), min(zl(2), pos(3)));
        end

    end

end % classdef
