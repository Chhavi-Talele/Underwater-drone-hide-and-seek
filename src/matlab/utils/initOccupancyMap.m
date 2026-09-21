function omap = initOccupancyMap(resolution)
%INITOCCUPANCYMAP  Load and prepare the 3-D occupancy map from reference data.
%
%   omap = initOccupancyMap()        loads high-res map with default resolution
%   omap = initOccupancyMap(res)     loads high-res map with specified resolution
%
%   The function locates the reference project's UUVSceneHighResMap.mat file
%   relative to this utils/ directory, loads the occupancy map, raises the
%   FreeThreshold to OccupiedThreshold (so free cells are truly free), and
%   inflates obstacles by 1 metre to add a safety margin.
%
%   Output
%   ------
%   omap : occupancyMap3D object ready for collision checking and path planning

    if nargin < 1
        resolution = 1;   % metres per cell (default)
    end

    % ------------------------------------------------------------------ %
    %  Locate the reference map file (relative to this utils/ folder)     %
    % ------------------------------------------------------------------ %
    thisDir   = fileparts(mfilename('fullpath'));
    refDir    = fullfile(thisDir, '..', '..', '..', ...
                         'reference_auv', 'Source', 'Planning');
    refDir    = what(refDir).path;   % resolve to absolute canonical path

    highResFile = fullfile(refDir, 'UUVSceneHighResMap.mat');
    lowResFile  = fullfile(refDir, 'UUVSceneLowResMap3.mat');

    if exist(highResFile, 'file')
        mapFile = highResFile;
    elseif exist(lowResFile, 'file')
        mapFile = lowResFile;
        warning('initOccupancyMap:fallback', ...
            'High-res map not found; falling back to low-res map.');
    else
        error('initOccupancyMap:notFound', ...
            'Cannot find occupancy map .mat files in:\n  %s', refDir);
    end

    % ------------------------------------------------------------------ %
    %  Load map                                                            %
    % ------------------------------------------------------------------ %
    data = load(mapFile, 'omap');
    omap = data.omap;

    % ------------------------------------------------------------------ %
    %  Configure thresholds and inflate obstacles                          %
    % ------------------------------------------------------------------ %
    omap.FreeThreshold = omap.OccupiedThreshold;  % collapse ambiguous to free
    inflate(omap, 1);                              % 1-metre safety buffer

    fprintf('[initOccupancyMap] Loaded: %s\n', mapFile);
    fprintf('  Resolution : %.2f m/cell\n', omap.Resolution);
    fprintf('  X bounds   : [%.1f, %.1f] m\n', omap.XWorldLimits);
    fprintf('  Y bounds   : [%.1f, %.1f] m\n', omap.YWorldLimits);
    fprintf('  Z bounds   : [%.1f, %.1f] m\n', omap.ZWorldLimits);
end
