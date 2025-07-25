%% Define MRI system hardware limits
% Dependencies:
% https://github.com/pulseq/pulseq.git
% https://github.com/toppeMRI/toppe.git

% RF/gradient delay. Conservative value that should work across all GE scanners.
psd_rf_wait = 200e-6; % s

% Create Siemens/pulseq MRI system
% Here we extend rfRingdownTime by psd_rf_wait to ensure that the subsequent 
% wait pulse (delay block) doesn't overlap with the 'true' RF ringdown time
% (54 us).
sys = mr.opts('maxGrad', 40, 'gradUnit','mT/m', ...
              'maxSlew', 120, 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 100e-6, ...
              'rfRingdownTime', 60e-6 + psd_rf_wait, ...
              'adcDeadTime', 20e-6, ...
              'adcRasterTime', 2e-6, ...
              'rfRasterTime', 2e-6, ...
              'gradRasterTime', 4e-6, ...
              'blockDurationRaster', 4e-6, ...
              'B0', 3.0);

% Create GE MRI system (for tv6)
sysGE = toppe.systemspecs('maxGrad', sys.maxGrad/sys.gamma*100, ...   % G/cm
    'maxSlew', sys.maxSlew/sys.gamma/10, ...           % G/cm/ms
    'maxRF', 0.25);

% Common raster time of Siemens: 10e-6, GE: 4e-6;
CRT = 20e-6; % s

% ADC sample time
dwell = 4e-6; % s

%% Scan parameters for echo-planar imaging (EPI) sequence

% Spatial parameters
res = [2.4 2.4 2.4]*1e-3; % resolution (m)
N = [90 90 60]; % acquisition tensor size
fov = N .* res; % field of view (m)
Nx = N(1); Ny = N(2); Nz = N(3);

% Random undersampling parameters. Total acceleration = Ry*Rz*caipi_z
Ry = 1; Rz = 1; % Acceleration/undersampling factors in each direction
caipi_z = 1; % Number of kz locations to acquire per shot. Must be positive integer
R = [Ry Rz];
acs = [0 0]; % Central portion of ky-kz space to fully sample
max_ky_step = round(Ny/16); % Maximum gap in fast PE direction
max_kz_step = (caipi_z - 1); % Maximum possible jump in slow PE direction

% Temporal parameters
Nshots = ceil(length(1:caipi_z:(Nz - caipi_z + 1))/Rz); % Number of shots per volume

% Decay parameters
TE = 30.5e-3;                         % echo time (s)
volumeTR = 4.2;                     % temporal frame rate (s)
TR = volumeTR / Nshots;             % repetition time (s)
T1 = 1500e-3;                       % T1 (s)

% Number of frames to write in sequence, which is then looped on the scanner
minNframesPerLoop = lcm(40,Nshots)/Nshots; % number of temporal frames to complete one RF spoil cycle
duration = 60; % experiment duration (s)
NframesPerLoop = floor(duration/volumeTR/minNframesPerLoop)*minNframesPerLoop;

% Dummy parameters
Ndummyframes = round(3*T1/TR); % dummy frames to reach steady state for calibration

% Exciting stuff
alpha = 180/pi * acos(exp(-TR/T1)); % Ernst angle (degrees)
rfDur = 2e-3;                       % RF pulse duration (s)
rfTB  = 6;                          % RF pulse time-bandwidth product
rf_phase_0 = 117;                   % RF spoiling initial phase (degrees)
NcyclesSpoil = 2;                   % number of Gx and Gz spoiler cycles

% Fat saturation
fatChemShift = 3.5*1e-6;                        % 3.5 ppm
fatOffresFreq = sys.gamma*sys.B0*fatChemShift;  % Hz
fatsat.flip    = 90;      % degrees
fatsat.slThick = 1e5;     % dummy value (determines slice-select gradient, but we won't use it; just needs to be large to reduce dead time before+after rf pulse)
fatsat.tbw     = 3;       % time-bandwidth product
fatsat.dur     = 4;     % pulse duration (ms)

%% Scan parameters for gradient echo (GRE) sequence. Used for sensitivity maps

% Spatial parameters
res_gre = [2, 2, 2]*1e-3; % resolution (m)
fov_gre = [21.6, 21.6, 21.6]*1e-2; % field of view (m)
N_gre = round(fov_gre./res_gre); % acquisiton tensor size
Nx_gre = N_gre(1); Ny_gre = N_gre(2); Nz_gre = N_gre(3);

% Temporal parameters
NdummyZloops = 10; % number of dummy excitations to reach steady state

% Other acquisition params
TE_gre = 1/fatOffresFreq + 2e-4; % fat and water in phase for both echoes
TR_gre = 6e-3; % constant TR
T1_gre = 1500e-3; % approximate T1
alpha_gre = 180/pi*acos(exp(-TR_gre/T1_gre)); % flip angle (degrees)

% Sequence parameters
rfDur_gre = 0.4e-3;  % RF duration
nCyclesSpoil = 2; % number of spoiler cycles
Tpre = 1.0e-3; % prephasing trapezoid duration