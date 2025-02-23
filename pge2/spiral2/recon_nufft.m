system('git clone git@github.com:JeffFessler/MIRT.git');
cd MIRT; setup; cd ..;

system('git clone --branch v1.9.1 git@github.com:toppeMRI/toppe.git');
addpath toppe

nleaf = 8;
nz = 1;
nt = 1;
nx = 128;   % image size
fov = 20;   % cm

% load first shot and get data size
archive = GERecon('Archive.Load', 'data.h5');
shot = GERecon('Archive.Next', archive);

[ndat nc] = size(shot.Data);

% load data
d = zeros(ndat, nc, nleaf, nz, nt);
k = 1; l = 1; t = 1;
d(:, :, l, k, t) = shot.Data;
for l = 2:nleaf
    shot = GERecon('Archive.Next', archive);
    d(:, :, l, k, t) = shot.Data;
end

% recon
% reshape to size [ndat nleaf nz nt ncoil] which is what toppe.utils.spiral.reconSoS wants
d = permute(d, [1 3 4 5 2]);
[imsos ims dcf] = toppe.utils.spiral.reconSoS(d, kx(1:ndat,:), ky(1:ndat,:), [fov fov], [nx nx], ...
                  'useParallel', false );

im(imsos);
