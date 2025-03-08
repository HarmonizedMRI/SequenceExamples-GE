% 3D SPI sequence by David Frey (djfrey@umich.edu)

%% Set parameters
te_delay = 1e-3; % extra delay for TE (s)
tr_delay = 200e-3; % extra delay for TR (s)
fov = 20; % fov (cm)
dt = 4e-6; % raster time (s)
N = 128; % 3D matrix size
nscl = 1; % number of scales (scaling of gradient to "zoom" out of image)
nint = 1; % number of interleaves (2D in-plane rotations)
nprj = 16; % number of projections (3D thru-plane rotations)
gmax = 4; % max gradient amplitude (G/cm)
smax = 12000; % max slew rate (G/cm/s)
plotseq = true; % option to plot the sequence
safile = 'data.h5'; % scanarchive data file name
pislquant = 1; % number of prescan acquisitions to determine gains

%% Set paths
% Pulseq
system('git clone --branch v1.5.0 git@github.com:pulseq/pulseq.git');
addpath pulseq/matlab
% PulCeq
system('git clone --branch tv7 git@github.com:fmrifrey/PulCeq.git');
addpath PulCeq/matlab
% TOPPE
system('git clone --branch develop git@github.com:toppeMRI/toppe.git');
addpath toppe
% MIRT
system('git clone git@github.com:JeffFessler/MIRT.git');
run MIRT/setup.m

%% Actions
createSequenceFile = 1;
reconstruct = 0;

if createSequenceFile

    % create the 3D SPI .seq file with given parameters
    write_seq( ...
        'te_delay', te_delay, ...
        'tr_delay', tr_delay, ...
        'fov', fov, ...
        'dt', dt, ...
        'N', N, ...
        'nscl', nscl, ...
        'nint', nint, ...
        'nprj', nprj, ...
        'gmax', gmax, ...
        'smax', smax, ...
        'plotseq', plotseq ...
        );

    % convert to .pge file
    ceq = seq2ceq('spi3d.seq');
    writeceq(ceq, 'spi3d.pge', 'pislquant', pislquant);

end

if reconstruct

    % set up the system matrices
    [A,W,b] = setup_recon('safile',safile);

    % reconstruct with density-weighted NUFFT
    img = reshape((W * A)' * b, [N*ones(1,3),nscl]);

    % display image
    if nscl == 1 % one scale
        figure
        im(abs(img))
        title('dc-NUFFT reconstruction');
    else % multiple scales
        for i = 1:nscl
            figure
            im(abs(img(:,:,:,i)))
            title(sprintf('dc-NUFFT reconstruction, scale #%d',i));
        end
    end

end

