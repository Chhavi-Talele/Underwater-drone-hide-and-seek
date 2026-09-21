%% StandaloneSimulation.m
%  ========================================================================
%  UNDERWATER DRONE HIDE & SEEK — STANDALONE SIMULATION
%  ========================================================================
%  Paste this into MATLAB Online and click RUN!
%
%  Controls:
%    - Move your mouse over the 3D arena to steer the HIDER (green circle)
%    - The SEEKER (red square) autonomously hunts using conical sonar
%    - Hide behind boulders to break line-of-sight!
%  ========================================================================

function StandaloneSimulation()
    clc; close all;

    %% =====================================================================
    %   1. FIGURE & AXES SETUP
    % ======================================================================
    hFig = figure('Name', 'Underwater Drone Hide & Seek — Interactive', ...
                  'Color', [0.88, 0.94, 0.98], ...
                  'Position', [40, 40, 1200, 820], ...
                  'Renderer', 'opengl');

    hAx = axes('Parent', hFig, 'Position', [0.05 0.22 0.58 0.72]);
    hold(hAx, 'on'); grid(hAx, 'on');

    X_MAX = 250; Y_MAX = 250; Z_MAX = 60;
    xlim(hAx, [0 X_MAX]); ylim(hAx, [0 Y_MAX]); zlim(hAx, [0 Z_MAX]);

    xlabel(hAx, 'East / X (m)',  'FontWeight','bold','Color',[0.1 0.2 0.3]);
    ylabel(hAx, 'North / Y (m)', 'FontWeight','bold','Color',[0.1 0.2 0.3]);
    zlabel(hAx, 'Depth / Z (m)', 'FontWeight','bold','Color',[0.1 0.2 0.3]);
    title(hAx, 'Ocean Arena (250m × 250m)  |  Steer Hider with Mouse', ...
          'FontSize',12,'FontWeight','bold','Color',[0.05 0.15 0.25]);

    set(hAx, 'ZDir','reverse', ...
             'Color',[0.82 0.92 0.96], ...
             'GridColor',[0.55 0.70 0.80], ...
             'GridAlpha',0.35, 'Box','on');

    %% =====================================================================
    %   2. BATHYMETRIC SEABED
    % ======================================================================
    [Xbed, Ybed] = meshgrid(0:5:X_MAX, 0:5:Y_MAX);
    Zbed = 56.0 + 2.5*sin(Xbed/22).*cos(Ybed/26) + 1.2*sin((Xbed+Ybed)/18);
    surf(hAx, Xbed, Ybed, Zbed, 'FaceColor',[0.74 0.69 0.58], ...
         'EdgeColor','none','FaceAlpha',0.95);

    %% =====================================================================
    %   3. PROCEDURAL BOULDERS (14)
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
        [sx,sy,sz] = sphere(22);
        noise = 1.0 + 0.22*sin(3*sx).*cos(3*sy) + 0.12*cos(5*sz) + 0.08*(rand(size(sx))-0.5);
        rx = cx + baseR*sx.*noise*1.15;
        ry = cy + baseR*sy.*noise*0.95;
        rz = cz + baseR*sz.*noise*0.85;
        rockModels{i}.center = [cx, cy, cz];
        rockModels{i}.radius = baseR * 1.08;
        surf(hAx, rx, ry, rz, 'FaceColor',[0.40 0.38 0.36], ...
             'EdgeColor','none','FaceAlpha',1.0);
    end

    %% =====================================================================
    %   4. KELP VEGETATION (14 CLUSTERS)
    % ======================================================================
    plantClusters = [
        25,30; 50,110; 80,70; 110,170; 150,45; 170,120;
        200,85; 225,180; 130,220; 70,225; 30,160; 190,220; 115,90; 165,160
    ];
    for p = 1:size(plantClusters,1)
        px = plantClusters(p,1); py = plantClusters(p,2);
        pz_bed = 56.0 + 2.5*sin(px/22)*cos(py/26);
        for stalk = 1:3
            stalkH = 12 + rand()*5;
            zNodes = linspace(pz_bed, pz_bed-stalkH, 16);
            xSway  = px + (rand()-0.5)*2.0 + 1.1*sin((pz_bed-zNodes)/2.5);
            ySway  = py + (rand()-0.5)*2.0 + 0.9*cos((pz_bed-zNodes)/2.8);
            plot3(hAx, xSway, ySway, zNodes, 'Color',[0.18 0.44 0.22],'LineWidth',2.0);
        end
    end

    %% =====================================================================
    %   5. SIDE PANELS (Distance Plot & HUD)
    % ======================================================================
    % Distance plot panel
    axDist = axes('Parent', hFig, 'Position', [0.67 0.55 0.30 0.38]);
    set(axDist, 'Color',[0.92 0.96 1.0], 'XColor',[0.1 0.2 0.3], 'YColor',[0.1 0.2 0.3]);
    hold(axDist,'on'); grid(axDist,'on');
    title(axDist,'Inter-AUV Range (m)','FontWeight','bold','Color',[0.05 0.15 0.25]);
    xlabel(axDist,'Step'); ylabel(axDist,'Distance (m)');
    hDistLine = plot(axDist, 0, norm([200-35, 200-35, 42-28]), 'Color',[0.1 0.5 0.9],'LineWidth',2);
    hCaptLine = yline(axDist, 8.0, 'r--', 'Capture','LineWidth',1.5,'Color',[0.8 0.1 0.1]);

    % HUD stats panel (text area)
    axHUD = axes('Parent', hFig, 'Position', [0.67 0.08 0.30 0.42]);
    axis(axHUD,'off');
    set(axHUD,'Color',[0.88 0.94 0.98]);
    hHUDText = text(axHUD, 0.05, 0.95, 'INITIALIZING...', ...
        'Units','normalized','VerticalAlignment','top', ...
        'FontSize',10,'FontName','Courier','Color',[0.05 0.15 0.25], ...
        'BackgroundColor',[0.93 0.97 1.0],'Margin',8, ...
        'Interpreter','none');

    % Legend panel at bottom
    axLeg = axes('Parent', hFig, 'Position', [0.05 0.04 0.58 0.12]);
    axis(axLeg,'off'); set(axLeg,'Color',[0.88 0.94 0.98]);
    text(axLeg,0.02,0.65,'● HIDER (You — steer with mouse)', 'Units','normalized','Color',[0.05 0.5 0.15],'FontSize',10,'FontWeight','bold');
    text(axLeg,0.02,0.25,'■ SEEKER (Autonomous AI + Sonar)', 'Units','normalized','Color',[0.75 0.1 0.1], 'FontSize',10,'FontWeight','bold');
    text(axLeg,0.55,0.65,'◀ Blue cone = active sonar beam','Units','normalized','Color',[0.05 0.4 0.75],'FontSize',10);
    text(axLeg,0.55,0.25,'★ Hide behind boulders for acoustic shadow!','Units','normalized','Color',[0.4 0.3 0.05],'FontSize',10);

    %% =====================================================================
    %   6. AGENT INITIAL POSITIONS & GRAPHICS HANDLES
    % ======================================================================
    global mouseTargetPos isSimRunning arenaBounds;
    arenaBounds     = [X_MAX, Y_MAX, Z_MAX];
    mouseTargetPos  = [200.0, 200.0, 42.0];
    isSimRunning    = true;

    hiderPos  = [200.0, 200.0, 42.0];
    seekerPos = [35.0,  35.0,  28.0];
    seekerVel = [0.0, 0.0, 0.0];

    % Agent markers
    hHider = plot3(hAx, hiderPos(1), hiderPos(2), hiderPos(3), 'o', ...
                   'MarkerSize',11, 'MarkerFaceColor',[0.15 0.7 0.3], ...
                   'MarkerEdgeColor',[0.05 0.35 0.15], 'LineWidth',1.5);
    hSeeker = plot3(hAx, seekerPos(1), seekerPos(2), seekerPos(3), 's', ...
                    'MarkerSize',12, 'MarkerFaceColor',[0.85 0.25 0.2], ...
                    'MarkerEdgeColor',[0.45 0.05 0.05], 'LineWidth',1.5);
    hPointerTarget = plot3(hAx, mouseTargetPos(1), mouseTargetPos(2), mouseTargetPos(3), ...
                           'x','MarkerSize',13,'LineWidth',2,'Color',[0.1 0.6 0.2]);

    % Trails
    hHiderTrail  = plot3(hAx, hiderPos(1), hiderPos(2), hiderPos(3), ...
                         '-', 'Color',[0.1 0.55 0.25],'LineWidth',1.4);
    hSeekerTrail = plot3(hAx, seekerPos(1), seekerPos(2), seekerPos(3), ...
                         '--','Color',[0.75 0.2 0.15],'LineWidth',1.2);

    % In-scene HUD label
    hInSceneHUD = text(hAx, 8, 12, 6, 'INITIALIZING...', ...
                       'FontSize',10,'FontWeight','bold','Color',[0.1 0.25 0.35], ...
                       'BackgroundColor',[0.95 0.98 1.0],'Margin',5);

    view(hAx, 38, 30); camlight('headlight'); lighting(hAx,'gouraud');

    % Mouse & close callbacks
    set(hFig,'WindowButtonMotionFcn', @(src,evt) onMouseMove(hAx));
    set(hFig,'CloseRequestFcn',       @(src,evt) onCloseFigure(src));

    %% =====================================================================
    %   7. PARTICLE FILTER STATE (50 particles for seeker estimate)
    % ======================================================================
    numParticles = 50;
    particles    = repmat(hiderPos, numParticles, 1) + randn(numParticles,3)*20;
    weights      = ones(numParticles,1) / numParticles;

    %% =====================================================================
    %   8. MAIN SIMULATION LOOP
    % ======================================================================
    sonarMaxRange      = 65.0;
    azimuthAperture    = deg2rad(38);
    elevationAperture  = deg2rad(24);
    sonarAzimuth       = deg2rad(0);
    sonarPitch         = deg2rad(6);
    captureRadius      = 8.0;
    stateNames         = {'SEARCH','TRACK','PURSUE'};
    hiderNames         = {'HIDE','SILENT','EVADE'};
    seekerState        = 1; hiderState = 1;

    hiderTrailX  = hiderPos(1);  hiderTrailY  = hiderPos(2);  hiderTrailZ  = hiderPos(3);
    seekerTrailX = seekerPos(1); seekerTrailY = seekerPos(2); seekerTrailZ = seekerPos(3);

    distHist = norm(hiderPos - seekerPos);
    stepHist = 0;

    hSonarMesh  = [];
    isLockedOn  = false;
    step        = 0;
    captured    = false;

    while isSimRunning && ishandle(hFig)
        step = step + 1;

        %% A. HIDER KINEMATICS (mouse-driven)
        diffPointer   = mouseTargetPos - hiderPos;
        distToPointer = norm(diffPointer);
        if distToPointer > 0.5
            hiderSpeed = min(2.40, distToPointer * 0.45);
            hiderPos   = hiderPos + hiderSpeed*(diffPointer/distToPointer);
        end
        % Hider AI state based on proximity to seeker
        distSH = norm(hiderPos - seekerPos);
        if distSH < 20
            hiderState = 3;
        elseif distSH < 50
            hiderState = 2;
        else
            hiderState = 1;
        end

        %% B. SONAR GEOMETRY
        delete(hSonarMesh);
        if ~isLockedOn
            % Wide patrol arc around arena centre
            patrolTarget = [125 + 85*cos(step*0.025), 125 + 85*sin(step*0.03), 30 + 6*sin(step*0.04)];
            dirP  = patrolTarget - seekerPos;
            seekerVel = 0.85*(dirP/norm(dirP));
            seekerPos = seekerPos + seekerVel;
            sonarAzimuth = mod(sonarAzimuth + deg2rad(9), 2*pi);
            sonarPitch   = deg2rad(7)*sin(step*0.10) + deg2rad(5);
            seekerState  = 1;
        else
            dirToHider   = hiderPos - seekerPos;
            speedS       = min(1.4, distSH * 0.05 + 0.6);
            seekerVel    = speedS*(dirToHider/norm(dirToHider));
            seekerPos    = seekerPos + seekerVel;
            sonarAzimuth = atan2(dirToHider(2), dirToHider(1));
            sonarPitch   = atan2(dirToHider(3), norm(dirToHider(1:2)));
            seekerState  = ternary(distSH < 25, 3, 2);
        end

        % Build conical sonar mesh
        [Rgrid,PhiGrid] = meshgrid(linspace(0,sonarMaxRange,8), linspace(0,2*pi,20));
        cLX = Rgrid;
        cLY = Rgrid.*tan(azimuthAperture).*cos(PhiGrid);
        cLZ = Rgrid.*tan(elevationAperture).*sin(PhiGrid);
        Rz  = [cos(sonarAzimuth) -sin(sonarAzimuth) 0; sin(sonarAzimuth) cos(sonarAzimuth) 0; 0 0 1];
        Ry  = [cos(sonarPitch) 0 sin(sonarPitch); 0 1 0; -sin(sonarPitch) 0 cos(sonarPitch)];
        Rot = Rz*Ry;
        cR  = Rot*[cLX(:)'; cLY(:)'; cLZ(:)'];
        cX  = seekerPos(1) + reshape(cR(1,:), size(Rgrid));
        cY  = seekerPos(2) + reshape(cR(2,:), size(Rgrid));
        cZ  = seekerPos(3) + reshape(cR(3,:), size(Rgrid));
        hSonarMesh = surf(hAx, cX, cY, cZ, ...
                          'FaceColor',[0.1 0.65 0.95],'EdgeColor','none','FaceAlpha',0.16);

        %% C. RAY-CAST OCCLUSION — ALL 14 BOULDERS
        relVec       = hiderPos - seekerPos;
        rangeToHider = norm(relVec);
        beamDir      = Rot*[1;0;0];
        cosA         = dot(relVec/rangeToHider, beamDir);
        targetAngle  = acos(max(-1.0, min(1.0, cosA)));
        isInsideBeam = (rangeToHider <= sonarMaxRange) && (targetAngle <= azimuthAperture);
        isOccluded   = false;

        if isInsideBeam
            rayDir = relVec / rangeToHider;
            for r = 1:numRocks
                rC   = rockModels{r}.center;
                rRad = rockModels{r}.radius;
                proj = dot(rC - seekerPos, rayDir);
                if proj > 0 && proj < rangeToHider
                    perpDist = norm((seekerPos + proj*rayDir) - rC);
                    if perpDist <= rRad
                        isOccluded = true; break;
                    end
                end
            end
        end

        %% D. PARTICLE FILTER UPDATE
        if isInsideBeam && ~isOccluded
            meas = hiderPos + randn(1,3)*3.0;
        else
            meas = seekerPos + randn(1,3)*30.0;
        end
        particles  = particles + randn(numParticles,3)*1.5;
        distsP     = vecnorm(particles - meas, 2, 2);
        weights    = exp(-distsP.^2/(2*15^2));
        weights    = weights / sum(weights);
        idxR       = drawRandomIdx(weights, numParticles);
        particles  = particles(idxR,:);

        %% E. CAPTURE CHECK
        if distSH <= captureRadius
            captured = true;
        end

        %% F. LOCK-ON & STATUS DISPLAY
        if isInsideBeam && ~isOccluded
            isLockedOn = true;
            sonarColor = [0.95 0.25 0.1];
            sonarAlpha = 0.28;
            statusStr  = sprintf('⚠ ALERT: HIDER SPOTTED! PURSUING\n  Range: %.1f m  Step: %d', rangeToHider, step);
            statusCol  = [0.80 0.05 0.05];
            set(hHider, 'MarkerFaceColor',[0.9 0.1 0.1],'MarkerSize',14);
        elseif isInsideBeam && isOccluded
            isLockedOn = false;
            sonarColor = [0.15 0.65 0.95];
            sonarAlpha = 0.16;
            statusStr  = sprintf('★ SHADOW ZONE — Boulder occlusion active\n  Range: %.1f m  Step: %d', rangeToHider, step);
            statusCol  = [0.55 0.40 0.05];
            set(hHider, 'MarkerFaceColor',[0.15 0.70 0.30],'MarkerSize',11);
        else
            isLockedOn = false;
            sonarColor = [0.1 0.65 0.95];
            sonarAlpha = 0.16;
            statusStr  = sprintf('◉ SEARCHING — Steer hider with mouse\n  Range: %.1f m  Step: %d', rangeToHider, step);
            statusCol  = [0.1 0.25 0.35];
            set(hHider, 'MarkerFaceColor',[0.15 0.70 0.30],'MarkerSize',11);
        end
        set(hSonarMesh, 'FaceColor', sonarColor, 'FaceAlpha', sonarAlpha);
        set(hInSceneHUD, 'String', statusStr, 'Color', statusCol);

        % Rich HUD panel
        hudLines = sprintf([ ...
            '┌──────────────────────────────┐\n' ...
            '│  STATUS TELEMETRY HUD        │\n' ...
            '├──────────────────────────────┤\n' ...
            '│ Step        : %6d         │\n' ...
            '│ Range       : %6.1f m      │\n' ...
            '│ Sonar       : %-12s   │\n' ...
            '│ Seeker Mode : %-12s   │\n' ...
            '│ Hider Mode  : %-12s   │\n' ...
            '├──────────────────────────────┤\n' ...
            '│ Seeker Pos  : (%.0f, %.0f, %.0f)  │\n' ...
            '│ Hider Pos   : (%.0f, %.0f, %.0f)  │\n' ...
            '└──────────────────────────────┘'], ...
            step, rangeToHider, ...
            ternaryStr(isInsideBeam && ~isOccluded, 'LOCKED ON', 'SCANNING'), ...
            stateNames{seekerState}, hiderNames{hiderState}, ...
            seekerPos(1), seekerPos(2), seekerPos(3), ...
            hiderPos(1),  hiderPos(2),  hiderPos(3));
        set(hHUDText, 'String', hudLines);

        %% G. GRAPHICS UPDATE
        set(hHider,         'XData',hiderPos(1),  'YData',hiderPos(2),  'ZData',hiderPos(3));
        set(hSeeker,        'XData',seekerPos(1), 'YData',seekerPos(2), 'ZData',seekerPos(3));
        set(hPointerTarget, 'XData',mouseTargetPos(1),'YData',mouseTargetPos(2),'ZData',mouseTargetPos(3));

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

        % Distance plot
        distHist(end+1) = distSH; %#ok<AGROW>
        stepHist(end+1) = step;   %#ok<AGROW>
        set(hDistLine, 'XData', stepHist, 'YData', distHist);

        drawnow limitrate;
        pause(0.025);

        if captured
            set(hInSceneHUD, 'String', sprintf('>>> CAPTURE! Range: %.1f m <<<', distSH), 'Color', [0.8 0.05 0.05]);
            set(hHUDText, 'String', sprintf('GAME OVER — SEEKER WINS!\nCapture at step %d\nFinal range: %.1f m', step, distSH));
            drawnow;
            pause(3);
            break;
        end
    end
end

%% =========================================================================
%   MOUSE CALLBACK
% =========================================================================
function onMouseMove(hAx)
    global mouseTargetPos arenaBounds;
    cp     = get(hAx, 'CurrentPoint');
    pFront = cp(1,:); pBack = cp(2,:);
    targetZ = 42.0;
    if abs(pBack(3) - pFront(3)) > 1e-9
        t = (targetZ - pFront(3)) / (pBack(3) - pFront(3));
        tX = pFront(1) + t*(pBack(1)-pFront(1));
        tY = pFront(2) + t*(pBack(2)-pFront(2));
        mouseTargetPos = [max(5, min(arenaBounds(1)-5, tX)), ...
                          max(5, min(arenaBounds(2)-5, tY)), targetZ];
    end
end

function onCloseFigure(figHandle)
    global isSimRunning;
    isSimRunning = false;
    delete(figHandle);
end

%% =========================================================================
%   HELPERS
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

function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function s = ternaryStr(cond, a, b)
    if cond, s = a; else, s = b; end
end
