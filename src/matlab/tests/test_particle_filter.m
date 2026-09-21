%% test_particle_filter.m
%  Unit tests for ParticleFilter
%  Run from src/matlab/ :  >> test_particle_filter
%  No toolbox dependencies — pure MATLAB maths.

function test_particle_filter()

fprintf('\n=== test_particle_filter.m ===\n\n');
passed = 0; failed = 0;

rng(42);   % reproducible

bounds = struct('X',[0 250],'Y',[0 250],'Z',[-100 0]);

%% Test 1: Construction — correct particle count
pf = ParticleFilter(bounds, 50);
assertTest('T1 particle count = 50', size(pf.Particles,1) == 50, passed, failed);
passed = passed + (size(pf.Particles,1)==50);
failed = failed + (size(pf.Particles,1)~=50);

%% Test 2: Weights sum to 1 after init
pf.uniformInit();
wsum = sum(pf.Weights);
assertTest('T2 weights sum to 1.0', abs(wsum - 1.0) < 1e-9, passed, failed);
passed = passed + (abs(wsum-1.0)<1e-9);
failed = failed + (abs(wsum-1.0)>=1e-9);

%% Test 3: predict() keeps particles in bounds
pf.uniformInit();
pf.predict(1.0, 1.0);
inX = all(pf.Particles(:,1) >= bounds.X(1) & pf.Particles(:,1) <= bounds.X(2));
inY = all(pf.Particles(:,2) >= bounds.Y(1) & pf.Particles(:,2) <= bounds.Y(2));
inZ = all(pf.Particles(:,3) >= bounds.Z(1) & pf.Particles(:,3) <= bounds.Z(2));
assertTest('T3 predict stays in bounds', inX && inY && inZ, passed, failed);
passed = passed + (inX&&inY&&inZ);
failed = failed + ~(inX&&inY&&inZ);

%% Test 4: Convergence test — after 8 updates, estimate within 40 m of truth
% True Hider position
truePos  = [120, 80, -40, 1.2];
seekerPos = [10, 10, 0, 0];

pf2 = ParticleFilter(bounds, 200);
pf2.uniformInit();

for i = 1:8
    % Simulate a perfect bearing measurement (no noise)
    pf2.BearingNoiseSigma   = 0.01;
    pf2.ElevationNoiseSigma = 0.01;

    dx = truePos(1) - seekerPos(1);
    dy = truePos(2) - seekerPos(2);
    dz = truePos(3) - seekerPos(3);
    trueBearing = atan2(dx, dy);
    if trueBearing <= 0, trueBearing = trueBearing + 2*pi; end
    trueElev    = atan2(dz, sqrt(dx^2+dy^2));

    pf2.predict(1.0, 1.0);
    pf2.update(trueBearing, trueElev, seekerPos);
end

est  = pf2.getEstimate();
err  = norm(est(1:3) - truePos(1:3));
assertTest(sprintf('T4 converges within 40m (err=%.1fm)', err), err < 40, passed, failed);
passed = passed + (err<40);
failed = failed + (err>=40);

%% Test 5: Weights renormalise after update
pf3 = ParticleFilter(bounds, 50);
pf3.uniformInit();
pf3.predict(1.0);
pf3.update(pi/4, 0.1, seekerPos);
wsum2 = sum(pf3.Weights);
assertTest('T5 weights renormalised after update', abs(wsum2-1.0) < 1e-9, passed, failed);
passed = passed + (abs(wsum2-1.0)<1e-9);
failed = failed + (abs(wsum2-1.0)>=1e-9);

%% Test 6: getPositionUncertainty decreases with information
pf4 = ParticleFilter(bounds, 100);
pf4.uniformInit();
unc_before = pf4.getPositionUncertainty();

pf4.BearingNoiseSigma = 0.05;
pf4.ElevationNoiseSigma = 0.02;
for i = 1:5
    pf4.predict(0.5, 1.0);
    pf4.update(pi/4, 0.1, seekerPos);
end
unc_after = pf4.getPositionUncertainty();
assertTest('T6 uncertainty decreases with measurements', unc_after < unc_before, passed, failed);
passed = passed + (unc_after < unc_before);
failed = failed + (unc_after >= unc_before);

%% Summary
fprintf('\n--- Results: %d passed, %d failed ---\n\n', passed, failed);
if failed > 0
    error('test_particle_filter: %d test(s) FAILED.', failed);
end

end % test_particle_filter

% -----------------------------------------------------------------------
function assertTest(name, condition, ~, ~)
    if condition
        fprintf('  [PASS] %s\n', name);
    else
        fprintf('  [FAIL] %s\n', name);
    end
end
