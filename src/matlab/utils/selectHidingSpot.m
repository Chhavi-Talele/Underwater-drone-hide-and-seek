function [bestPt, scores] = selectHidingSpot(candidates, seekerPose, omap, weights)
%SELECTHIDINGSPOT  Score candidate waypoints for the Hider AUV.
%
%   [bestPt, scores] = selectHidingSpot(candidates, seekerPose, omap)
%   [bestPt, scores] = selectHidingSpot(candidates, seekerPose, omap, weights)
%
%   Evaluates each candidate position on three criteria:
%     1. Distance from Seeker   — further is better
%     2. Terrain occlusion      — not in LOS of Seeker is better
%     3. Depth preference       — mid-depth (−20 to −60 m) preferred
%
%   Inputs
%   ------
%   candidates  : [Nx3] array of candidate [x y z] positions in metres (ENU)
%   seekerPose  : [1x4] Seeker's current pose [x y z heading]
%   omap        : occupancyMap3D object (used for LOS + free-space check)
%   weights     : [1x3] weights for [distance, occlusion, depth] scoring
%                 (default [0.5, 0.35, 0.15])
%
%   Outputs
%   -------
%   bestPt : [1x3] highest-scoring candidate position
%   scores : [Nx1] composite score for each candidate (higher = better hiding)

    if nargin < 4 || isempty(weights)
        weights = [0.50, 0.35, 0.15];
    end

    N = size(candidates, 1);
    if N == 0
        error('selectHidingSpot:noCandiates', 'No candidate points provided.');
    end

    seekerXYZ = seekerPose(1:3);

    % ------------------------------------------------------------------
    % 1. Distance score  (normalised to [0,1])
    % ------------------------------------------------------------------
    dists = vecnorm(candidates - seekerXYZ, 2, 2);   % [Nx1]
    distScore = dists / (max(dists) + 1e-6);

    % ------------------------------------------------------------------
    % 2. Occlusion score  (1 = hidden, 0 = visible)
    % ------------------------------------------------------------------
    occScore = zeros(N, 1);
    for i = 1:N
        % Only score free cells
        if checkOccupancy(omap, candidates(i,:)) == 0
            visible = computeLOS(candidates(i,:), seekerXYZ, omap);
            occScore(i) = ~visible;   % hidden = 1
        else
            distScore(i) = 0;  % occupied cell: zero all scores
            occScore(i)  = 0;
        end
    end

    % ------------------------------------------------------------------
    % 3. Depth preference score  (prefer mid-depth: -20 to -60 m)
    % ------------------------------------------------------------------
    z = candidates(:, 3);
    % Bell curve centred at -40 m with std dev 20 m
    depthScore = exp(-0.5 * ((z + 40) / 20).^2);
    depthScore = depthScore / (max(depthScore) + 1e-6);

    % ------------------------------------------------------------------
    % Composite score
    % ------------------------------------------------------------------
    scores = weights(1)*distScore + weights(2)*occScore + weights(3)*depthScore;

    [~, idx] = max(scores);
    bestPt   = candidates(idx, :);
end
