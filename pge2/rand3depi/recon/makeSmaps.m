%% makeSmaps.m
%
% Wrapper function to estimate sensitivity maps using either:
% 1. Rodrigo's PISCO technique or
% 2. BART
%
% Input arguments:
% ksp = 3D k-space data. Typically acquired using GRE. 3D tensor.
% method = 'pisco' or 'bart'. String.
% 
% Output arguments:
% 
%
% Last modified Jan 30th, 2025. Rex Fung

function smaps = makeSmaps(ksp, method)
    % Read in dimensions
    [Nx, Ny, Nz, Ncoils] = size(ksp);

    if strcmp(method, 'bart')
        [calib, emaps] = bart('ecalib -r 20', ksp);
        smaps = squeeze(calib(:,:,:,:,1));
    elseif strcmp(method, 'pisco')
        % PISCO options
        tau = 3;
        threshold = 0.05;
        kernel_shape = 1;
        FFT_nullspace_C_calculation = 1;
        PowerIteration_G_nullspace_vectors = 1;
        M = 20;
        PowerIteration_flag_convergence = 1;
        PowerIteration_flag_auto = 1;
        FFT_interpolation = 1;
        interp_zp = 24;
        gauss_win_param = 100;
        verbose = 0;

        % Only use central (high SNR) region of k-space to estimate smaps
        cal_length = 32; % Length of each dimension of the calibration data
        center_x = ceil(Nx/2) + ~rem(Nx,2);
        center_y = ceil(Ny/2) + ~rem(Ny,2);
        cal_index_x = center_x + (-floor(cal_length/2):floor(cal_length/2) - ~rem(cal_length/2,2));
        cal_index_y = center_y + (-floor(cal_length/2):floor(cal_length/2) - ~rem(cal_length/2,2));
    
        % Compute smaps slice-by-slice
        tmp = ifftshift(ifft(fftshift(ksp),Nz,3));
        smaps = zeros(Nx, Ny, Nz, Ncoils);
        % eigmaps = zeros(Nx, Ny, Nz);

        parfor z = 1:Nz
            fprintf('estimate z = %d\n', round(z));
            [smaps_tmp, eigvals] = PISCO_senseMaps_estimation(...
                squeeze(tmp(cal_index_x,cal_index_y,z,:)),...
                [Nx, Ny],...
                tau,...
                threshold,...
                kernel_shape,...
                FFT_nullspace_C_calculation,...
                PowerIteration_G_nullspace_vectors,...
                M,...
                PowerIteration_flag_convergence,...
                PowerIteration_flag_auto,...
                FFT_interpolation,...
                interp_zp,...
                gauss_win_param,...
                verbose...
            );
    
            % Normalize
            smaps_tmp = smaps_tmp./sqrt(sum(abs(smaps_tmp).^2, 3));
    
            % Allocate
            smaps(:,:,z,:) = smaps_tmp;
            % eigmaps(:,:,z,:) = eigvals;
        end
    end
end