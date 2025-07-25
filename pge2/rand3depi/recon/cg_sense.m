%% CG-SENSE recon with BART
% Load data
kdata_path = "/mnt/storage/rexfung/20250725ball/recon/ksp6x.mat";
smaps_path = "/mnt/storage/rexfung/20250725ball/recon/smaps.mat";

load(kdata_path); % ksp_epi_zf
load(smaps_path); % smaps
run('params.m'); % params

[Nx, Ny, Nz, Nvcoils, Nframes] = size(ksp_epi_zf);

%% Recon with CG-SENSE
tic;
img = zeros(Nx,Ny,Nz,Nframes);
for frame = 1:Nframes
    fprintf('Reconstructing frame %d\n', round(frame));
    data = squeeze(ksp_epi_zf(:,:,:,:,frame));
    img(:,:,:,frame) = bart('pics -l1 -r0.001', data, smaps);
end
toc;

%% Viz
interactive4D(abs(flip(permute(img, [2 1 3 4]), 1)));
ksp = toppe.utils.ift3(img);
interactive4D(abs(flip(permute(log(abs(ksp) + eps), [2 1 3 4]), 1)));

return;

%% Viz
frame = 1;
figure('WindowState','maximized');
im('mid3',img(:,:,:,frame),'cbar')
title(sprintf('|image|, middle 3 planes of frame %d',frame));
ylabel('z, y'); xlabel('x, z')

%% Save
save('cg_recon_1e-3.mat','img','-v7.3');
