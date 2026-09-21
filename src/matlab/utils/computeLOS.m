function visible = computeLOS(posA, posB, omap, nSamples)
%COMPUTELOS  Line-of-sight check between two 3-D points in an occupancy map.
%
%   visible = computeLOS(posA, posB, omap)
%   visible = computeLOS(posA, posB, omap, nSamples)
%
%   Samples 'nSamples' equally-spaced points along the segment from posA to
%   posB and queries the 3-D occupancy map.  Returns true only if every
%   sample is in free (unoccupied) space.
%
%   Inputs
%   ------
%   posA     : [1x3] start position [x y z] in metres (ENU)
%   posB     : [1x3] end   position [x y z] in metres (ENU)
%   omap     : occupancyMap3D object
%   nSamples : number of interpolation points (default 50)
%
%   Output
%   ------
%   visible  : logical scalar — true if LOS is clear, false if blocked

    if nargin < 4 || isempty(nSamples)
        nSamples = 50;
    end

    % Build interpolated points along the segment
    t      = linspace(0, 1, nSamples)';
    pts    = posA + t .* (posB - posA);   % [nSamples x 3]

    % checkOccupancy returns:  1 = occupied, 0 = free, -1 = unknown
    occ    = checkOccupancy(omap, pts);

    % LOS is clear only if no sample is occupied (allow unknown = -1)
    visible = ~any(occ == 1);
end
