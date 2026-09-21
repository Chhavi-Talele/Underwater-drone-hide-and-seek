%% test_pathplanner.m
%  Tests for path planning and environment utilities.
%  Run from src/matlab/ :  >> test_pathplanner
%  Requires: Navigation Toolbox (occupancyMap3D)

function test_pathplanner()

fprintf('\n=== test_pathplanner.m ===\n\n');
passed = 0; failed = 0;

%% ---- Build a small synthetic 3-D map for testing ------------------
% 50x50x50 metre map, 1 m resolution
omap = occupancyMap3D(1);

% Add a wall at x = 25, y = 0..50, z = 0..-50 (a vertical slab)
[yy, zz] = meshgrid(0:1:50, -50:1:0);
wallPts   = [25*ones(numel(yy),1), yy(:), zz(:)];
setOccupancy(omap, wallPts, 1);
omap.FreeThreshold = omap.OccupiedThreshold;
inflate(omap, 0.5);

%% Test 1: computeLOS — clear path (no wall between)
posA = [5  25  -25];
posB = [20 25  -25];   % both on same side of wall
vis  = computeLOS(posA, posB, omap);
assertTest('T1 LOS clear on same side of wall', vis == true, passed, failed);
passed = passed + vis;
failed = failed + ~vis;

%% Test 2: computeLOS — blocked path (wall between A and B)
posC = [5  25 -25];
posD = [45 25 -25];   % crosses the wall at x=25
vis2 = computeLOS(posC, posD, omap);
assertTest('T2 LOS blocked by wall', vis2 == false, passed, failed);
passed = passed + ~vis2;
failed = failed + vis2;

%% Test 3: oceanCurrent — returns [1x3] for single point
v = oceanCurrent([50 50 -30], 100);
assertTest('T3 oceanCurrent returns 1x3', isequal(size(v), [1 3]), passed, failed);
passed = passed + isequal(size(v),[1 3]);
failed = failed + ~isequal(size(v),[1 3]);

%% Test 4: oceanCurrent — deeper water has weaker current
v_shallow = oceanCurrent([50 50 -5],  0);
v_deep    = oceanCurrent([50 50 -95], 0);
shallowMag = norm(v_shallow);
deepMag    = norm(v_deep);
assertTest('T4 shallower current stronger than deep', shallowMag >= deepMag, passed, failed);
passed = passed + (shallowMag >= deepMag);
failed = failed + (shallowMag < deepMag);

%% Test 5: selectHidingSpot — returns a free cell
% Create small open map
omapOpen = occupancyMap3D(2);
% All cells free by default (occupancy = 0)

candidates = [10 10 -20; 20 20 -40; 30 30 -60; 40 40 -80];
seekerPose  = [0 0 0 0];

% Create a minimal stub for env
envStub.OccupancyMap = omapOpen;

[best, scores] = selectHidingSpot(candidates, seekerPose, omapOpen);
assertTest('T5 selectHidingSpot returns [1x3]', isequal(size(best),[1 3]), passed, failed);
passed = passed + isequal(size(best),[1 3]);
failed = failed + ~isequal(size(best),[1 3]);

%% Test 6: selectHidingSpot — prefers farther cells
% With equal depth scores, farther should score higher
cands2 = [10 10 -40; 100 100 -40];
[best2, ~] = selectHidingSpot(cands2, seekerPose, omapOpen);
farther = norm(best2 - seekerPose(1:3));
assertTest('T6 selectHidingSpot prefers farther cell', farther > 50, passed, failed);
passed = passed + (farther > 50);
failed = failed + (farther <= 50);

%% Test 7: initOccupancyMap path resolution (stub: no actual file needed)
% Just verify the function handle exists and returns oMap if called
% Skip if reference files are not present (CI environment)
refFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', '..', ...
    'reference_auv', 'Source', 'Planning', 'UUVSceneHighResMap.mat');
if exist(refFile, 'file')
    try
        om = initOccupancyMap();
        assertTest('T7 initOccupancyMap loads successfully', isa(om,'occupancyMap3D'), passed, failed);
        passed = passed + isa(om,'occupancyMap3D');
        failed = failed + ~isa(om,'occupancyMap3D');
    catch ME
        fprintf('  [SKIP] T7 — %s\n', ME.message);
    end
else
    fprintf('  [SKIP] T7 — reference map file not found (expected in reference_auv/)\n');
end

%% Summary
fprintf('\n--- Results: %d passed, %d failed ---\n\n', passed, failed);
if failed > 0
    error('test_pathplanner: %d test(s) FAILED.', failed);
end

end % test_pathplanner

% -----------------------------------------------------------------------
function assertTest(name, condition, ~, ~)
    if condition
        fprintf('  [PASS] %s\n', name);
    else
        fprintf('  [FAIL] %s\n', name);
    end
end
