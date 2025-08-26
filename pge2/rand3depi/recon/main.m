%{
Script for loading and preprocessing randomized 3D EPI data generated using:
https://github.com/rextlfung/rand3depi

Does the following:
1. Sets MRI hardware and experiment parameters (prior knowledge)
2. Read in ScanArchive files using Matteo Cencini's scripts (GE private)
3. Applies EPI odd/even phase correction using HarmonizedMRI utils
4. Allocates phase-corrected data to Cartesian grid based on known samp pattern
5. Outputs zero-filled k-space data for reconstruction

Optionally does the following:
1. Estimates sensitivity maps from GRE data via either BART or PISCO
%}

%% Dependencies
addpath('/home/rexfung/github/orchestra'); % Reading ScanArchives
addpath('/home/rexfung/github/hmriutils'); % EPI odd/even correction

%% Define experiment parameters

% Load in sequence parameters
run('./params.m');

% Total number of time frames
Nloops = 1; % TOPPE CV #8
Nframes = Nloops*NframesPerLoop;

% Coil compression params
Nvcoils = 10; % Chosen based on visual inspection of the "knee" in SVs

% Filenames
datdir = '/mnt/storage/rexfung/20250725ball/';
fn_cal = strcat(datdir, 'cal.h5');
fn_epi = strcat(datdir, 'randEPI_8x.h5');
fn_gre = strcat(datdir, 'gre.h5');
fn_samp_log = strcat(datdir, 'samp_logs/8x.mat');
fn_oe_locs = strcat(datdir, sprintf('samp_logs/kxoe%d.mat', Nx));
fn_smaps = strcat(datdir, 'recon/smaps.mat');

% Options
useOrchestra = true;
showEPIphaseDiff = true;
doSENSE = true; % Takes a while
SENSEmethod = 'bart';

%% Load GRE data
ksp_gre_raw = orc_read(fn_gre);
Ncoils = size(ksp_gre_raw,2);

% Check for reasonable magnitude
fprintf('Max real part of gre data: %d\n', max(real(ksp_gre_raw(:))))
fprintf('Max imag part of gre data: %d\n', max(imag(ksp_gre_raw(:))))

% Reshape and permute gre data
ksp_gre = ksp_gre_raw(:,:,1:Ny_gre*Nz_gre); % discard trailing data
ksp_gre = reshape(ksp_gre,Nx_gre,Ncoils,Ny_gre,Nz_gre);
ksp_gre = permute(ksp_gre,[1 3 4 2]); % [Nx Ny Nz Ncoils]

%% Coil-compress data via PCA
[ksp_gre, SVs, Vr] = ir_mri_coil_compress(ksp_gre, 'ncoil', Nvcoils);

%% Load EPI data
ksp_cal_raw = orc_read(fn_cal);
ksp_epi_raw = orc_read(fn_epi);
Nfid = size(ksp_epi_raw, 1);

% Print max real and imag parts to check for reasonable magnitude
fprintf('Max real part of cal data: %d\n', max(real(ksp_cal_raw(:))))
fprintf('Max imag part of cal data: %d\n', max(imag(ksp_cal_raw(:))))
fprintf('Max real part of epi data: %d\n', max(real(ksp_epi_raw(:))))
fprintf('Max imag part of epi data: %d\n', max(imag(ksp_epi_raw(:))))

%% Coil-compress using compression matrix Vr
ksp_cal_raw = reshape(permute(ksp_cal_raw, [1 3 2]), [], Ncoils) * Vr;
ksp_cal_raw = permute(reshape(ksp_cal_raw, Nfid, [], Nvcoils), [1 3 2]);
ksp_epi_raw = reshape(permute(ksp_epi_raw, [1 3 2]), [], Ncoils) * Vr;
ksp_epi_raw = permute(reshape(ksp_epi_raw, Nfid, [], Nvcoils), [1 3 2]);

%% Compute odd/even delays using calibration (blipless) data

% Reshape and permute calibration data (a single frame w/out blips)
ksp_cal = permute(ksp_cal_raw,[1 3 2]); % [Nfid Ny*Nshots Ncoils]
ksp_cal = ksp_cal(:,1:Ny/2, :, :); % Use the first half of echoes (higher SNR)

% Estimate k-space center offset due to gradient delay using max of each echo
% train
cal_data = squeeze(abs(mean(ksp_cal, 3)));
cal_data(:,2:2:end,:,:) = flip(cal_data(:,2:2:end,:,:),1);
[M, I] = max(cal_data,[],1);
delay = Nfid - 2*mean(I,'all');
delay = -2;
fprintf('Estimated offset from center of k-space (samples): %f\n', delay);

% retrieve sample locations from .mod file with adc info
% fn_adc = strcat(datdir, sprintf('adc%d.mod', Nfid));
% % [rf,gx,gy,gz,desc,paramsint16,pramsfloat,hdr] = toppe.readmod(fn_adc);
% [kxo, kxe] = toppe.utils.getk(sysGE, fn_adc, Nfid, delay);
load(fn_oe_locs, 'kxo', 'kxe');
kxo = kxo/100; kxe = kxe/100; % convert to cycles/cm
kxo = kxo + delay*(kxo(2) - kxo(1)); kxe = kxe + delay*(kxe(2) - kxe(1)); % apply estimated delays

% Extract even number of lines (in case ETL is odd)
ETL_even = size(ksp_cal,2) - mod(size(ksp_cal,2),2);
oephase_data = ksp_cal(:,1:ETL_even,:,:);

% EPI ghost correction phase offset values
oephase_data = hmriutils.epi.rampsampepi2cart(oephase_data, kxo, kxe, Nx, fov(1)*100, 'nufft');
oephase_data = ifftshift(ifft(fftshift(oephase_data),Nx,1));
[a, th] = hmriutils.epi.getoephase(squeeze(mean(oephase_data, 3)),showEPIphaseDiff);
fprintf('Constant phase offset (radians): %f\n', a(1));
fprintf('Linear term (radians/fov): %f\n', a(2));

%% Grid and apply odd/even correction to EPI data
% Reshape and permute loop data
ksp_epi = reshape(ksp_epi_raw,Nfid,Nvcoils,2*ceil(Ny/Ry/2)*round(Nz/caipi_z/Rz),Nframes);
ksp_epi = permute(ksp_epi,[1 3 2 4]); % [Nfid Ny/Ry*Nz/Rz Nvcoils Nframes]

% Grid along kx direction via NUFFT (takes a while)
ksp_loop_cart = zeros([Nx,size(ksp_epi,2:ndims(ksp_epi))]);
tic
    for frame = 1:Nframes
        fprintf('Gridding frame %d\n', round(frame));
        tmp = squeeze(ksp_epi(:,:,:,frame));
        tmp1 = hmriutils.epi.rampsampepi2cart(tmp, kxo, kxe, Nx, fov(1)*100, 'nufft');
        ksp_loop_cart(:,:,:,frame) = tmp1;
    end
toc

clear ksp_epi_raw ksp_epi;

% Phase correct along kx direction
ksp_loop_cart = hmriutils.epi.epiphasecorrect(ksp_loop_cart, a);

%% Create zero-filled k-space data
ksp_epi_zf = zeros(Nx,Ny,Nz,Nvcoils,Nframes);
load(fn_samp_log);

% Replicate samp_log to the number of experiment loops
samp_log = repmat(samp_log, [Nloops, 1, 1]);

% Read through log of sample locations and allocate data
for frame = 1:Nframes
    for samp_count = 1:2*ceil(Ny/Ry/2)*round(Nz/caipi_z/Rz)
        iy = samp_log(frame,samp_count,1);
        iz = samp_log(frame,samp_count,2);
        if ksp_epi_zf(:,iy,iz,:,frame) ~= 0
            fprintf('Warning: attempting to overwrite frame %d, ky %d, kz %d', frame, iy, iz);
            pause;
        end
        ksp_epi_zf(:,iy,iz,:,frame) = ksp_loop_cart(:,samp_count,:,frame);
    end
end

clear ksp_loop_cart;

%% NN-interpolation in time (view-sharing)
ksp_epi_nn = zeros(Nx,Ny,Nz,Nvcoils,Nframes);

%% Save for next step of recon
save(strcat(datdir,'recon/ksp.mat'),'ksp_epi_zf','-v7.3');

%% Rebuild sampling mask from samp_log
omegas = false(Ny, Nz, Nframes);
for f = 1:size(samp_log, 1)
    for k = 1:size(samp_log, 2)
        omegas(samp_log(f,k,1), samp_log(f,k,2), f) = true;
    end
end

%% IFFT to get multi-coil images
imgs_mc = zeros(Nx, Ny, Nz, Nvcoils, Nframes);
for frame = 1:Nframes
    imgs_mc(:,:,:,:,frame) = toppe.utils.ift3(ksp_epi_zf(:,:,:,:,frame));
end

%% Get sensitivity maps with either BART or PISCO
if doSENSE
    if exist(fn_smaps, 'file')
        load(fn_smaps);
    else
        fprintf('Estimating sensitivity maps from GRE data via %s...\n', SENSEmethod)
    
        % Compute sensitivity maps
        tic
            smaps_raw = makeSmaps(ksp_gre, SENSEmethod);
        toc
    end
    
    smaps = smaps_raw;

    % Mask
    % smaps(repmat(eigmaps>8*threshold,1,1,1,32)) = 0;

    % Crop in z to match EPI FoV
    z_start = round((fov_gre(3) - fov(3))/fov_gre(3)/2*Nz_gre + 1);
    z_end = round(Nz_gre - (fov_gre(3) - fov(3))/fov_gre(3)/2*Nz_gre);
    smaps = smaps(:,:,z_start:z_end,:);

    % Interpolate to match EPI data dimensions
    smaps_new = zeros(Nx,Ny,Nz,Nvcoils);
    for coil = 1:Nvcoils
        smaps_new(:,:,:,coil) = imresize3(smaps(:,:,:,coil),[Nx,Ny,Nz]);
    end
    smaps = smaps_new; clear smaps_new;

    % Align x-direction of smaps with EPI data (sometimes necessary)
    % smaps = flip(smaps,1);

    % Save for next time
    save(fn_smaps, 'smaps', 'smaps_raw', '-v7.3');
end

%% Coil combination
if doSENSE
    img_final = squeeze(sum(imgs_mc .* conj(smaps), 4));
else % root sum of squares combination
    img_final = squeeze(sqrt(sum(abs(imgs_mc).^2, 4)));
end

%% Compute k-space by IFT3
ksp_final = toppe.utils.ift3(img_final);

%% Viz
interactive4D(abs(flip(permute(img_final, [2 1 3 4]), 1)));
interactive4D(abs(flip(permute(log(abs(ksp_final) + eps), [2 1 3 4]), 1)));
return;
