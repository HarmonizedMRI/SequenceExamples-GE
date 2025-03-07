system('git clone git@github.com:JeffFessler/MIRT.git');
cd MIRT; setup; cd ..;

system('git clone --branch v1.9.1 git@github.com:toppeMRI/toppe.git');
addpath toppe

Nint = 1;
Nprj = 16;
nx = 128;   % image size
fov = 20;   % cm

% select specific rotations to recon
select_rots = 1:Nint*Nprj;

% load first shot and get data size
archive = GERecon('Archive.Load', 'data.h5');
shot = GERecon('Archive.Next', archive);

[ndat nc] = size(shot.Data);

% load data
d = zeros(ndat, nc, Nint*Nprj);
d(:, :, 1) = shot.Data;
for l = 2:Nint*Nprj
    shot = GERecon('Archive.Next', archive);
    d(:, :, l) = shot.Data;
end

% compress coils
d = permute(d,[1,3,2]); % n x nrot x nc
if nc > 1
    d = ir_mri_coil_compress(d,'ncoil',1);
end

% load the kspace trajectory
load ../kspace.mat
kspace = permute(kspace,[1,3,2]); % n x nrot x 3

% select out the rotations
d = d(:,select_rots);
kspace = kspace(:,select_rots,:);

% create nufft object
omega = 2*pi*fov/nx*reshape(kspace,[],3);
omega_msk = vecnorm(omega,2,2) < pi;
omega = omega(omega_msk,:);
nufft_args = {nx*ones(1,3), 6*ones(1,3), 2*nx*ones(1,3), nx/2*ones(1,3), 'table', 2^10, 'minmax:kb'};
A = Gnufft(true(nx*ones(1,3)),[omega,nufft_args]);

% calculate density compensation using the Pipe method
wi = ones(size(A,1),1);
for itr = 1:10 % 10 iterations
    wd = real( A.arg.st.interp_table(A.arg.st, ...
        A.arg.st.interp_table_adj(A.arg.st, wi) ) );
    wi = wi ./ wd;
end
W = Gdiag(wi / sum(abs(wi)));

%% solve for initial estimate (dc-NUFFT)
y = d(omega_msk);
x0 = (W*A)' * y;

im(reshape(x0,nx*ones(1,3)));