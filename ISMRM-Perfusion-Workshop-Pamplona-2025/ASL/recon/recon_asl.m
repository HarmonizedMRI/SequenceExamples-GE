addpath ~/Programs/orchestra-sdk-2.1-1.matlab/

load ../sequence/readout
nz = readout.nz;  
nleaf = readout.nleaf;   % number of spiral leafs

% load first shot and get data size
clear archive
archive = GERecon('Archive.Load', 'data.h5');
shot = GERecon('Archive.Next', archive);

[ndat nc] = size(shot.Data);

%rhnframes = archive.DownloadData.rdb_hdr_rec.rdb_hdr_nframes;

nt = 2*30; %2*74; %rhnframes;   % number of tag-control pairs is nt/2

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
textprogressbar('Loading data: ');
for t = 2:nt
    textprogressbar(t/nt*100);
    for k = 1:nz
        for l = 1:nleaf
            shot = GERecon('Archive.Next', archive);
            d(:, :, l, kz(k), t) = shot.Data;
        end
    end
end
textprogressbar('');

% get kx and ky sampling trajectory
kx = readout.kx(1:ndat,:);
ky = -readout.ky(1:ndat,:);  % rotations are negated, need to look into this TODO

% recon
d = permute(d, [1 3 4 5 2]);   % reshape to size [ndat nleaf nz nt ncoil]
nx = readout.nx;
[imsos ims dcf] = toppe.utils.spiral.reconSoS(d, kx, ky, 100*readout.fov(1:2), [nx nx], ...
                  'useParallel', false );
