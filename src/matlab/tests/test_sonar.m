%% test_sonar.m
%  Unit tests for AcousticSonarModel
%  Run from src/matlab/ :  >> test_sonar
%  Requires: Navigation Toolbox (for occupancyMap3D)

function test_sonar()

fprintf('\n=== test_sonar.m ===\n\n');
passed = 0; failed = 0;

%% ---- Setup minimal environment ------------------------------------
% Use a small empty map so we can control occupancy
omap = occupancyMap3D(1);
env  = UnderwaterEnvStub(omap);

sonar = AcousticSonarModel(env);
sonar.Range         = 125;
sonar.PingInterval  = 10;
sonar.PingBandwidth = 1;

seekerPose = [0 0 0 0];

%% Test 1: Detection at close range (t = 0 → inside ping window)
hiderPose = [50 0 0 0];
result = sonar.detect(hiderPose, seekerPose, 0.0);
assertTest('T1 close range detected', result.detected == true, passed, failed);
passed = passed + result.detected;
failed = failed + ~result.detected;

%% Test 2: No detection at t = 5 s (outside PingBandwidth=1 window)
result = sonar.detect(hiderPose, seekerPose, 5.0);
assertTest('T2 no ping outside window', result.detected == false, passed, failed);
passed = passed + ~result.detected;
failed = failed + result.detected;

%% Test 3: No detection beyond range (dist = 126 m > range 125 m)
hiderFar = [126 0 0 0];
result = sonar.detect(hiderFar, seekerPose, 0.0);
assertTest('T3 beyond range not detected', result.detected == false, passed, failed);
passed = passed + ~result.detected;
failed = failed + result.detected;

%% Test 4: Boundary detection at dist = 124 m (just inside range)
hiderEdge = [124 0 0 0];
result = sonar.detect(hiderEdge, seekerPose, 0.0);
assertTest('T4 boundary range detected', result.detected == true, passed, failed);
passed = passed + result.detected;
failed = failed + ~result.detected;

%% Test 5: Bearing is reasonable (within 90° of true direction)
% True bearing of hider at [50 50 0] from origin:
% atan2(50,50) = 45° in ENU convention
hiderDiag = [50 50 0 0];
result = sonar.detect(hiderDiag, seekerPose, 0.0);
if result.detected
    trueBearing = atan2(50, 50);
    if trueBearing <= 0, trueBearing = trueBearing + 2*pi; end
    bearingError = abs(mod(result.bearing - trueBearing + pi, 2*pi) - pi);
    assertTest('T5 bearing within 30°', bearingError < pi/6, passed, failed);
    passed = passed + (bearingError < pi/6);
    failed = failed + (bearingError >= pi/6);
else
    fprintf('  [SKIP] T5 — ping not detected for bearing test\n');
end

%% Test 6: LOS blocked → no detection
% Put an occupied voxel between hider and seeker
omapBlocked = occupancyMap3D(1);
setOccupancy(omapBlocked, [25 0 0], 1);
envBlocked = UnderwaterEnvStub(omapBlocked);
sonarBlocked = AcousticSonarModel(envBlocked);
sonarBlocked.Range = 125;
sonarBlocked.PingInterval = 10;
sonarBlocked.PingBandwidth = 1;

hiderPose = [50 0 0 0];
result = sonarBlocked.detect(hiderPose, seekerPose, 0.0);
assertTest('T6 LOS blocked → no detection', result.detected == false, passed, failed);
passed = passed + ~result.detected;
failed = failed + result.detected;

%% Summary
fprintf('\n--- Results: %d passed, %d failed ---\n\n', passed, failed);
if failed > 0
    error('test_sonar: %d test(s) FAILED.', failed);
end

end % test_sonar

% -----------------------------------------------------------------------
function assertTest(name, condition, ~, ~)
    if condition
        fprintf('  [PASS] %s\n', name);
    else
        fprintf('  [FAIL] %s\n', name);
    end
end

% -----------------------------------------------------------------------
% Minimal stub so we can test sonar without loading full maps
classdef UnderwaterEnvStub < handle
    properties
        OccupancyMap
        Initialized = true
        Bounds = struct('X',[0 250],'Y',[0 250],'Z',[-100 0])
    end
    methods
        function obj = UnderwaterEnvStub(omap)
            obj.OccupancyMap = omap;
        end
        function v = isLOS(obj, posA, posB)
            v = computeLOS(posA, posB, obj.OccupancyMap);
        end
    end
end
