function v = oceanCurrent(pos, t, params)
%OCEANCURRENT  Returns ocean current velocity at a given 3-D position and time.
%
%   v = oceanCurrent(pos)
%   v = oceanCurrent(pos, t)
%   v = oceanCurrent(pos, t, params)
%
%   Models a realistic-but-simple spatially-varying, time-drifting current
%   field using sinusoidal basis functions.  Deeper water moves more slowly
%   (linear depth attenuation).  A slow temporal drift adds variety to long
%   games.
%
%   Inputs
%   ------
%   pos    : [1x3] or [Nx3] position(s) [x y z] in metres (ENU; z ≤ 0 = depth)
%   t      : scalar simulation time in seconds (default 0)
%   params : struct with optional fields:
%              .amplitude  – max current speed in m/s  (default 0.3)
%              .waveLen    – spatial wavelength in m    (default 200)
%              .driftRate  – temporal drift rate rad/s  (default 0.001)
%              .depthScale – depth at which current → 0 (default 100 m)
%
%   Output
%   ------
%   v : [Nx3] current velocity [vx vy vz] in m/s for each input position

    if nargin < 2 || isempty(t),      t = 0;           end
    if nargin < 3 || isempty(params), params = struct;  end

    A  = getfield_default(params, 'amplitude',  0.30);
    L  = getfield_default(params, 'waveLen',  200.0);
    dr = getfield_default(params, 'driftRate', 0.001);
    ds = getfield_default(params, 'depthScale', 100.0);

    k  = 2*pi / L;          % spatial wave number
    ph = dr * t;             % temporal phase shift

    x = pos(:,1);  y = pos(:,2);  z = pos(:,3);

    % Depth attenuation: current weakens with depth (z is negative down)
    % At surface (z=0) → factor=1; at z=-depthScale → factor=0
    depthFactor = max(0, 1 + z / ds);

    % Sinusoidal flow field
    vx = A .* sin(k*y + ph) .* depthFactor;
    vy = A .* cos(k*x + ph) .* depthFactor;
    vz = 0.1 * A .* sin(k*(x+y) + 2*ph) .* depthFactor;

    v = [vx, vy, vz];
end

% ---------------------------------------------------------------------------
function val = getfield_default(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end
