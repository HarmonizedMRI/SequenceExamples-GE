%% CG-SENSE recon with BART
% Load data
kdata_path = "/mnt/storage/rexfung/20241121ball/kdata2x3.mat";
smaps_path = "/mnt/storage/rexfung/20241121ball/smaps.mat";

kdata = matfile(kdata_path); % ksp_zf
load(smaps_path); % smaps

Nx = 120; Ny = 120; Nz = 40; Ncoils = 32; Nframes = 20;

%% Recon with CG-SENSE
tic;
img = zeros(Nx,Ny,Nz,Nframes);
parfor frame = 1:Nframes
    fprintf('Reconstructing frame %d\n', round(frame));
    data = squeeze(kdata.ksp_zf(:,:,:,:,frame));
    img(:,:,:,frame) = bart('pics -l1 -r0.001', data, smaps);
end
toc;

%% Viz
frame = 1;
figure('WindowState','maximized');
im('mid3',img(:,:,:,frame),'cbar')
title(sprintf('|image|, middle 3 planes of frame %d',frame));
ylabel('z, y'); xlabel('x, z')

%% Save
save('icg_1e-3.mat','img','-v7.3');
