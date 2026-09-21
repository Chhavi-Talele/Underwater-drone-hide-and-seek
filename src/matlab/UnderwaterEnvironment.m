classdef UnderwaterEnvironment < handle
%UNDERWATERENVIRONMENT  Shared simulation world for the Hide-and-Seek game.
%
%   Manages:
%     - 3-D occupancy map (loaded from reference project)
%     - Depth zone classification
%     - Ocean current field
%     - LOS (line-of-sight) queries
%     - Candidate hiding-spot generation
%
%   Usage
%   -----
%     env = UnderwaterEnvironment();
%     env.init();
%     env.plotEnvironment();
%
%   Coordinate frame: ENU  (Z negative = underwater)
%     Depth zones:
%       Shallow  : Z in  [0,   -20)  m
%       Mid      : Z in  [-20, -60)  m
%       Deep     : Z in  [-60, -100] m

    properties (SetAccess = private)
        % 3-D occupancy map (occupancyMap3D)
        OccupancyMap

        % Spatial bounds as struct with fields X, Y, Z each [min max]
        Bounds struct

        % Ocean current parameters (passed to oceanCurrent.m)
        CurrentParams struct

        % Pre-sampled free-space candidate positions [Nx3] for Hider AI
        FreeCandidates (:,3) double

        % Has init() been called?
        Initialized (1,1) logical = false
    end

    properties (Constant)
        % Depth zone boundaries in metres (ENU, so negative)
        DEPTH_SHALLOW = [0,   -20]
        DEPTH_MID     = [-20, -60]
        DEPTH_DEEP    = [-60, -100]

        % Number of candidate hiding spots to pre-sample
        N_CANDIDATES = 300
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = UnderwaterEnvironment(currentParams)
        %UNDERWATERENVIRONMENT  Constructor.
        %   currentParams : (optional) struct for oceanCurrent.m
            if nargin < 1 || isempty(currentParams)
                obj.CurrentParams = struct();  % use defaults in oceanCurrent.m
            else
                obj.CurrentParams = currentParams;
            end
        end

        % -------------------------------------------------------------- %
        function init(obj)
        %INIT  Load occupancy map and pre-sample candidate positions.
            if obj.Initialized
                return;
            end

            fprintf('[UnderwaterEnvironment] Initialising...\n');

            % Add utils to path (in case called standalone)
            utilsDir = fullfile(fileparts(mfilename('fullpath')), 'utils');
            addpath(utilsDir);

            % Load and prepare occupancy map
            obj.OccupancyMap = initOccupancyMap();

            % Store bounds
            omap = obj.OccupancyMap;
            obj.Bounds = struct(...
                'X', omap.XWorldLimits, ...
                'Y', omap.YWorldLimits, ...
                'Z', omap.ZWorldLimits);

            % Pre-sample free candidate positions for Hider
            obj.FreeCandidates = obj.sampleFreeCells(obj.N_CANDIDATES);

            obj.Initialized = true;
            fprintf('[UnderwaterEnvironment] Ready. %d free candidates sampled.\n', ...
                size(obj.FreeCandidates, 1));
        end

        % -------------------------------------------------------------- %
        function v = getCurrent(obj, pos, simTime)
        %GETCURRENT  Ocean current velocity at position pos and time simTime.
        %   pos     : [1x3] or [Nx3]
        %   simTime : scalar
            if nargin < 3, simTime = 0; end
            v = oceanCurrent(pos, simTime, obj.CurrentParams);
        end

        % -------------------------------------------------------------- %
        function visible = isLOS(obj, posA, posB)
        %ISLOS  True if posA and posB have clear line-of-sight.
            visible = computeLOS(posA, posB, obj.OccupancyMap);
        end

        % -------------------------------------------------------------- %
        function free = isFree(obj, pos)
        %ISFREE  True if pos is in free (unoccupied) space.
        %   pos : [1x3] or [Nx3]
            occ  = checkOccupancy(obj.OccupancyMap, pos);
            free = (occ == 0);
        end

        % -------------------------------------------------------------- %
        function zone = depthZone(~, z)
        %DEPTHZONE  Returns depth zone string for a given Z coordinate.
        %   zone : 'shallow' | 'mid' | 'deep' | 'surface'
            if z >= -20
                zone = 'shallow';
            elseif z >= -60
                zone = 'mid';
            elseif z >= -100
                zone = 'deep';
            else
                zone = 'abyss';
            end
        end

        % -------------------------------------------------------------- %
        function pts = getHidingCandidates(obj, seekerPose, n)
        %GETHIDINGCANDIDATES  Return n pre-sampled free candidates for hiding.
        %   seekerPose : [1x4] seeker's current pose (used to exclude nearby)
        %   n          : how many candidates to return (default: all)
            if nargin < 3 || isempty(n)
                pts = obj.FreeCandidates;
                return;
            end
            % Filter out cells too close to seeker (< 30 m)
            dists = vecnorm(obj.FreeCandidates - seekerPose(1:3), 2, 2);
            farPts = obj.FreeCandidates(dists > 30, :);
            if isempty(farPts)
                farPts = obj.FreeCandidates;
            end
            idx = randperm(size(farPts,1), min(n, size(farPts,1)));
            pts = farPts(idx, :);
        end

        % -------------------------------------------------------------- %
        function plotEnvironment(obj, ax)
        %PLOTENVIRONMENT  Visualise the occupancy map in an axes handle.
            if nargin < 2 || isempty(ax)
                figure('Name', 'Underwater Environment');
                ax = axes;
            end
            show(obj.OccupancyMap, 'Parent', ax);
            title(ax, 'Underwater Environment — Occupancy Map');
            xlabel(ax, 'X (m)'); ylabel(ax, 'Y (m)'); zlabel(ax, 'Z (m)');
            colormap(ax, 'parula');
        end

    end % public methods

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function pts = sampleFreeCells(obj, n)
        %SAMPLEFREECELLS  Monte-Carlo sample free positions from the map.
            omap = obj.OccupancyMap;
            xl = omap.XWorldLimits;
            yl = omap.YWorldLimits;
            zl = omap.ZWorldLimits;

            pts    = zeros(0, 3);
            budget = n * 20;   % try up to 20x more samples to find n free cells
            count  = 0;

            while size(pts,1) < n && count < budget
                % Uniform random sample in map bounds
                x = xl(1) + rand * diff(xl);
                y = yl(1) + rand * diff(yl);
                % Bias toward underwater depth range (-100 to 0)
                z = -rand * 100;

                if z < zl(1), z = zl(1); end
                if z > zl(2), z = zl(2); end

                if checkOccupancy(omap, [x y z]) == 0
                    pts(end+1, :) = [x y z]; %#ok<AGROW>
                end
                count = count + 1;
            end

            if size(pts,1) < n
                warning('UnderwaterEnvironment:fewFreeCells', ...
                    'Only found %d free cells (requested %d).', size(pts,1), n);
            end
        end

    end % private methods

end % classdef
