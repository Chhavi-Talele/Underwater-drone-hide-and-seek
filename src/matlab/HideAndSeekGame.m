classdef HideAndSeekGame < handle
%HIDEANDSEEKGAME  Top-level orchestrator for the Underwater Drone Hide-and-Seek game.
%
%   Sets up the environment, both AUV agents, sonar model, and visualiser,
%   then runs the main game loop until win/loss condition is met.
%
%   Win conditions:
%     - SEEKER WINS  : Seeker gets within CaptureRadius of Hider
%     - HIDER WINS   : Game time expires (MaxTime seconds) without capture
%
%   Usage
%   -----
%     game = HideAndSeekGame();
%     game.SeekerStart = [10 10 -20 0];
%     game.HiderStart  = [180 180 -55 pi];
%     game.MaxTime     = 300;
%     result = game.run();
%
%   Monte Carlo usage:
%     results = HideAndSeekGame.runMonteCarlo(10);

    % ------------------------------------------------------------------ %
    properties
        % ---- Agent starting poses [x y z heading_rad] ----
        SeekerStart (1,4) double = [10,  10,  -20, 0]
        HiderStart  (1,4) double = [180, 180, -55, pi]

        % ---- Game rules ----
        MaxTime        (1,1) double = 300   % seconds
        CaptureRadius  (1,1) double = 8     % metres
        Dt             (1,1) double = 0.5   % simulation timestep (s)

        % ---- Visualisation ----
        EnableVisualization (1,1) logical = true

        % ---- Verbose logging ----
        Verbose (1,1) logical = true
    end

    % ------------------------------------------------------------------ %
    properties (SetAccess = private)
        % Shared environment
        Env         UnderwaterEnvironment

        % Agents
        Seeker      SeekerAUV
        Hider       HiderAUV

        % Acoustic sonar
        Sonar       AcousticSonarModel

        % Visualiser (may be empty if disabled)
        Vis         GameVisualizer

        % Simulation clock
        SimTime     (1,1) double = 0

        % Game outcome: 'seeker' | 'hider' | '' (in progress)
        Winner      (1,:) char = ''

        % Log of key events
        EventLog    cell = {}

        % Full telemetry log (struct array, one entry per tick)
        Telemetry   struct

        % Whether game has been run
        HasRun      (1,1) logical = false
    end

    % ------------------------------------------------------------------ %
    methods

        function obj = HideAndSeekGame(varargin)
        %HIDEANDSEEKGAME  Constructor. Accepts name-value pairs for any property.
        %   Example: game = HideAndSeekGame('MaxTime', 600, 'EnableVisualization', false);
            for i = 1:2:length(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
        end

        % -------------------------------------------------------------- %
        function result = run(obj)
        %RUN  Execute the full game loop. Returns a result struct.
        %
        %   result.winner    : 'seeker' or 'hider'
        %   result.time      : elapsed time at game end (s)
        %   result.captures  : capture distance at each tick (Nx1)
        %   result.telemetry : full per-tick log

            obj.setup();
            result = obj.gameLoop();
            obj.HasRun = true;
        end

        % -------------------------------------------------------------- %
        function plotTelemetry(obj)
        %PLOTTELEMETRY  Post-game analysis plots.
            if ~obj.HasRun || isempty(obj.Telemetry)
                warning('Run game first.'); return;
            end
            times  = [obj.Telemetry.time];
            dists  = [obj.Telemetry.distance];
            sigs   = [obj.Telemetry.signalLevel];

            figure('Name','Post-Game Analysis','Color',[0.08 0.10 0.14],'Position',[100 100 900 400]);

            ax1 = subplot(1,2,1);
            plot(ax1, times, dists, 'Color',[0.3 0.7 1.0], 'LineWidth',2);
            yline(ax1, obj.CaptureRadius, '--r', 'Capture Radius');
            xlabel(ax1,'Time (s)'); ylabel(ax1,'Distance (m)');
            title(ax1,'Seeker–Hider Distance Over Time','Color','w');
            set(ax1,'Color',[0.06 0.09 0.13],'XColor','w','YColor','w');
            grid(ax1,'on');

            ax2 = subplot(1,2,2);
            plot(ax2, times, sigs, 'Color',[1.0 0.8 0.2], 'LineWidth',1.5);
            xlabel(ax2,'Time (s)'); ylabel(ax2,'Sonar Signal Level (%)');
            title(ax2,'Acoustic Signal Level Over Time','Color','w');
            set(ax2,'Color',[0.06 0.09 0.13],'XColor','w','YColor','w');
            grid(ax2,'on');
        end

    end % public methods

    % ------------------------------------------------------------------ %
    methods (Static)

        function results = runMonteCarlo(nTrials, gameParams)
        %RUNMONTECARLO  Run nTrials independent games and collect statistics.
        %
        %   gameParams : (optional) cell array of name-value pairs for HideAndSeekGame
        %   results    : struct with fields:
        %                  .seekerWins, .hiderWins, .meanCaptureTime
            if nargin < 2, gameParams = {}; end

            seekerWins = 0;
            captureTimes = [];

            fprintf('Running %d Monte Carlo trials...\n', nTrials);
            for i = 1:nTrials
                fprintf('  Trial %d/%d\n', i, nTrials);
                game = HideAndSeekGame('EnableVisualization', false, 'Verbose', false, gameParams{:});
                r    = game.run();
                if strcmp(r.winner, 'seeker')
                    seekerWins = seekerWins + 1;
                    captureTimes(end+1) = r.time; %#ok<AGROW>
                end
            end

            hiderWins = nTrials - seekerWins;
            results.seekerWins    = seekerWins;
            results.hiderWins     = hiderWins;
            results.seekerWinRate = seekerWins / nTrials;
            results.meanCaptureTime = mean(captureTimes);
            results.stdCaptureTime  = std(captureTimes);

            fprintf('\n=== Monte Carlo Results (%d trials) ===\n', nTrials);
            fprintf('  Seeker win rate : %.1f%%\n', results.seekerWinRate*100);
            fprintf('  Mean capture time: %.1f s (std %.1f s)\n', ...
                results.meanCaptureTime, results.stdCaptureTime);
        end

    end % static methods

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function setup(obj)
        %SETUP  Initialise all simulation components.

            obj.log('=== Underwater Drone Hide & Seek ===');
            obj.log(sprintf('MaxTime=%.0fs  CaptureRadius=%.1fm  dt=%.2fs', ...
                obj.MaxTime, obj.CaptureRadius, obj.Dt));

            % Add utils to path
            utilsDir = fullfile(fileparts(mfilename('fullpath')), 'utils');
            addpath(utilsDir);

            % Environment
            obj.Env = UnderwaterEnvironment();
            obj.Env.init();

            % Agents
            obj.Seeker        = SeekerAUV(obj.Env);
            obj.Seeker.Pose   = obj.SeekerStart;
            obj.Seeker.init();

            obj.Hider         = HiderAUV(obj.Env);
            obj.Hider.Pose    = obj.HiderStart;
            obj.Hider.init();

            % Sonar
            obj.Sonar = AcousticSonarModel(obj.Env);

            % Visualiser
            if obj.EnableVisualization
                obj.Vis = GameVisualizer();
                obj.Vis.init(obj.Env);
            end

            obj.SimTime  = 0;
            obj.Winner   = '';
            obj.Telemetry = struct('time',{},'distance',{},'signalLevel',{},...
                'seekerState',{},'hiderState',{});
            obj.EventLog = {};

            obj.log('Setup complete. Starting game loop...');
        end

        % -------------------------------------------------------------- %
        function result = gameLoop(obj)
        %GAMELOOP  Main simulation loop.

            while obj.SimTime <= obj.MaxTime && isempty(obj.Winner)

                % 1. Acoustic detection (only if Hider is not suppressing pings)
                sonarResult = obj.Sonar.emptyResult();
                if ~obj.Hider.isPingSuppressed()
                    sonarResult = obj.Sonar.detect( ...
                        obj.Hider.Pose, obj.Seeker.Pose, obj.SimTime);
                end

                % 2. Step both agents
                obj.Seeker.step(obj.Dt, obj.SimTime, sonarResult);
                obj.Hider.step(obj.Dt, obj.SimTime, obj.Seeker.Pose);

                % 3. Check win condition
                dist = obj.Seeker.distanceTo(obj.Hider.Pose);
                if dist <= obj.CaptureRadius
                    obj.Winner = 'seeker';
                    obj.log(sprintf('CAPTURE at t=%.1fs! Distance=%.2fm', ...
                        obj.SimTime, dist));
                    break;
                end

                % 4. Log telemetry
                entry.time        = obj.SimTime;
                entry.distance    = dist;
                entry.signalLevel = sonarResult.signalLevel;
                entry.seekerState = obj.Seeker.State;
                entry.hiderState  = obj.Hider.State;
                obj.Telemetry(end+1) = entry;

                % 5. Update visualiser
                if obj.EnableVisualization && ~isempty(obj.Vis) && obj.Vis.Active
                    sk = obj.Seeker.getState();
                    hk = obj.Hider.getState();
                    obj.Vis.update(sk, hk, sonarResult, obj.SimTime, obj.MaxTime);
                end

                % 6. Advance clock
                obj.SimTime = obj.SimTime + obj.Dt;
            end

            % Time-out → Hider wins
            if isempty(obj.Winner)
                obj.Winner = 'hider';
                obj.log(sprintf('TIME EXPIRED at t=%.1fs → Hider wins!', obj.SimTime));
            end

            % Final visualisation overlay
            if obj.EnableVisualization && ~isempty(obj.Vis) && obj.Vis.Active
                switch obj.Winner
                    case 'seeker', msg = '🔵 SEEKER CAPTURES THE HIDER!';
                    case 'hider',  msg = '🔴 HIDER SURVIVES — HIDER WINS!';
                end
                obj.Vis.showOutcome(msg, obj.SimTime);
            end

            result.winner    = obj.Winner;
            result.time      = obj.SimTime;
            result.telemetry = obj.Telemetry;
        end

        % -------------------------------------------------------------- %
        function log(obj, msg)
        %LOG  Printf + store message if verbose.
            obj.EventLog{end+1} = msg;
            if obj.Verbose
                fprintf('[Game] %s\n', msg);
            end
        end

    end % private methods

end % classdef
