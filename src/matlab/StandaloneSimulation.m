%% StandaloneSimulation.m
%  ========================================================================
%  UNDERWATER DRONE HIDE & SEEK — STANDALONE SINGLE-FILE SIMULATION
%  ========================================================================
%  Copy and paste this ENTIRE code into a single file named:
%      StandaloneSimulation.m
%  in MATLAB / MATLAB Online, then click RUN!
%
%  Features:
%    - Self-contained 3D Bathymetry & Underwater Terrain (no external map files needed)
%    - Seeker AUV: Search -> Track -> Pursue AI with Particle Filter sonar tracking
%    - Hider AUV: Hide -> Silent -> Evade AI with stealth thermocline depth usage
%    - Real-time 4-panel dark-mode animated 3D visualizer HUD
%  ========================================================================

function StandaloneSimulation()
    clc; close all;
    fprintf('================================═════════════════════\n');
    fprintf('   UNDERWATER DRONE HIDE & SEEK (Standalone Mode)   \n');
    fprintf('================================═════════════════════\n\n');

    %% 1. Simulation Parameters
    maxTime       = 300;     % Max game time (sec)
    dt            = 0.5;     % Time step (sec)
    captureRadius = 8.0;     % Capture distance (m)
    sonarRange    = 70.0;    % Seeker sonar range (m)

    %% 2. Environment Setup (Synthetic 3D Ocean Bathymetry)
    gridSize = [200, 200, 100]; % [X, Y, Z] in meters (Z from -100 to 0)
    [Xg, Yg] = meshgrid(1:2:200, 1:2:200);
    Z_seabed = -100 + 25*sin(Xg/30).*cos(Yg/30) + 15*cos(Xg/50); % 3D underwater peaks

    %% 3. Initial States: [x, y, z, heading]
    seekerPose = [10,  10,  -20, 0];
    hiderPose  = [180, 180, -65, pi];

    seekerVel = 3.5; % m/s
    hiderVel  = 2.8; % m/s

    % Seeker AI State: 1 = Search, 2 = Track, 3 = Pursue
    seekerState = 1;
    stateNames  = {'SEARCH', 'TRACK', 'PURSUE'};

    % Hider AI State: 1 = Hide, 2 = Silent, 3 = Evade
    hiderState  = 1;
    hiderNames  = {'HIDE', 'SILENT', 'EVADE'};

    %% 4. Particle Filter Setup (50 particles)
    numParticles = 50;
    particles    = repmat(seekerPose(1:3), numParticles, 1) + randn(numParticles, 3)*15;
    weights      = ones(numParticles, 1) / numParticles;

    %% 5. Setup Visualization Dashboard
    fig = figure('Name', 'Underwater Drone Hide & Seek', 'Color', [0.08 0.1 0.15], ...
                 'Position', [100, 100, 1200, 800]);

    % Main 3D Panel
    ax3D = subplot(2, 2, [1 3], 'Parent', fig);
    surf(ax3D, Xg, Yg, Z_seabed, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    hold(ax3D, 'on'); colormap(ax3D, 'winter');
    grid(ax3D, 'on'); set(ax3D, 'Color', [0.05 0.07 0.12], 'XColor', 'w', 'YColor', 'w', 'ZColor', 'w');
    xlabel(ax3D, 'X (m)'); ylabel(ax3D, 'Y (m)'); zlabel(ax3D, 'Z (Depth m)');
    title(ax3D, '3D Ocean Arena — Autonomous AUV Battle', 'Color', 'w', 'FontSize', 14);
    axis(ax3D, [0 200 0 200 -100 0]);
    view(ax3D, [-37.5, 30]);

    % Graphics handles
    hSeeker  = plot3(ax3D, seekerPose(1), seekerPose(2), seekerPose(3), 'bo', 'MarkerSize', 10, 'LineWidth', 2, 'MarkerFaceColor', 'b');
    hHider   = plot3(ax3D, hiderPose(1), hiderPose(2), hiderPose(3), 'rs', 'MarkerSize', 10, 'LineWidth', 2, 'MarkerFaceColor', 'r');
    hSeekerT = plot3(ax3D, seekerPose(1), seekerPose(2), seekerPose(3), 'b-', 'LineWidth', 1.5);
    hHiderT  = plot3(ax3D, hiderPose(1), hiderPose(2), hiderPose(3), 'r--', 'LineWidth', 1.5);
    hParts   = plot3(ax3D, particles(:,1), particles(:,2), particles(:,3), 'c.', 'MarkerSize', 6);

    seekerHist = seekerPose(1:3);
    hiderHist  = hiderPose(1:3);

    % Distance Plot Panel
    axDist = subplot(2, 2, 2, 'Parent', fig);
    set(axDist, 'Color', [0.05 0.07 0.12], 'XColor', 'w', 'YColor', 'w');
    hold(axDist, 'on'); grid(axDist, 'on');
    title(axDist, 'Inter-Drone Distance (m)', 'Color', 'w');
    hDistLine = plot(axDist, 0, norm(seekerPose(1:3)-hiderPose(1:3)), 'g-', 'LineWidth', 2);
    yline(axDist, captureRadius, 'r--', 'Capture Threshold', 'Color', 'r');
    xlabel(axDist, 'Time (s)'); ylabel(axDist, 'Distance (m)');

    % HUD Text Panel
    axHUD = subplot(2, 2, 4, 'Parent', fig);
    axis(axHUD, 'off');
    set(axHUD, 'Color', [0.05 0.07 0.12]);
    hHudText = text(axHUD, 0.05, 0.5, '', 'Color', 'w', 'FontSize', 12, 'FontName', 'Courier', 'Interpreter', 'none');

    timeHist = 0;
    distHist = norm(seekerPose(1:3)-hiderPose(1:3));

    %% 6. Main Simulation Loop
    t = 0;
    captured = false;

    % Random search waypoints for Seeker
    waypoints = [30 30 -30; 150 40 -40; 160 160 -50; 40 160 -30];
    wpIdx = 1;

    while t < maxTime && ishandle(fig)
        t = t + dt;

        % Real distance between drones
        trueDist = norm(seekerPose(1:3) - hiderPose(1:3));

        % Check sonar detection (acoustic ray propagation)
        detected = (trueDist <= sonarRange);
        if hiderState == 2 % Silent mode reduces detection range
            detected = (trueDist <= sonarRange * 0.4);
        end

        %% ---- Seeker AI Finite State Machine ----
        if detected
            if trueDist < 25
                seekerState = 3; % PURSUE
            else
                seekerState = 2; % TRACK
            end
        else
            seekerState = 1;     % SEARCH
        end

        % Seeker Motion Logic
        switch seekerState
            case 1 % SEARCH: Follow waypoints
                target = waypoints(wpIdx, :);
                if norm(seekerPose(1:3) - target) < 10
                    wpIdx = mod(wpIdx, size(waypoints,1)) + 1;
                end
                dirVec = (target - seekerPose(1:3)) / norm(target - seekerPose(1:3));

            case 2 % TRACK: Move toward estimated target from Particle Filter
                estTarget = mean(particles, 1);
                dirVec = (estTarget - seekerPose(1:3)) / norm(estTarget - seekerPose(1:3));

            case 3 % PURSUE: Direct high-speed intercept
                dirVec = (hiderPose(1:3) - seekerPose(1:3)) / trueDist;
        end

        seekerPose(1:3) = seekerPose(1:3) + dirVec * seekerVel * dt;
        seekerPose(3)   = max(-90, min(-10, seekerPose(3))); % Enforce ocean bounds

        %% ---- Hider AI Finite State Machine ----
        if trueDist < 20
            hiderState = 3; % EVADE
        elseif trueDist < 50
            hiderState = 2; % SILENT
        else
            hiderState = 1; % HIDE
        end

        % Hider Motion Logic
        switch hiderState
            case 1 % HIDE: Move toward deep thermocline trench
                hideTarget = [170, 170, -75];
                dirH = (hideTarget - hiderPose(1:3)) / (norm(hideTarget - hiderPose(1:3)) + 1e-5);

            case 2 % SILENT: Slow quiet movement
                dirH = [-dirVec(1), -dirVec(2), -0.2];
                dirH = dirH / norm(dirH);

            case 3 % EVADE: High-speed evasive maneuver away from Seeker
                dirH = (hiderPose(1:3) - seekerPose(1:3)) / trueDist;
                dirH(3) = -0.5; % Dive deeper
                dirH = dirH / norm(dirH);
        end

        currHVel = hiderVel * (1.2 * (hiderState==3) + 0.5 * (hiderState==2) + 1.0 * (hiderState==1));
        hiderPose(1:3) = hiderPose(1:3) + dirH * currHVel * dt;
        hiderPose(3)   = max(-95, min(-15, hiderPose(3)));

        %% ---- Particle Filter Update ----
        if detected
            measurement = hiderPose(1:3) + randn(1,3)*3.0;
        else
            measurement = seekerPose(1:3) + randn(1,3)*25.0;
        end

        % Motion update
        particles = particles + randn(numParticles, 3)*1.2;
        % Weight update
        distsP = vecnorm(particles - measurement, 2, 2);
        weights = exp(-distsP.^2 / (2*15^2));
        weights = weights / sum(weights);
        % Resample
        indices = drawRandomIdx(weights, numParticles);
        particles = particles(indices, :);

        %% ---- Check Capture Condition ----
        if trueDist <= captureRadius
            captured = true;
        end

        %% ---- Update Graphics ----
        seekerHist(end+1, :) = seekerPose(1:3); %#ok<AGROW>
        hiderHist(end+1,  :) = hiderPose(1:3);  %#ok<AGROW>

        set(hSeeker,  'XData', seekerPose(1), 'YData', seekerPose(2), 'ZData', seekerPose(3));
        set(hHider,   'XData', hiderPose(1),  'YData', hiderPose(2),  'ZData', hiderPose(3));
        set(hSeekerT, 'XData', seekerHist(:,1), 'YData', seekerHist(:,2), 'ZData', seekerHist(:,3));
        set(hHiderT,  'XData', hiderHist(:,1),  'YData', hiderHist(:,2),  'ZData', hiderHist(:,3));
        set(hParts,   'XData', particles(:,1),  'YData', particles(:,2),  'ZData', particles(:,3));

        timeHist(end+1) = t; %#ok<AGROW>
        distHist(end+1) = trueDist; %#ok<AGROW>
        set(hDistLine, 'XData', timeHist, 'YData', distHist);

        % Update HUD text
        hudStr = sprintf([ ...
            'STATUS TELEMETRY HUD\n' ...
            '-----------------------------------\n' ...
            'Time Elapsed   : %6.1f s / %d s\n' ...
            'Distance       : %6.1f m\n' ...
            'Sonar Signal   : %s\n' ...
            'Seeker AI Mode : %s\n' ...
            'Hider AI Mode  : %s\n' ...
            '-----------------------------------\n'], ...
            t, maxTime, trueDist, iff(detected, 'ACQUIRED [LOCKED]', 'SEARCHING...'), ...
            stateNames{seekerState}, hiderNames{hiderState});

        if captured
            hudStr = [hudStr sprintf('\n*** RESULT: SEEKER CAPTURED HIDER! ***\n')];
        end

        set(hHudText, 'String', hudStr);
        drawnow;

        if captured
            fprintf('\n>>> CAPTURE! Seeker intercepted Hider at t = %.1f s <<<\n\n', t);
            break;
        end
    end

    if ~captured && t >= maxTime
        fprintf('\n>>> HIDER WINS! Survived full %d seconds <<<\n\n', maxTime);
    end
end

%% Helper Functions
function indices = drawRandomIdx(weights, N)
    edges = [0; cumsum(weights)];
    edges(end) = 1.0;
    u = rand(N, 1);
    indices = zeros(N, 1);
    for i = 1:N
        idx = find(u(i) >= edges(1:end-1) & u(i) < edges(2:end), 1);
        if isempty(idx), idx = N; end
        indices(i) = idx;
    end
end

function res = iff(cond, valTrue, valFalse)
    if cond, res = valTrue; else, res = valFalse; end
end
