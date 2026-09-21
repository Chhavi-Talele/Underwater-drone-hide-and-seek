classdef GameVisualizer < handle
%GAMEVISUALIZER  Real-time 4-panel MATLAB dashboard for Hide-and-Seek.
%
%   Panel layout:
%   ┌──────────────────┬──────────────────┐
%   │  1. 3-D Scene    │  2. Top-down Map │
%   ├──────────────────┼──────────────────┤
%   │  3. Sonar HUD    │  4. Game Stats   │
%   └──────────────────┴──────────────────┘
%
%   Panel 1 — 3-D Scene:   Both drones + terrain + particle cloud
%   Panel 2 — Top-down:    XY floor plan, drone trails, belief heatmap
%   Panel 3 — Sonar HUD:   Polar plot — bearing arc, signal strength
%   Panel 4 — Stats:       Time, distance, detection count, state labels
%
%   Usage
%   -----
%     vis = GameVisualizer();
%     vis.init(env);
%     % each game tick:
%     vis.update(seekerState, hiderState, sonarResult, simTime, maxTime);
%     % game over:
%     vis.showOutcome('Seeker Wins!', simTime);

    properties
        % Figure handle
        Fig

        % Axes handles
        Ax3D        % 3D scene
        AxTop       % top-down map
        AxSonar     % polar sonar HUD
        AxStats     % stats text panel

        % Graphics object handles (updated each tick)
        hSeeker3D
        hHider3D
        hSeekerTrail3D
        hHiderTrail3D
        hParticles3D
        hSeekerTop
        hHiderTop
        hSeekerTrailTop
        hHiderTrailTop
        hHeatmap
        hSonarArc
        hSonarBearing
        hBearingLine

        % Text handles for stats panel
        tTime
        tDist
        tDetections
        tSeekerState
        tHiderState
        tUncertainty

        % Colourmap for belief heatmap (particle density)
        BeliefGrid   % [gridH x gridW] accumulated density
        GridResolution (1,1) double = 10   % metres per grid cell

        % Environment reference (for bounds)
        Env

        % Whether visualiser window is open
        Active (1,1) logical = false
    end

    % ------------------------------------------------------------------ %
    methods

        function init(obj, env)
        %INIT  Create the dashboard figure and all graphic objects.
        %   env : UnderwaterEnvironment (must be initialised)

            obj.Env = env;
            B = env.Bounds;

            % ---- Create figure ----
            obj.Fig = figure( ...
                'Name',       'Underwater Drone Hide & Seek', ...
                'NumberTitle','off', ...
                'Color',      [0.08 0.10 0.14], ...
                'Position',   [50 50 1400 780], ...
                'Resize',     'on');

            % ---- Panel 1: 3-D Scene ----
            obj.Ax3D = subplot(2, 2, 1, 'Parent', obj.Fig);
            show(env.OccupancyMap, 'Parent', obj.Ax3D);
            hold(obj.Ax3D, 'on');
            obj.styleAx(obj.Ax3D, '3-D Scene');
            view(obj.Ax3D, 45, 25);
            axis(obj.Ax3D, 'tight');

            % Drone markers — 3D
            obj.hSeeker3D = plot3(obj.Ax3D, 0, 0, 0, ...
                'o', 'MarkerSize', 14, 'MarkerFaceColor', [0.2 0.5 1.0], ...
                'MarkerEdgeColor','w', 'LineWidth', 1.5);
            obj.hHider3D = plot3(obj.Ax3D, 0, 0, 0, ...
                's', 'MarkerSize', 14, 'MarkerFaceColor', [1.0 0.3 0.2], ...
                'MarkerEdgeColor','w', 'LineWidth', 1.5);
            obj.hSeekerTrail3D = plot3(obj.Ax3D, NaN, NaN, NaN, ...
                '-', 'Color', [0.3 0.6 1.0 0.5], 'LineWidth', 1.5);
            obj.hHiderTrail3D = plot3(obj.Ax3D, NaN, NaN, NaN, ...
                '-', 'Color', [1.0 0.4 0.3 0.5], 'LineWidth', 1.5);
            obj.hParticles3D = scatter3(obj.Ax3D, NaN, NaN, NaN, ...
                12, 'filled', 'MarkerFaceColor', [1.0 0.9 0.2], ...
                'MarkerFaceAlpha', 0.4);

            legend(obj.Ax3D, {'Seeker','Hider','Seeker trail','Hider trail','Particles'}, ...
                'TextColor','w', 'Color',[0.1 0.12 0.16], 'Location','northwest');

            % ---- Panel 2: Top-down map ----
            obj.AxTop = subplot(2, 2, 2, 'Parent', obj.Fig);
            hold(obj.AxTop, 'on');
            obj.styleAx(obj.AxTop, 'Top-down View + Belief Heatmap');
            xlim(obj.AxTop, B.X); ylim(obj.AxTop, B.Y);
            xlabel(obj.AxTop, 'X (m)'); ylabel(obj.AxTop, 'Y (m)');

            % Pre-allocate belief heatmap grid
            gridW = ceil(diff(B.X) / obj.GridResolution) + 1;
            gridH = ceil(diff(B.Y) / obj.GridResolution) + 1;
            obj.BeliefGrid = zeros(gridH, gridW);

            xEdge = B.X(1) : obj.GridResolution : B.X(2);
            yEdge = B.Y(1) : obj.GridResolution : B.Y(2);
            obj.hHeatmap = imagesc(obj.AxTop, xEdge, yEdge, obj.BeliefGrid, ...
                'AlphaData', obj.BeliefGrid);
            colormap(obj.AxTop, obj.hotAlpha());
            set(obj.AxTop, 'YDir','normal');

            obj.hSeekerTop = plot(obj.AxTop, 0, 0, ...
                'o', 'MarkerSize',12, 'MarkerFaceColor',[0.2 0.5 1.0], ...
                'MarkerEdgeColor','w', 'LineWidth',1.5);
            obj.hHiderTop = plot(obj.AxTop, 0, 0, ...
                's', 'MarkerSize',12, 'MarkerFaceColor',[1.0 0.3 0.2], ...
                'MarkerEdgeColor','w', 'LineWidth',1.5);
            obj.hSeekerTrailTop = plot(obj.AxTop, NaN, NaN, ...
                '-', 'Color',[0.3 0.6 1.0], 'LineWidth',1.2);
            obj.hHiderTrailTop = plot(obj.AxTop, NaN, NaN, ...
                '-', 'Color',[1.0 0.4 0.3], 'LineWidth',1.2);

            % ---- Panel 3: Sonar HUD ----
            obj.AxSonar = subplot(2, 2, 3, 'Parent', obj.Fig);
            obj.styleAx(obj.AxSonar, 'Sonar HUD');
            obj.AxSonar.Visible = 'off';
            obj.AxSonar = polaraxes('Parent', obj.Fig, ...
                'Position', obj.AxSonar.Position);
            obj.AxSonar.Color         = [0.06 0.09 0.13];
            obj.AxSonar.GridColor     = [0.4 0.4 0.4];
            obj.AxSonar.RColor        = [0.6 0.6 0.6];
            obj.AxSonar.ThetaColor    = [0.6 0.6 0.6];
            obj.AxSonar.Title.String  = 'Sonar HUD';
            obj.AxSonar.Title.Color   = [0.85 0.85 0.85];
            obj.AxSonar.RLim          = [0, 125];
            hold(obj.AxSonar, 'on');

            % Sonar range ring
            theta = linspace(0, 2*pi, 200);
            polarplot(obj.AxSonar, theta, 125*ones(size(theta)), ...
                '--', 'Color', [0.3 0.5 0.3], 'LineWidth', 1);

            obj.hSonarArc = polarplot(obj.AxSonar, [0 0], [0 0], ...
                'Color', [1.0 0.8 0.2], 'LineWidth', 3);
            obj.hSonarBearing = polarplot(obj.AxSonar, [0 0], [0 0], ...
                'Color', [1.0 0.3 0.2], 'LineWidth', 2);

            % ---- Panel 4: Game Stats ----
            obj.AxStats = subplot(2, 2, 4, 'Parent', obj.Fig);
            obj.styleAx(obj.AxStats, 'Game Statistics');
            axis(obj.AxStats, 'off');

            yPos = 0.92;
            dy   = 0.13;
            labels = {'⏱  Time Remaining', '📡  Seeker–Hider Distance', ...
                      '🔊  Detections', '🔵  Seeker State', ...
                      '🔴  Hider State', '🎯  Belief Uncertainty'};
            vals   = {'—', '—', '—', '—', '—', '—'};
            tHandles = gobjects(6,1);
            for i = 1:6
                text(obj.AxStats, 0.05, yPos - (i-1)*dy, ...
                    [labels{i} ':  '], ...
                    'Color', [0.55 0.6 0.65], 'FontSize', 10, ...
                    'FontName', 'Courier', 'Units', 'normalized');
                tHandles(i) = text(obj.AxStats, 0.55, yPos - (i-1)*dy, vals{i}, ...
                    'Color', [0.95 0.95 0.95], 'FontSize', 11, ...
                    'FontWeight', 'bold', 'FontName', 'Courier', ...
                    'Units', 'normalized');
            end
            obj.tTime        = tHandles(1);
            obj.tDist        = tHandles(2);
            obj.tDetections  = tHandles(3);
            obj.tSeekerState = tHandles(4);
            obj.tHiderState  = tHandles(5);
            obj.tUncertainty = tHandles(6);

            drawnow;
            obj.Active = true;
            fprintf('[GameVisualizer] Dashboard ready.\n');
        end

        % -------------------------------------------------------------- %
        function update(obj, seekerState, hiderState, sonarResult, simTime, maxTime)
        %UPDATE  Refresh all panels with current game state.
        %
        %   seekerState : struct from SeekerAUV.getState()
        %   hiderState  : struct from HiderAUV.getState()
        %   sonarResult : struct from AcousticSonarModel.detect()
        %   simTime     : elapsed seconds
        %   maxTime     : total game duration seconds

            if ~obj.Active || ~isvalid(obj.Fig)
                return;
            end

            sP = seekerState.pose(1:3);
            hP = hiderState.pose(1:3);
            dist = norm(sP - hP);

            % ---- Panel 1: 3-D ----
            set(obj.hSeeker3D, 'XData', sP(1), 'YData', sP(2), 'ZData', sP(3));
            set(obj.hHider3D,  'XData', hP(1), 'YData', hP(2), 'ZData', hP(3));

            if ~isempty(seekerState.particles)
                pw = max(seekerState.weights) * seekerState.weights / max(seekerState.weights+eps);
                set(obj.hParticles3D, ...
                    'XData', seekerState.particles(:,1), ...
                    'YData', seekerState.particles(:,2), ...
                    'ZData', seekerState.particles(:,3), ...
                    'SizeData', 8 + 30*pw);
            end

            % Trails
            obj.updateTrail3D(obj.hSeekerTrail3D, sP);
            obj.updateTrail3D(obj.hHiderTrail3D,  hP);

            % ---- Panel 2: Top-down ----
            set(obj.hSeekerTop, 'XData', sP(1), 'YData', sP(2));
            set(obj.hHiderTop,  'XData', hP(1), 'YData', hP(2));
            obj.updateTrail2D(obj.hSeekerTrailTop, sP);
            obj.updateTrail2D(obj.hHiderTrailTop,  hP);

            % Belief heatmap from particles
            if ~isempty(seekerState.particles)
                B = obj.Env.Bounds;
                gw = size(obj.BeliefGrid, 2);
                gh = size(obj.BeliefGrid, 1);
                px = seekerState.particles(:,1);
                py = seekerState.particles(:,2);
                xi = round((px - B.X(1)) / obj.GridResolution) + 1;
                yi = round((py - B.Y(1)) / obj.GridResolution) + 1;
                xi = max(1, min(gw, xi));
                yi = max(1, min(gh, yi));
                obj.BeliefGrid = obj.BeliefGrid * 0.85;  % decay
                for k = 1:length(xi)
                    obj.BeliefGrid(yi(k), xi(k)) = ...
                        obj.BeliefGrid(yi(k), xi(k)) + seekerState.weights(k);
                end
                set(obj.hHeatmap, 'CData', obj.BeliefGrid, ...
                    'AlphaData', min(1, obj.BeliefGrid * 8));
            end

            % ---- Panel 3: Sonar HUD ----
            if ~isempty(sonarResult) && sonarResult.detected
                theta = sonarResult.bearing;
                sig   = sonarResult.signalLevel;
                arc_r = sig;   % radius = signal strength (max 100)
                % Draw bearing line
                set(obj.hSonarBearing, 'ThetaData', [theta theta], ...
                    'RData', [0, arc_r]);
                % Draw ±7.5° accuracy arc
                arcTheta = linspace(theta - 7.5*pi/180, theta + 7.5*pi/180, 30);
                set(obj.hSonarArc, 'ThetaData', arcTheta, ...
                    'RData', arc_r * ones(size(arcTheta)));
            else
                set(obj.hSonarBearing, 'ThetaData', [0 0], 'RData', [0 0]);
                set(obj.hSonarArc,     'ThetaData', [0 0], 'RData', [0 0]);
            end

            % ---- Panel 4: Stats ----
            remaining = max(0, maxTime - simTime);
            set(obj.tTime,        'String', sprintf('%.0f s', remaining));
            set(obj.tDist,        'String', sprintf('%.1f m', dist));
            set(obj.tDetections,  'String', sprintf('%d', seekerState.detections));
            set(obj.tSeekerState, 'String', upper(seekerState.state));
            set(obj.tHiderState,  'String', upper(hiderState.state));

            if isfield(seekerState, 'uncertainty')
                set(obj.tUncertainty, 'String', sprintf('%.1f m', seekerState.uncertainty));
            end

            % Colour seeker state label
            stateColors = struct('search',[0.6 0.8 1.0],'track',[1.0 0.9 0.3],'pursue',[1.0 0.4 0.2]);
            if isfield(stateColors, seekerState.state)
                set(obj.tSeekerState, 'Color', stateColors.(seekerState.state));
            end

            drawnow limitrate;
        end

        % -------------------------------------------------------------- %
        function showOutcome(obj, message, simTime)
        %SHOWOUTCOME  Overlay a game-over message on all panels.
            if ~obj.Active || ~isvalid(obj.Fig)
                return;
            end
            for ax = [obj.Ax3D, obj.AxTop]
                text(ax, 'Units','normalized', 'Position',[0.5 0.5], ...
                    'String', message, ...
                    'FontSize', 22, 'FontWeight','bold', ...
                    'Color', [1 0.9 0.2], ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor',[0.05 0.07 0.10], ...
                    'EdgeColor',[0.8 0.7 0.1]);
            end
            fprintf('\n=== GAME OVER: %s (t=%.1f s) ===\n', message, simTime);
            drawnow;
        end

    end % public methods

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function styleAx(~, ax, titleStr)
        %STYLEAX  Apply dark-theme styling to a Cartesian axes.
            set(ax, 'Color',      [0.06 0.09 0.13], ...
                    'XColor',     [0.55 0.6 0.65], ...
                    'YColor',     [0.55 0.6 0.65], ...
                    'ZColor',     [0.55 0.6 0.65], ...
                    'GridColor',  [0.25 0.28 0.32], ...
                    'GridAlpha',  0.5, ...
                    'FontName',   'Courier', ...
                    'FontSize',   9);
            title(ax, titleStr, 'Color', [0.85 0.85 0.85], ...
                'FontWeight','bold', 'FontName','Courier');
            grid(ax, 'on');
        end

        % -------------------------------------------------------------- %
        function updateTrail3D(~, h, newPt)
        %UPDATETRAIL3D  Append a point to a 3-D trail line.
            xd = [get(h,'XData'), newPt(1)];
            yd = [get(h,'YData'), newPt(2)];
            zd = [get(h,'ZData'), newPt(3)];
            % Keep last 500 points
            if length(xd) > 500
                xd = xd(end-499:end);
                yd = yd(end-499:end);
                zd = zd(end-499:end);
            end
            set(h, 'XData',xd, 'YData',yd, 'ZData',zd);
        end

        % -------------------------------------------------------------- %
        function updateTrail2D(~, h, newPt)
        %UPDATETRAIL2D  Append a point to a 2-D trail line.
            xd = [get(h,'XData'), newPt(1)];
            yd = [get(h,'YData'), newPt(2)];
            if length(xd) > 500
                xd = xd(end-499:end);
                yd = yd(end-499:end);
            end
            set(h, 'XData',xd, 'YData',yd);
        end

        % -------------------------------------------------------------- %
        function cmap = hotAlpha(~)
        %HOTALPHA  Custom hot colourmap for belief heatmap.
            cmap = hot(256);
            % Shift toward yellow-orange for belief blobs
            cmap(:,1) = 1;
            cmap(:,2) = linspace(0,1,256)';
            cmap(:,3) = linspace(0,0.3,256)';
        end

    end % private methods

end % classdef
