%% randsamp2d_caipi2
%
% Generate a 2D pseudo random sampling pattern with a fully sampled "ACS"
% region. Outside the ACS region, randomly sample with probability proportional
% to user-provided sampling weights e.g. Gaussian, uniform etc.
%
% Input arguments:
% N = [Ny Nz] = sampling grid dimensions. Positive vector of integers >= 1.
% R = [Ry Rz] = acceleration factors. Positive vector of integers >= 1.
% acs = [acs_y acs_z] = portions of k-space to be fully sampled as ACS
% region. Vector of numbers between 0 and 1.
% weights_y = sampling weights for all possible ky locations. Ny-long vector of
% non-negative numbers.
% weights_z = sampling weights for all possible kz locations. Nz-long vector of
% non-negative numbers.
% max_ky_step = the largest tolerable gap between subsequently sampled fast
% PE (ky) locations.
% caipi_z = Number of kz locations to be sampled per shot outside of the
% ACS zone. Constrains the minimum gap between adjacent sampled kz
% locations. Positive odd integer >= 1.
%
% Output arguments:
% omega = 2D sampling mask in the PE plane. Boolean matrix of size [Ny Nz].
% nacs_indices_samp_z = linear indices of z locations outside the ACS zone.
% Used to determine when to apply CAIPI shifts when constructing the pulse
% sequence. Vector of length [Nz_nacs].
%
% Design constraints:
% 1. Even number of samples about the center of k-space along the fast PE
% (ky) direction to ensure consistent TE
% 2. If the randomly selected ky sampling locations are separated by gaps
% exceeding max_ky_step, move the sampling location with the nearest
% neightbor(s) to the midpoint of the largest gap.
% 3. For kz, outside the ACS zone, randomly sample locations with minimal
% gap equivalent to caipi_z to prevent replicate sampling locations when
% applying caipi shifts.
%
% Last modified April 18th, 2025. Rex Fung

function [omega, acs_indices_z, nacs_indices_samp_z] = randsamp2dcaipi(N, R, acs, weights_y, weights_z, max_ky_step, caipi_z)
    % Unpack input arguments
    Ny = N(1); Nz = N(2);
    Ry = R(1); Rz = R(2);
    acs_y = acs(1); acs_z = acs(2);

    % Validate input arguments
    assert(Ny >= 1 && Nz >= 1, ...
           'Dimensions must be >= 1');
    assert(Ry >= 1 && Rz >= 1, ...
           'Acceleration factors must be >= 1');
    assert(0 <= acs_y && acs_y < 1 && ...
           0 <= acs_z && acs_z < 1, ...
           'ACS portions must be between [0, 1)');
    assert(acs_y <= 1/Ry && acs_z <= 1/Rz, ...
           'ACS portion cannot be larger than undersampling factor');
    assert(length(weights_y) == Ny && length(weights_z) == Nz, ...
           'sampling weights vectors must be equal to dimensions Ny Nz');
    assert(max_ky_step >= 1, ...
           'max_ky_step must be >= 1');
    assert(round(caipi_z) == caipi_z && caipi_z >= 1, ...
           'caipi_z must be an integer >= 1');

    % Compute range of caipi shifts
    caipi_z_range = (1:caipi_z) - round(caipi_z/2);

    % Compute number of ACS lines (even about ky = 0)
    Ny_acs = 2*round(acs_y*Ny/2);
    Nz_acs = round(acs_z*Nz);

    % Split indices into ACS and non-ACS regions
    acs_indices_y = round(Ny/2) + ((-floor(Ny_acs/2) + 1):ceil(Ny_acs/2));
    acs_indices_z = round(Nz/2) + ((-floor(Nz_acs/2) + 1):ceil(Nz_acs/2));
    % Split into halves for evenness
    if acs_y > 0
        nacs_indices_y = [1:(acs_indices_y(1) - 1);
                          (acs_indices_y(end) + 1):Ny];
    else
        nacs_indices_y = [1:round(Ny/2);
                          (round(Ny/2) + 1):Ny];
    end

    if acs_z > 0
        % Prevent caipi shifts from hitting ACS region or outside [1, Nz]
        nacs_indices_z = [(1 + -caipi_z_range(1)):(acs_indices_z(1) - 1 - caipi_z_range(end)), ...
                          (acs_indices_z(end) + 1 + -caipi_z_range(1)):(Nz - caipi_z_range(end))];
    else
        nacs_indices_z = [(1 + -caipi_z_range(1)):(round(Nz/2) - caipi_z_range(end)), ...
                          (round(Nz/2) + -caipi_z_range(1) + 1):(Nz - caipi_z_range(end))];
    end

    % Compute the number of non-ACS locations to sample based on R
    Ny_nacs = 2*round((Ny/Ry - Ny_acs)/2); % Ensure even number
    Nz_nacs = round(Nz/Rz/caipi_z - Nz_acs);

    % Extract sampling weights for non-ACS locations
    w_y = weights_y(nacs_indices_y);
    w_z = weights_z(nacs_indices_z);

    % Generate sampling locations along kz
    nacs_indices_samp_z = zeros(1, Nz_nacs);
    for iz = 1:Nz_nacs
        % Sample one location
        loc = datasample(nacs_indices_z, 1, 'Weights', w_z);
        nacs_indices_samp_z(iz) = loc;

        % For the next iteration, remove sampling locations that may lead
        % to replicate sampling after CAIPI-shifts
        caipi_zone = (-(caipi_z - 1):(caipi_z - 1)) + loc;
        caipi_zone = caipi_zone(1 <= caipi_zone | caipi_zone <= Nz);
        nacs_indices_z = nacs_indices_z(~ismember(nacs_indices_z, caipi_zone));
        w_z = w_z(~ismember(nacs_indices_z, caipi_zone));
    end
    nacs_indices_samp_z = sort(nacs_indices_samp_z);

    % Combine into one set of sampling indices
    indices_z = unique([acs_indices_z, nacs_indices_samp_z]);

    % Preallocate sampling grid
    omega = false(Ny, Nz);

    % Loop through kz locations and generate sampling locations along ky
    for z = indices_z
        nacs_indices_samp_y = zeros(2,Ny_nacs/2);
        for side = 1:2 % Sample the same amount on each half of k-space
            half_line = sort(datasample(nacs_indices_y(side,:), Ny_nacs/2,...
                                        'Replace', false,...
                                        'Weights', w_y(side,:)));

            % Limit spacing between consecutive ky lines
            % Add in edge of ACS region to prevent large gap
            if Ny_acs > 0
                if side == 1
                    half_line = [half_line, acs_indices_y(1)];
                else
                    half_line = [acs_indices_y(end), half_line];
                end
            end
            [gap,maxdex] = max(diff(half_line)); % find biggest gap
            while gap > max_ky_step
                % Find ky location with nearest neighbor(s)
                [~,mindex] = min(conv(diff(half_line),[1 1], 'valid'));

                % Move sampling location to the midpoint of largest gap
                half_line(mindex + 1) = half_line(maxdex) + round(gap/2);

                % Resort and update
                half_line = sort(half_line);
                [gap,maxdex] = max(diff(half_line)); 
            end
            % remove edge of ACS index from NACS indices
            if Ny_acs > 0
                if side == 1
                    half_line = half_line(1:end-1);
                else
                    half_line = half_line(2:end);
                end
            end

            nacs_indices_samp_y(side,:) = half_line;
        end
        indices_y = sort([acs_indices_y, reshape(nacs_indices_samp_y, 1, Ny_nacs)]);

        % Randomized CAIPI-shifting outside the ACS zone
        if ismember(z, nacs_indices_samp_z)
            for iy = 1:caipi_z:length(indices_y)
                shifts = randperm(caipi_z) - ceil(caipi_z/2);
                for iz = 1:min(caipi_z, length(indices_y) - iy + 1)
                    omega(indices_y(iy + iz - 1),z + shifts(iz)) = true;
                end
            end
        else
            omega(indices_y,z) = true;
        end
    end
end 