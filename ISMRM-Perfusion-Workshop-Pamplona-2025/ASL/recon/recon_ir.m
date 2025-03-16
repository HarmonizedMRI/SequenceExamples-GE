addpath ~/Programs/orchestra-sdk-2.1-1.matlab/

load ../sequence/readout
nz = readout.nz;  
nleaf = readout.nleaf;   % number of spiral leafs
load ../sequence/TI.mat
nt = length(TI);     % number of frames

% load first shot and get data size
archive = GERecon('Archive.Load', 'data.h5');
shot = GERecon('Archive.Next', archive);

[ndat nc] = size(shot.Data);

d = zeros(ndat, nc, nleaf, nz, nt);

load ../sequence/kz   %
kz = kz + nz/2 + 1;   % range is now [1 nz]

% load first frame
k = 1; l = 1; t = 1;
d(:, :, l, kz(k), t) = shot.Data;
for l = 2:nleaf
    shot = GERecon('Archive.Next', archive);
    d(:, :, l, kz(k), t) = shot.Data;
end
for k = 2:nz
    for l = 1:nleaf
        shot = GERecon('Archive.Next', archive);
        d(:, :, l, kz(k), t) = shot.Data;
    end
end

% load other frames
for t = 2:nt
    for k = 1:nz
        for l = 1:nleaf
            shot = GERecon('Archive.Next', archive);
            d(:, :, l, kz(k), t) = shot.Data;
        end
    end
end

% get kx and ky sampling trajectory
kx = readout.kx(1:ndat,:);
ky = -readout.ky(1:ndat,:);  % rotations are negated, need to look into this TODO

% recon
% reshape to size [ndat nleaf nz nt ncoil] which is what toppe.utils.spiral.reconSoS wants
d = permute(d, [1 3 4 5 2]);
[imsos ims dcf] = toppe.utils.spiral.reconSoS(d, kx, ky, [24 24], [64 64], ...
                  'useParallel', false );
