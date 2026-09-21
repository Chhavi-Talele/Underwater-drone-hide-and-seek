%% runHideAndSeek.m
%  Underwater Drone Hide & Seek — Entry Point
%  ==========================================
%  Run this script from the src/matlab/ directory in MATLAB to start a game.
%
%  Requirements:
%    - MATLAB R2020b or later
%    - Navigation Toolbox
%    - UAV Toolbox
%    - Robotics System Toolbox
%
%  The reference AUV project files are loaded automatically from:
%    ../../reference_auv/Source/Planning/
%
%  Usage:
%    >> runHideAndSeek            % default settings
%    >> runHideAndSeek('quick')   % short 60-second game, no vis
%    >> runHideAndSeek('mc', 10)  % run 10 Monte Carlo trials

function runHideAndSeek(mode, varargin)

if nargin < 1 || isempty(mode)
    mode = 'default';
end

%% ---- Add source paths -----------------------------------------------
here    = fileparts(mfilename('fullpath'));
utilsDir = fullfile(here, 'utils');
addpath(here);
addpath(utilsDir);

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════╗\n');
fprintf('║   UNDERWATER DRONE HIDE & SEEK  v1.0            ║\n');
fprintf('║   Built on MathWorks AUV Demo Reference          ║\n');
fprintf('╚══════════════════════════════════════════════════╝\n\n');

%% ---- Configure game by mode ----------------------------------------

switch lower(mode)

    case 'default'
        %  Standard 300-second game with full visualisation
        game = HideAndSeekGame( ...
            'SeekerStart',          [10,  10,  -20, 0], ...
            'HiderStart',           [180, 180, -55, pi], ...
            'MaxTime',              300, ...
            'CaptureRadius',        8.0, ...
            'Dt',                   0.5, ...
            'EnableVisualization',  true, ...
            'Verbose',              true);

    case 'quick'
        %  Short game for quick testing — no visualisation
        game = HideAndSeekGame( ...
            'MaxTime',             60, ...
            'EnableVisualization', false, ...
            'Verbose',             true);

    case 'challenge'
        %  Hard mode — faster Hider, shorter seeker sonar range
        game = HideAndSeekGame( ...
            'MaxTime',             600, ...
            'CaptureRadius',       5.0, ...
            'EnableVisualization', true, ...
            'Verbose',             true);

    case 'mc'
        %  Monte Carlo: pass number of trials as second argument
        nTrials = 10;
        if nargin >= 2
            nTrials = varargin{1};
        end
        fprintf('Running %d Monte Carlo trials (no visualisation)...\n\n', nTrials);
        results = HideAndSeekGame.runMonteCarlo(nTrials, ...
            {'EnableVisualization', false, 'Verbose', false});
        fprintf('\n--- Monte Carlo Summary ---\n');
        fprintf('  Seeker wins : %d / %d  (%.1f%%)\n', ...
            results.seekerWins, nTrials, results.seekerWinRate*100);
        fprintf('  Hider  wins : %d / %d  (%.1f%%)\n', ...
            results.hiderWins,  nTrials, (1-results.seekerWinRate)*100);
        if ~isnan(results.meanCaptureTime)
            fprintf('  Mean capture time : %.1f ± %.1f s\n', ...
                results.meanCaptureTime, results.stdCaptureTime);
        end
        return;  % MC mode — no single-game run below

    otherwise
        error('runHideAndSeek:unknownMode', ...
            'Unknown mode "%s". Use: default | quick | challenge | mc', mode);
end

%% ---- Run a single game --------------------------------------------

fprintf('Starting game...\n\n');
tic;
result = game.run();
elapsed = toc;

%% ---- Display result -----------------------------------------------

fprintf('\n');
fprintf('══════════════════════════════════\n');
switch result.winner
    case 'seeker'
        fprintf('  🔵  SEEKER WINS!\n');
        fprintf('  Captured at t = %.1f s\n', result.time);
    case 'hider'
        fprintf('  🔴  HIDER WINS!\n');
        fprintf('  Survived the full %.0f s\n', result.time);
end
fprintf('  Wall-clock time : %.1f s\n', elapsed);
fprintf('══════════════════════════════════\n\n');

%% ---- Post-game plots ----------------------------------------------

if strcmp(lower(mode), 'default') || strcmp(lower(mode), 'challenge')
    fprintf('Generating post-game telemetry plots...\n');
    game.plotTelemetry();
end

end % function
