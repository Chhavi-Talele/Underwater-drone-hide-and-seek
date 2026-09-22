%% StandaloneSimulation.m
%  ========================================================================
%  UNDERWATER DRONE HIDE & SEEK — ADVANCED AUTONOMOUS SIMULATION
%  ========================================================================
%  Paste this into MATLAB / MATLAB Online and click RUN!
%
%  Features:
%    - Ultra-Responsive UI: Pause/Resume, Restart, 3D Iso, 2D Top, Side View,
%      Zoom (+/-), Mouse Scroll Wheel Zoom, Reset Cam, and 3D Orbit Rotate!
%    - Enhanced Hider AI Senses:
%        * Passive Acoustic Array Hearing (110m range)
%        * Predictive Sonar Beam Sweep Avoidance (predicts sweep path 4 steps ahead)
%        * Dynamic Multi-Factor Safety Evaluator (Boulders + Kelp Thickets)
%        * 4 Tactical Modes: HIDE, SILENT SHADOW, SPRINT EVADE, PRE-EMPTIVE DUCK
%    - Seeker AUV with 38° Conical Active Sonar Beam & 3D Particle Filter Tracking
%    - Ocean Visuals: Light ocean theme, ocean surface plane, textured seabed,
%      14 shaded boulders, swaying kelp fronds, live acoustic exposure seabed heatmap.
%  ========================================================================

function StandaloneSimulation()
    clc; close all;

    %% =====================================================================
    %   1. SIMULATION STATE & RESTART LOOP
    % ======================================================================
    global isRestartRequested;
    isRestartRequested = false;

    while true
        isRestartRequested = false;
        runSingleSimulation();
        if ~isRestartRequested
            break; % Exit loop if figure was closed naturally without restart request
        end
    end
end

function runSingleSimulation()
    global isRestartRequested;

    %% =====================================================================
    %   2. FIGURE & AXES SETUP (CRISP OCEAN THEME)
    % ======================================================================
    hFig = figure('Name', 'Underwater Drone Hide & Seek — Autonomous Simulation', ...
                  'Color', [0.88, 0.94, 0.98], ...
                  'Position', [30, 30, 1320, 860], ...
                  'Renderer', 'opengl');

    % Set figure AppData for reliable button callback state management
    setappdata(hFig, 'isPaused', false);
    setappdata(hFig, 'viewMode', '3D');
    setappdata(hFig, 'orbitState', false);

    X_MAX = 250; Y_MAX = 250; Z_MAX = 60;

    % Main 3D Simulation Axes
    hAx = axes('Parent', hFig, 'Position', [0.05 0.20 0.61 0.71], 'Tag', 'MainAxes');
    hold(hAx, 'on'); grid(hAx, 'on');

    xlim(hAx, [0 X_MAX]); ylim(hAx, [0 Y_MAX]); zlim(hAx, [0 Z_MAX]);
    axis(hAx, 'vis3d'); % Freeze aspect ratio for smooth zooming & view changes

    xlabel(hAx, 'East / X (m)',  'FontWeight','bold','Color',[0.1 0.2 0.3]);
    ylabel(hAx, 'North / Y (m)', 'FontWeight','bold','Color',[0.1 0.2 0.3]);
    zlabel(hAx, 'Depth / Z (m)', 'FontWeight','bold','Color',[0.1 0.2 0.3]);
    title(hAx, '3D Ocean Arena (250m × 250m × 60m) | Tactical AI Simulation', ...
          'FontSize',13,'FontWeight','bold','Color',[0.05 0.15 0.25]);

    set(hAx, 'ZDir','reverse', ...
             'Color',[0.82 0.92 0.96], ...
             'GridColor',[0.45 0.65 0.78], ...
             'GridAlpha',0.45, 'Box','on', ...
             'XColor',[0.15 0.25 0.35], 'YColor',[0.15 0.25 0.35], 'ZColor',[0.15 0.25 0.35]);

    % Attach Mouse Scroll Wheel Zoom Listener
    set(hFig, 'WindowScrollWheelFcn', @(src, evt) cbScrollZoom(src, evt, hAx));

    %% =====================================================================
    %   3. INTERACTIVE CONTROL BUTTON TOOLBAR (MATLAB ONLINE OPTIMIZED)
    % ======================================================================
    % Pause / Resume Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '⏸ Pause', 'Units', 'normalized', ...
        'Position', [0.030 0.945 0.070 0.040], ...
        'BackgroundColor', [0.15 0.55 0.85], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @cbTogglePause);

    % Restart Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '↺ Restart', 'Units', 'normalized', ...
        'Position', [0.105 0.945 0.070 0.040], ...
        'BackgroundColor', [0.85 0.35 0.15], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @cbRestart);

    % 3D Isometric View Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '📷 3D Iso', 'Units', 'normalized', ...
        'Position', [0.180 0.945 0.070 0.040], ...
        'BackgroundColor', [0.20 0.65 0.40], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @cbSetView3D);

    % 2D Top-Down View Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '🗺 2D Top', 'Units', 'normalized', ...
        'Position', [0.255 0.945 0.070 0.040], ...
        'BackgroundColor', [0.15 0.50 0.75], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @cbSetView2D);

    % Side View Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '⚓ Side View', 'Units', 'normalized', ...
        'Position', [0.330 0.945 0.075 0.040], ...
        'BackgroundColor', [0.25 0.45 0.70], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @cbSetViewSide);

    % Zoom In Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '🔍 Zoom +', 'Units', 'normalized', ...
        'Position', [0.410 0.945 0.065 0.040], ...
        'BackgroundColor', [0.30 0.45 0.65], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @(src,~) cbZoom(src, 1.25));

    % Zoom Out Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '🔎 Zoom -', 'Units', 'normalized', ...
        'Position', [0.480 0.945 0.065 0.040], ...
        'BackgroundColor', [0.30 0.45 0.65], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @(src,~) cbZoom(src, 0.80));

    % Reset Camera Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '🎯 Reset Cam', 'Units', 'normalized', ...
        'Position', [0.550 0.945 0.075 0.040], ...
        'BackgroundColor', [0.40 0.40 0.55], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @cbResetCam);

    % Orbit Rotate Toggle Button
    uicontrol('Parent', hFig, 'Style', 'pushbutton', ...
        'String', '🔄 Orbit 3D', 'Units', 'normalized', ...
        'Position', [0.630 0.945 0.080 0.040], ...
        'BackgroundColor', [0.50 0.35 0.65], 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 9.5, ...
        'Interruptible', 'on', 'BusyAction', 'queue', ...
        'Callback', @cbToggleOrbit);

    %% =====================================================================
    %   4. OCEAN ENVIRONMENT (SURFACE, SEABED & ACOUSTIC HEATMAP)
    % ======================================================================
    % Semi-transparent ocean surface plane at Depth Z=0
    [Xsurf, Ysurf] = meshgrid(0:50:X_MAX, 0:50:Y_MAX);
    Zsurf = zeros(size(Xsurf));
    surf(hAx, Xsurf, Ysurf, Zsurf, 'FaceColor',[0.35 0.75 0.95], ...
         'EdgeColor','none','FaceAlpha',0.18);

    % Bathymetric Seabed Floor
    [Xbed, Ybed] = meshgrid(0:10:X_MAX, 0:10:Y_MAX);
    Zbed = 56.0 + 2.5*sin(Xbed/22).*cos(Ybed/26) + 1.2*sin((Xbed+Ybed)/18);
    surf(hAx, Xbed, Ybed, Zbed, 'FaceColor',[0.76 0.71 0.58], ...
         'EdgeColor','none','FaceAlpha',0.75);

    % Acoustic Exposure Heatmap surface (Optimized 31x31 grid)
    gridRes = 31;
    [Xgrid, Ygrid] = meshgrid(linspace(0, X_MAX, gridRes), linspace(0, Y_MAX, gridRes));
    Zgrid = 55.5 + 2.5*sin(Xgrid/22).*cos(Ygrid/26);
    exposureGrid = zeros(gridRes, gridRes);

    colormap(hAx, 'parula');
    hHeatmap = surf(hAx, Xgrid, Ygrid, Zgrid - 0.25, exposureGrid, ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.50);
    caxis(hAx, [0 40]);

    %% =====================================================================
    %   5. PROCEDURAL BOULDERS (14 OBSTACLES WITH HIGH-VIS SHADING)
    % ======================================================================
    rockData = [
         40,  45, 11.0;  75,  90, 13.5; 120,  50, 12.0;  60, 160, 10.5;
        135, 140, 15.0; 180,  70, 13.0; 210, 130, 11.5; 160, 200, 14.0;
         95, 215, 12.0;  35, 210, 10.0; 215,  40, 10.5; 185, 175, 12.5;
         90, 125,  9.5; 145,  95, 11.0
    ];
    numRocks = size(rockData,1);
    rockModels = cell(numRocks,1);
    rng(101);

    for i = 1:numRocks
        cx = rockData(i,1); cy = rockData(i,2); baseR = rockData(i,3);
        cz = 56.0 + 2.5*sin(cx/22)*cos(cy/26) - baseR*0.52;
        [sx,sy,sz] = sphere(16);
        noise = 1.0 + 0.22*sin(3*sx).*cos(3*sy) + 0.12*cos(5*sz);
        rx = cx + baseR*sx.*noise*1.15;
        ry = cy + baseR*sy.*noise*0.95;
        rz = cz + baseR*sz.*noise*0.85;
        rockModels{i}.center = [cx, cy, cz];
        rockModels{i}.radius = baseR * 1.10;
        surf(hAx, rx, ry, rz, 'FaceColor',[0.38 0.36 0.34], ...
             'EdgeColor','none','FaceAlpha',1.0);
    end

    %% =====================================================================
    %   6. KELP VEGETATION (14 CLUSTERS WITH MULTI-LEAF SWAY)
    % ======================================================================
    plantClusters = [
        25,30; 50,110; 80,70; 110,170; 150,45; 170,120;
        200,85; 225,180; 130,220; 70,225; 30,160; 190,220; 115,90; 165,160
    ];
    numPlants = size(plantClusters,1);
    hKelpStalks = cell(numPlants, 2);
    hKelpLeaves = cell(numPlants, 2);
    kelpBaseNodes = cell(numPlants, 2);

    for p = 1:numPlants
        px = plantClusters(p,1); py = plantClusters(p,2);
        pz_bed = 56.0 + 2.5*sin(px/22)*cos(py/26);
        for stalk = 1:2
            stalkH = 14 + rand()*6;
            zNodes = linspace(pz_bed, pz_bed-stalkH, 10);
            kelpBaseNodes{p, stalk}.z = zNodes;
            kelpBaseNodes{p, stalk}.px = px + (rand()-0.5)*2.5;
            kelpBaseNodes{p, stalk}.py = py + (rand()-0.5)*2.5;
            hKelpStalks{p, stalk} = plot3(hAx, zeros(10,1), zeros(10,1), zNodes, ...
                'Color',[0.12 0.50 0.22], 'LineWidth',2.4);
            hKelpLeaves{p, stalk} = plot3(hAx, zeros(10,1), zeros(10,1), zNodes, ...
                'Color',[0.20 0.65 0.30], 'LineWidth',1.2);
        end
    end

    %% =====================================================================
    %   7. SIDE PANELS (Distance Plot & Telemetry HUD)
    % ======================================================================
    % Inter-AUV Distance Plot Panel
    axDist = axes('Parent', hFig, 'Position', [0.70 0.60 0.27 0.31]);
    set(axDist, 'Color',[0.92 0.96 1.0], 'XColor',[0.1 0.2 0.3], 'YColor',[0.1 0.2 0.3]);
    hold(axDist,'on'); grid(axDist,'on');
    title(axDist,'Inter-AUV Range History','FontWeight','bold','Color',[0.05 0.15 0.25]);
    xlabel(axDist,'Timestep'); ylabel(axDist,'Distance (m)');
    hDistLine = plot(axDist, 0, norm([210-30, 210-30, 45-25]), 'Color',[0.1 0.5 0.9],'LineWidth',2);
    yline(axDist, 8.0, 'r--', 'Capture (8m)','LineWidth',1.5,'Color',[0.8 0.1 0.1]);
    yline(axDist, 65.0, 'b:', 'Sonar Max (65m)','LineWidth',1.2,'Color',[0.1 0.4 0.8]);

    % HUD Stats Telemetry Panel
    axHUD = axes('Parent', hFig, 'Position', [0.70 0.16 0.27 0.32]);
    axis(axHUD,'off');
    set(axHUD,'Color',[0.88 0.94 0.98]);
    hHUDText = text(axHUD, 0.02, 0.98, 'INITIALIZING TACTICAL SIMULATION...', ...
        'Units','normalized','VerticalAlignment','top', ...
        'FontSize',9.0,'FontName','Courier','Color',[0.05 0.15 0.25], ...
        'BackgroundColor',[0.93 0.97 1.0],'Margin',6, ...
        'Interpreter','none');

    % Legend Panel at bottom
    axLeg = axes('Parent', hFig, 'Position', [0.03 0.02 0.94 0.09]);
    axis(axLeg,'off'); set(axLeg,'Color',[0.88 0.94 0.98]);
    text(axLeg,0.01,0.65,'● HIDER AUV (Stealth AI + Passive Sonar Array)', 'Units','normalized','Color',[0.05 0.55 0.20],'FontSize',9.5,'FontWeight','bold');
    text(axLeg,0.01,0.25,'■ SEEKER AUV (Active Sonar + 3D Particle Filter)', 'Units','normalized','Color',[0.80 0.15 0.15], 'FontSize',9.5,'FontWeight','bold');
    text(axLeg,0.36,0.65,'◀ Blue/Red Cone = Active Sonar Beam','Units','normalized','Color',[0.05 0.4 0.75],'FontSize',9.5);
    text(axLeg,0.36,0.25,'✦ Orange Dots = Target Belief Particle Cloud','Units','normalized','Color',[0.85 0.45 0.05],'FontSize',9.5);
    text(axLeg,0.70,0.65,'⬤ Boulders = Acoustic Shadow Cover','Units','normalized','Color',[0.35 0.35 0.35],'FontSize',9.5);
    text(axLeg,0.70,0.25,'▒ Heatmap = Floor Sonar Exposure','Units','normalized','Color',[0.2 0.4 0.8],'FontSize',9.5);

    %% =====================================================================
    %   8. AGENT INITIAL POSITIONS & HIGH-VISIBILITY GRAPHICS
    % ======================================================================
    hiderPos  = [210.0, 210.0, 45.0];
    seekerPos = [30.0,  30.0,  25.0];
    hiderTargetPos = hiderPos;
    hiderMoveDir   = [0; 0; 0];
    seekerMoveDir  = [1; 0; 0];

    % Hider agent marker (Bright Emerald Core)
    hHider = plot3(hAx, hiderPos(1), hiderPos(2), hiderPos(3), 'o', ...
                   'MarkerSize',13, 'MarkerFaceColor',[0.10 0.80 0.30], ...
                   'MarkerEdgeColor',[0.02 0.35 0.10], 'LineWidth',2.2);

    % Seeker agent marker (Bright Crimson Core)
    hSeeker = plot3(hAx, seekerPos(1), seekerPos(2), seekerPos(3), 's', ...
                    'MarkerSize',14, 'MarkerFaceColor',[0.95 0.20 0.15], ...
                    'MarkerEdgeColor',[0.45 0.05 0.05], 'LineWidth',2.2);
    
    % Heading direction vectors
    hHiderDirLine  = plot3(hAx, [hiderPos(1) hiderPos(1)], [hiderPos(2) hiderPos(2)], [hiderPos(3) hiderPos(3)], ...
                          '-', 'Color',[0.05 0.55 0.18], 'LineWidth',2.8);
    hSeekerDirLine = plot3(hAx, [seekerPos(1) seekerPos(1)], [seekerPos(2) seekerPos(2)], [seekerPos(3) seekerPos(3)], ...
                          '-', 'Color',[0.85 0.15 0.15], 'LineWidth',2.8);

    % Hider Target Destination Marker
    hTargetMarker = plot3(hAx, hiderTargetPos(1), hiderTargetPos(2), hiderTargetPos(3), ...
                          'p','MarkerSize',12,'LineWidth',2,'Color',[0.05 0.55 0.20], ...
                          'MarkerFaceColor',[0.40 0.85 0.40]);

    % Hider Passive Acoustic Hearing Ring (Indicates 110m hearing range when active)
    [hxRing, hyRing] = circlePoints(hiderPos(1), hiderPos(2), 110.0, 24);
    hHiderHearRing = plot3(hAx, hxRing, hyRing, repmat(hiderPos(3), size(hxRing)), ...
                           ':', 'Color', [0.10 0.70 0.35 0.45], 'LineWidth', 1.2);

    % Particle Filter belief cloud graphics
    numParticles = 40;
    particles    = repmat(hiderPos, numParticles, 1) + randn(numParticles,3)*25;
    hParticles   = plot3(hAx, particles(:,1), particles(:,2), particles(:,3), '.', ...
                         'Color',[0.95 0.50 0.05], 'MarkerSize',11);

    % Agent Trail ribbons
    hHiderTrail  = plot3(hAx, hiderPos(1), hiderPos(2), hiderPos(3), ...
                         '-', 'Color',[0.1 0.60 0.25 0.85],'LineWidth',1.8);
    hSeekerTrail = plot3(hAx, seekerPos(1), seekerPos(2), seekerPos(3), ...
                         '--','Color',[0.85 0.2 0.15 0.85],'LineWidth',1.8);

    % Conical Sonar Mesh
    sonarMaxRange      = 65.0;
    azimuthAperture    = deg2rad(38);
    elevationAperture  = deg2rad(24);
    [Rgrid,PhiGrid]    = meshgrid(linspace(0,sonarMaxRange,5), linspace(0,2*pi,14));
    cLX = Rgrid;
    cLY = Rgrid.*tan(azimuthAperture).*cos(PhiGrid);
    cLZ = Rgrid.*tan(elevationAperture).*sin(PhiGrid);
    
    hSonarMesh = surf(hAx, cLX, cLY, cLZ, ...
                      'FaceColor', [0.10 0.65 0.95], 'EdgeColor','none', 'FaceAlpha', 0.18);

    % Expanding Active Sonar Pulse Ring
    [pxRing, pyRing] = circlePoints(seekerPos(1), seekerPos(2), 10, 18);
    hPingPulse = plot3(hAx, pxRing, pyRing, repmat(seekerPos(3), size(pxRing)), ...
                       ':', 'Color', [0.10 0.65 0.95 0.6], 'LineWidth', 1.4);

    % In-scene Text HUD
    hInSceneHUD = text(hAx, 8, 12, 6, 'SIMULATION INITIALIZING...', ...
                       'FontSize',10,'FontWeight','bold','Color',[0.1 0.25 0.35], ...
                       'BackgroundColor',[0.95 0.98 1.0],'Margin',6);

    % Paused Banner Overlay Text
    hPauseBanner = text(hAx, X_MAX/2, Y_MAX/2, Z_MAX/2, '⏸ PAUSED — Click ▶ Resume to Continue', ...
                        'FontSize',14,'FontWeight','bold','HorizontalAlignment','center', ...
                        'Color',[0.9 0.1 0.1],'BackgroundColor',[1 1 0.85],'Margin',10, ...
                        'Visible','off');

    % Set initial camera view
    applyViewMode(hAx, getappdata(hFig, 'viewMode'));
    camlight('headlight'); lighting(hAx,'gouraud');
    set(hFig, 'CloseRequestFcn', @(src,~) onCloseFigure(src));

    %% =====================================================================
    %   9. SIMULATION PARAMETERS & TACTICAL AI STATE
    % ======================================================================
    sonarAzimuth       = deg2rad(0);
    sonarPitch         = deg2rad(6);
    captureRadius      = 8.0;

    seekerStateNames   = {'SEARCH (PATROL)','TRACK (PARTICLES)','PURSUE (INTERCEPT)'};
    hiderStateNames    = {'HIDE (STALK)','SILENT (SHADOW)','SPRINT EVADE','PRE-EMPTIVE DUCK'};
    seekerState = 1; hiderState = 1;

    hiderTrailX  = hiderPos(1);  hiderTrailY  = hiderPos(2);  hiderTrailZ  = hiderPos(3);
    seekerTrailX = seekerPos(1); seekerTrailY = seekerPos(2); seekerTrailZ = seekerPos(3);

    distHist = norm(hiderPos - seekerPos);
    stepHist = 0;

    isLockedOn  = false;
    step        = 0;
    captured    = false;
    timeSinceRehide = 99;

    weights = ones(numParticles,1) / numParticles;

    %% =====================================================================
    %   10. MAIN SIMULATION LOOP
    % ======================================================================
    while ishandle(hFig)
        
        % Handle Pause State Reliably
        if getappdata(hFig, 'isPaused')
            set(hPauseBanner, 'Visible', 'on');
            drawnow;
            pause(0.05);
            continue;
        else
            set(hPauseBanner, 'Visible', 'off');
        end

        step = step + 1;
        timeSinceRehide = timeSinceRehide + 1;

        % Ocean current drift vector
        oceanCurrent = [0.15*sin(step*0.02), 0.10*cos(step*0.025), 0];

        %% -----------------------------------------------------------------
        %  A. DYNAMIC KELP SWAY (Optimized)
        % ------------------------------------------------------------------
        if mod(step, 3) == 0
            for p = 1:numPlants
                for stalk = 1:2
                    zNodes = kelpBaseNodes{p, stalk}.z;
                    px     = kelpBaseNodes{p, stalk}.px;
                    py     = kelpBaseNodes{p, stalk}.py;
                    swayX  = px + 1.8*sin(step*0.05 + p) * (zNodes(1)-zNodes)/20;
                    swayY  = py + 1.4*cos(step*0.04 + stalk) * (zNodes(1)-zNodes)/20;
                    set(hKelpStalks{p, stalk}, 'XData', swayX, 'YData', swayY);
                    set(hKelpLeaves{p, stalk}, 'XData', swayX + 0.6*sin(zNodes), 'YData', swayY + 0.6*cos(zNodes));
                end
            end
        end

        %% -----------------------------------------------------------------
        %  B. RAY-CAST OCCLUSION & KELP ATTENUATION CHECK
        % ------------------------------------------------------------------
        relVec       = hiderPos - seekerPos;
        rangeToHider = norm(relVec);

        % Construct Seeker Sonar Rotation Matrix
        Rz  = [cos(sonarAzimuth) -sin(sonarAzimuth) 0; sin(sonarAzimuth) cos(sonarAzimuth) 0; 0 0 1];
        Ry  = [cos(sonarPitch) 0 sin(sonarPitch); 0 1 0; -sin(sonarPitch) 0 cos(sonarPitch)];
        Rot = Rz*Ry;

        beamDir      = Rot*[1;0;0];
        cosA         = dot(relVec/max(0.1, rangeToHider), beamDir);
        targetAngle  = acos(max(-1.0, min(1.0, cosA)));
        isInsideBeam = (rangeToHider <= sonarMaxRange) && (targetAngle <= azimuthAperture);

        % Ray-cast check against all 14 boulders
        isOccludedByRock = false;
        if isInsideBeam
            rayDir = relVec / max(0.1, rangeToHider);
            for r = 1:numRocks
                rC   = rockModels{r}.center;
                rRad = rockModels{r}.radius;
                proj = dot(rC - seekerPos, rayDir);
                if proj > 0 && proj < rangeToHider
                    perpDist = norm((seekerPos + proj*rayDir) - rC);
                    if perpDist <= rRad
                        isOccludedByRock = true; break;
                    end
                end
            end
        end

        % Check Kelp Attenuation
        inKelpThicket = false;
        for p = 1:numPlants
            distToKelp = norm(hiderPos(1:2) - plantClusters(p,:));
            if distToKelp < 12.0
                inKelpThicket = true; break;
            end
        end

        % Effective Sonar Detection
        hiderPingSuppressed = (hiderState == 2);
        detectedBySonar = isInsideBeam && ~isOccludedByRock && ~(inKelpThicket && rangeToHider > 30) && ~hiderPingSuppressed;

        %% -----------------------------------------------------------------
        %  C. ACOUSTIC EXPOSURE HEATMAP UPDATE
        % ------------------------------------------------------------------
        if mod(step, 2) == 0
            dxGrid = Xgrid - seekerPos(1);
            dyGrid = Ygrid - seekerPos(2);
            distGrid = sqrt(dxGrid.^2 + dyGrid.^2);
            angleGrid = atan2(dyGrid, dxGrid);
            
            angleDiff = abs(angleGrid - sonarAzimuth);
            angleDiff = min(angleDiff, 2*pi - angleDiff);
            
            scannedMask = (distGrid <= sonarMaxRange) & (angleDiff <= azimuthAperture);
            exposureGrid(scannedMask) = exposureGrid(scannedMask) + 0.40;
            set(hHeatmap, 'CData', exposureGrid);
        end

        %% -----------------------------------------------------------------
        %  D. ENHANCED HIDER ADVANCED TACTICAL AI & HIGH-SENSING ENGINE
        % ------------------------------------------------------------------
        % 1. Passive Acoustic Array Hearing (Long Range: 110 meters)
        hiderHearsSeekerPing = (rangeToHider <= 110.0);

        % 2. Predictive Sonar Sweep Avoidance Algorithm (Projects 4 steps ahead)
        futureAzimuth  = mod(sonarAzimuth + deg2rad(8)*4, 2*pi);
        RzFut          = [cos(futureAzimuth) -sin(futureAzimuth) 0; sin(futureAzimuth) cos(futureAzimuth) 0; 0 0 1];
        futureBeamDir  = RzFut*[1;0;0];
        futureCosA     = dot(relVec/max(0.1, rangeToHider), futureBeamDir);
        futureTargetAngle = acos(max(-1.0, min(1.0, futureCosA)));
        
        predictiveBeamWarning = isInsideBeam || (hiderHearsSeekerPing && futureTargetAngle < azimuthAperture * 1.5);

        % 3. Tactical State Selection
        if rangeToHider < 28.0 || (detectedBySonar && rangeToHider < 55.0)
            hiderState = 3; % SPRINT EVADE
        elseif predictiveBeamWarning && ~isOccludedByRock
            hiderState = 4; % PRE-EMPTIVE DUCK (Move to cover before beam hits)
        elseif hiderHearsSeekerPing && isOccludedByRock
            hiderState = 2; % SILENT SHADOW (Hold position in shadow cone)
        else
            hiderState = 1; % HIDE (Cruising toward optimal occluded hiding spot)
        end

        % 4. Multi-Factor Hiding Spot Evaluator
        if hiderState == 3 || hiderState == 4 || timeSinceRehide > 30
            bestScore = -Inf;
            bestTarget = hiderPos;
            
            % Evaluate candidate spots behind all 14 boulders & kelp thickets
            for r = 1:numRocks
                rC   = rockModels{r}.center;
                rRad = rockModels{r}.radius;
                
                % Vector from Seeker to Rock center
                dirSR = rC - seekerPos;
                dirSR_norm = dirSR / max(0.1, norm(dirSR));
                
                % Shadow zone candidate behind boulder
                candidate = rC + dirSR_norm * (rRad + 12.0);
                candidate(3) = min(50, max(15, rC(3) - 2.0));
                
                distS = norm(candidate - seekerPos);
                distH = norm(candidate - hiderPos);
                
                % Check kelp proximity for candidate
                nearKelpBonus = 0;
                for p = 1:numPlants
                    if norm(candidate(1:2) - plantClusters(p,:)) < 15.0
                        nearKelpBonus = 15.0; break;
                    end
                end

                % Multi-factor Safety Score
                shadowAlignment = dot(dirSR_norm, beamDir);
                score = distS * 1.8 - distH * 0.35 - shadowAlignment * 18.0 + nearKelpBonus;
                
                if score > bestScore
                    bestScore = score;
                    bestTarget = candidate;
                end
            end
            hiderTargetPos = bestTarget;
            timeSinceRehide = 0;
        end

        % 5. Hider Steering & Repulsion Physics
        hiderDir = hiderTargetPos - hiderPos;
        distToTarget = norm(hiderDir);
        
        % Speed tuning per tactical state
        switch hiderState
            case 3, hiderSpeed = 2.70; % SPRINT EVADE
            case 4, hiderSpeed = 2.20; % PRE-EMPTIVE DUCK
            case 2, hiderSpeed = 0.45; % SILENT SHADOW (Silent crawl)
            otherwise, hiderSpeed = 1.50; % HIDE
        end

        if distToTarget > 1.2
            hiderMoveDir = hiderDir / distToTarget;
            
            % Obstacle repulsion from boulders
            for r = 1:numRocks
                rC = rockModels{r}.center;
                rRad = rockModels{r}.radius;
                distR = norm(hiderPos - rC);
                if distR < (rRad + 6.0)
                    avoidVec = (hiderPos - rC) / max(0.1, distR);
                    hiderMoveDir = hiderMoveDir + avoidVec * 1.8;
                end
            end
            hiderMoveDir = hiderMoveDir / max(0.1, norm(hiderMoveDir));
            hiderPos = hiderPos + hiderMoveDir * hiderSpeed + oceanCurrent;
        else
            hiderPos = hiderPos + oceanCurrent;
        end

        % Clamp Hider position
        hiderPos(1) = min(240, max(10, hiderPos(1)));
        hiderPos(2) = min(240, max(10, hiderPos(2)));
        hiderPos(3) = min(52,  max(10, hiderPos(3)));

        %% -----------------------------------------------------------------
        %  E. AUTONOMOUS SEEKER AI & SONAR BEAM DYNAMICS
        % ------------------------------------------------------------------
        if detectedBySonar
            isLockedOn  = true;
            seekerState = ternary(rangeToHider < 25.0, 3, 2);
        else
            if isLockedOn && rangeToHider > 75.0
                isLockedOn = false;
                seekerState = 1;
            end
        end

        % Seeker Navigation & Sonar Steering
        if ~isLockedOn
            seekerState = 1;
            patrolTarget = [125 + 90*cos(step*0.022), 125 + 90*sin(step*0.028), 28 + 8*sin(step*0.035)];
            dirP = patrolTarget - seekerPos;
            seekerMoveDir = 0.95 * (dirP / max(0.1, norm(dirP)));
            
            sonarAzimuth = mod(sonarAzimuth + deg2rad(8), 2*pi);
            sonarPitch   = deg2rad(6)*sin(step*0.08) + deg2rad(4);
        else
            estPos = mean(particles, 1);
            dirE   = estPos - seekerPos;
            distE  = norm(dirE);
            speedS = min(1.65, distE * 0.06 + 0.6);
            seekerMoveDir = speedS * (dirE / max(0.1, distE));
            
            sonarAzimuth = atan2(dirE(2), dirE(1));
            sonarPitch   = atan2(dirE(3), max(0.1, norm(dirE(1:2))));
        end

        % Seeker Repulsion from rocks
        for r = 1:numRocks
            rC = rockModels{r}.center;
            rRad = rockModels{r}.radius;
            distR = norm(seekerPos - rC);
            if distR < (rRad + 7.0)
                avoidVec = (seekerPos - rC) / max(0.1, distR);
                seekerMoveDir = seekerMoveDir + avoidVec * 2.0;
            end
        end
        seekerMoveDir = seekerMoveDir / max(0.1, norm(seekerMoveDir));
        seekerPos     = seekerPos + seekerMoveDir * 1.15;

        % Clamp Seeker position
        seekerPos(1) = min(240, max(10, seekerPos(1)));
        seekerPos(2) = min(240, max(10, seekerPos(2)));
        seekerPos(3) = min(52,  max(10, seekerPos(3)));

        % Update Conical Sonar Mesh
        cR  = Rot*[cLX(:)'; cLY(:)'; cLZ(:)'];
        cX  = seekerPos(1) + reshape(cR(1,:), size(Rgrid));
        cY  = seekerPos(2) + reshape(cR(2,:), size(Rgrid));
        cZ  = seekerPos(3) + reshape(cR(3,:), size(Rgrid));

        sonarColor = ternary(detectedBySonar, [0.95 0.25 0.1], [0.10 0.65 0.95]);
        sonarAlpha = ternary(detectedBySonar, 0.28, 0.16);
        set(hSonarMesh, 'XData', cX, 'YData', cY, 'ZData', cZ, ...
                        'FaceColor', sonarColor, 'FaceAlpha', sonarAlpha);

        % Update Sonar Pulse Ring
        pulseRadius = mod(step * 3.5, sonarMaxRange);
        [pxRing, pyRing] = circlePoints(seekerPos(1), seekerPos(2), pulseRadius, 18);
        set(hPingPulse, 'XData', pxRing, 'YData', pyRing, ...
                        'ZData', repmat(seekerPos(3), size(pxRing)), ...
                        'Color', [sonarColor 0.6]);

        %% -----------------------------------------------------------------
        %  F. 3D PARTICLE FILTER UPDATE & BELIEF CLOUD
        % ------------------------------------------------------------------
        if detectedBySonar
            meas = hiderPos + randn(1,3)*2.5;
        else
            meas = seekerPos + randn(1,3)*35.0;
        end
        particles = particles + randn(numParticles,3)*1.6;
        distsP    = vecnorm(particles - meas, 2, 2);
        weights   = exp(-distsP.^2/(2*16^2));
        weights   = weights / (sum(weights) + 1e-9);
        
        idxR      = drawRandomIdx(weights, numParticles);
        particles = particles(idxR,:);
        set(hParticles, 'XData', particles(:,1), 'YData', particles(:,2), 'ZData', particles(:,3));

        %% -----------------------------------------------------------------
        %  G. CAPTURE CHECK & STATUS HUD UPDATE
        % ------------------------------------------------------------------
        if rangeToHider <= captureRadius
            captured = true;
        end

        if detectedBySonar
            statusStr = sprintf('!! ALERT: HIDER SPOTTED! SEEKER PURSUING\n  Range: %.1f m  | Step: %d', rangeToHider, step);
            statusCol = [0.80 0.05 0.05];
            set(hHider, 'MarkerFaceColor',[0.95 0.1 0.1],'MarkerSize',14);
        elseif predictiveBeamWarning
            statusStr = sprintf('⚡ SWEEP WARNING: Hider predicting sonar sweep!\n  Range: %.1f m  | Step: %d', rangeToHider, step);
            statusCol = [0.85 0.45 0.05];
            set(hHider, 'MarkerFaceColor',[0.90 0.60 0.10],'MarkerSize',12);
        elseif isOccludedByRock && isInsideBeam
            statusStr = sprintf('* SHADOW ZONE: Hider hidden behind Rock!\n  Range: %.1f m  | Step: %d', rangeToHider, step);
            statusCol = [0.55 0.40 0.05];
            set(hHider, 'MarkerFaceColor',[0.15 0.70 0.30],'MarkerSize',11);
        elseif inKelpThicket
            statusStr = sprintf('⌇ KELP COVER: Acoustic signal attenuated\n  Range: %.1f m  | Step: %d', rangeToHider, step);
            statusCol = [0.10 0.45 0.20];
            set(hHider, 'MarkerFaceColor',[0.15 0.70 0.30],'MarkerSize',11);
        else
            statusStr = sprintf('SEARCHING: Seeker scanning ocean volume\n  Range: %.1f m  | Step: %d', rangeToHider, step);
            statusCol = [0.10 0.25 0.35];
            set(hHider, 'MarkerFaceColor',[0.15 0.70 0.30],'MarkerSize',11);
        end

        set(hInSceneHUD, 'String', statusStr, 'Color', statusCol);

        % Telemetry HUD panel
        hudLines = sprintf([ ...
            '+----------------------------------+\n' ...
            '|   TELEMETRY & AI STATUS HUD      |\n' ...
            '+----------------------------------+\n' ...
            '| Timestep     : %6d            |\n' ...
            '| Range        : %6.1f m         |\n' ...
            '| Sonar Beam   : %-16s  |\n' ...
            '| Seeker AI    : %-16s  |\n' ...
            '| Hider AI     : %-16s  |\n' ...
            '| Rock Cover   : %-16s  |\n' ...
            '| Passive Hear : %-16s  |\n' ...
            '| Predictive   : %-16s  |\n' ...
            '+----------------------------------+\n' ...
            '| Seeker Pos   : (%.0f, %.0f, %.0f)      |\n' ...
            '| Hider Pos    : (%.0f, %.0f, %.0f)      |\n' ...
            '+----------------------------------+'], ...
            step, rangeToHider, ...
            ternaryStr(detectedBySonar, 'LOCKED ON', 'SCANNING'), ...
            seekerStateNames{seekerState}, hiderStateNames{hiderState}, ...
            ternaryStr(isOccludedByRock, 'YES (OCCLUDED)', 'NO (IN LINE)'), ...
            ternaryStr(hiderHearsSeekerPing, 'ACTIVE (110m)', 'OUT OF RANGE'), ...
            ternaryStr(predictiveBeamWarning, 'ALERT (SWEEP)', 'CLEAR'), ...
            seekerPos(1), seekerPos(2), seekerPos(3), ...
            hiderPos(1),  hiderPos(2),  hiderPos(3));
        set(hHUDText, 'String', hudLines);

        %% -----------------------------------------------------------------
        %  H. GRAPHICS & HEADING VECTOR UPDATE
        % ------------------------------------------------------------------
        set(hHider,        'XData',hiderPos(1),  'YData',hiderPos(2),  'ZData',hiderPos(3));
        set(hSeeker,       'XData',seekerPos(1), 'YData',seekerPos(2), 'ZData',seekerPos(3));
        set(hTargetMarker, 'XData',hiderTargetPos(1),'YData',hiderTargetPos(2),'ZData',hiderTargetPos(3));

        % Hider Passive Hearing Wave Ring Update
        [hxRing, hyRing] = circlePoints(hiderPos(1), hiderPos(2), 110.0, 24);
        set(hHiderHearRing, 'XData', hxRing, 'YData', hyRing, 'ZData', repmat(hiderPos(3), size(hxRing)));

        % Heading direction vectors
        set(hHiderDirLine,  'XData',[hiderPos(1) hiderPos(1)+hiderMoveDir(1)*12], ...
                            'YData',[hiderPos(2) hiderPos(2)+hiderMoveDir(2)*12], ...
                            'ZData',[hiderPos(3) hiderPos(3)+hiderMoveDir(3)*12]);
        set(hSeekerDirLine, 'XData',[seekerPos(1) seekerPos(1)+seekerMoveDir(1)*12], ...
                            'YData',[seekerPos(2) seekerPos(2)+seekerMoveDir(2)*12], ...
                            'ZData',[seekerPos(3) seekerPos(3)+seekerMoveDir(3)*12]);

        if mod(step,2) == 0
            hiderTrailX(end+1)  = hiderPos(1);  hiderTrailY(end+1)  = hiderPos(2);  hiderTrailZ(end+1)  = hiderPos(3);
            seekerTrailX(end+1) = seekerPos(1); seekerTrailY(end+1) = seekerPos(2); seekerTrailZ(end+1) = seekerPos(3);
            if length(hiderTrailX) > 80
                hiderTrailX(1)=[]; hiderTrailY(1)=[]; hiderTrailZ(1)=[];
                seekerTrailX(1)=[]; seekerTrailY(1)=[]; seekerTrailZ(1)=[];
            end
            set(hHiderTrail,  'XData',hiderTrailX,  'YData',hiderTrailY,  'ZData',hiderTrailZ);
            set(hSeekerTrail, 'XData',seekerTrailX, 'YData',seekerTrailY, 'ZData',seekerTrailZ);
        end

        % Distance Plot update
        distHist(end+1) = rangeToHider; %#ok<AGROW>
        stepHist(end+1) = step;         %#ok<AGROW>
        set(hDistLine, 'XData', stepHist, 'YData', distHist);

        drawnow limitrate;
        pause(0.015);

        if captured
            set(hInSceneHUD, 'String', sprintf('>>> CAPTURE AT STEP %d! Range: %.1f m <<<', step, rangeToHider), 'Color', [0.80 0.05 0.05]);
            set(hHUDText, 'String', sprintf('GAME OVER -- SEEKER CAPTURED HIDER!\nCapture Step: %d\nFinal Distance: %.2f m', step, rangeToHider));
            drawnow;
            pause(3);
            break;
        end
    end
end

%% =========================================================================
%   BUTTON CALLBACKS & CAMERA CONTROLS (ROBUST FOR MATLAB ONLINE)
% =========================================================================
function cbTogglePause(src, ~)
    hFig = ancestor(src, 'figure');
    if isempty(hFig), return; end
    paused = getappdata(hFig, 'isPaused');
    if isempty(paused), paused = false; end
    paused = ~paused;
    setappdata(hFig, 'isPaused', paused);
    if paused
        set(src, 'String', '▶ Resume', 'BackgroundColor', [0.20 0.70 0.35]);
    else
        set(src, 'String', '⏸ Pause', 'BackgroundColor', [0.15 0.55 0.85]);
    end
    drawnow;
end

function cbRestart(src, ~)
    global isRestartRequested;
    isRestartRequested = true;
    hFig = ancestor(src, 'figure');
    if ishandle(hFig)
        setappdata(hFig, 'isPaused', false);
        delete(hFig);
    end
end

function cbSetView3D(src, ~)
    hFig = ancestor(src, 'figure');
    hAx = findobj(hFig, 'Type', 'axes', 'Tag', 'MainAxes');
    if isempty(hAx), return; end
    setappdata(hFig, 'viewMode', '3D');
    applyViewMode(hAx, '3D');
end

function cbSetView2D(src, ~)
    hFig = ancestor(src, 'figure');
    hAx = findobj(hFig, 'Type', 'axes', 'Tag', 'MainAxes');
    if isempty(hAx), return; end
    setappdata(hFig, 'viewMode', '2D');
    applyViewMode(hAx, '2D');
end

function cbSetViewSide(src, ~)
    hFig = ancestor(src, 'figure');
    hAx = findobj(hFig, 'Type', 'axes', 'Tag', 'MainAxes');
    if isempty(hAx), return; end
    setappdata(hFig, 'viewMode', 'SIDE');
    applyViewMode(hAx, 'SIDE');
end

function cbZoom(src, factor)
    hFig = ancestor(src, 'figure');
    hAx = findobj(hFig, 'Type', 'axes', 'Tag', 'MainAxes');
    if isempty(hAx), return; end
    camzoom(hAx, factor);
    drawnow;
end

function cbResetCam(src, ~)
    hFig = ancestor(src, 'figure');
    hAx = findobj(hFig, 'Type', 'axes', 'Tag', 'MainAxes');
    if isempty(hAx), return; end
    view(hAx, [38, 28]);
    camup(hAx, [0 0 -1]);
    camproj(hAx, 'perspective');
    axis(hAx, [0 250 0 250 0 60]);
    camzoom(hAx, 'reset');
    drawnow;
end

function cbToggleOrbit(src, ~)
    hFig = ancestor(src, 'figure');
    hAx = findobj(hFig, 'Type', 'axes', 'Tag', 'MainAxes');
    if isempty(hAx), return; end
    
    orbitState = getappdata(hFig, 'orbitState');
    if isempty(orbitState), orbitState = false; end
    orbitState = ~orbitState;
    setappdata(hFig, 'orbitState', orbitState);
    
    if orbitState
        rotate3d(hAx, 'on');
        set(src, 'String', '🔄 Orbit ON', 'BackgroundColor', [0.80 0.35 0.20]);
    else
        rotate3d(hAx, 'off');
        set(src, 'String', '🔄 Orbit 3D', 'BackgroundColor', [0.50 0.35 0.65]);
    end
    drawnow;
end

function cbScrollZoom(~, evt, hAx)
    if ishandle(hAx)
        if evt.VerticalScrollCount > 0
            camzoom(hAx, 0.90); % Scroll Down -> Zoom Out
        else
            camzoom(hAx, 1.10); % Scroll Up -> Zoom In
        end
        drawnow;
    end
end

function applyViewMode(hAx, modeStr)
    if ~ishandle(hAx), return; end
    if strcmp(modeStr, '2D')
        view(hAx, [0, 90]);
        camup(hAx, [0 1 0]);   % North (Y axis) points UP on 2D map
        camproj(hAx, 'orthographic');
    elseif strcmp(modeStr, 'SIDE')
        view(hAx, [0, 0]);
        camup(hAx, [0 0 -1]);  % Depth points down
        camproj(hAx, 'orthographic');
    else
        view(hAx, [38, 28]);
        camup(hAx, [0 0 -1]);  % Standard up vector when ZDir is reverse
        camproj(hAx, 'perspective');
    end
    drawnow;
end

function onCloseFigure(figHandle)
    if ishandle(figHandle)
        delete(figHandle);
    end
end

%% =========================================================================
%   MATHEMATICAL HELPER FUNCTIONS
% =========================================================================
function indices = drawRandomIdx(weights, N)
    edges = [0; cumsum(weights)]; edges(end) = 1.0;
    u = rand(N,1); indices = zeros(N,1);
    for i = 1:N
        idx = find(u(i) >= edges(1:end-1) & u(i) < edges(2:end), 1);
        if isempty(idx), idx = N; end
        indices(i) = idx;
    end
end

function [x, y] = circlePoints(cx, cy, r, n)
    theta = linspace(0, 2*pi, n);
    x = cx + r * cos(theta);
    y = cy + r * sin(theta);
end

function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function s = ternaryStr(cond, a, b)
    if cond, s = a; else, s = b; end
end
