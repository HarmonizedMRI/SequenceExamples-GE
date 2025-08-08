% write2DGRE.m
% 2D RF-spoiled sequence. Acquires two echoes with different bandwidth and resolution.

% System/design parameters.
% Reduce gradients by 1/sqrt(3) to allow for oblique scans.
% Reduce slew a bit further to reduce PNS.
sys = mr.opts('maxGrad', 50/sqrt(3), 'gradUnit','mT/m', ...
              'maxSlew', 120/sqrt(3), 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 100e-6, ...
              'rfRingdownTime', 60e-6, ...
              'adcDeadTime', 40e-6, ...
              'adcRasterTime', 2e-6, ...
              'rfRasterTime', 2e-6, ...
              'gradRasterTime', 4e-6, ...
              'blockDurationRaster', 4e-6, ...
              'B0', 3.0);

ssi_time = 116e-6;    % (s) Gap after each segment instance (GE specific)

% Create a new sequence object
seq = mr.Sequence(sys);             

% Acquisition parameters 
% The second echo has matrix size [Nx/2 Ny] and dwell time 40e-6
fov = 240e-3; 
Nx = 192; Ny = 192;                 % 
dwell = 20e-6;                      % ADC sample time (s)
sliceThickness = 5e-3;              % slice thickness (m)
alpha = 6;                          % flip angle (degrees)
TR = 30e-3;                         % repetition time TR (s)
rfSpoilingInc = 117;                % RF spoiling increment

t_pre = 1e-3; % duration of x pre-phaser

% Create alpha-degree slice selection pulse and gradient
[rf, gz] = mr.makeSincPulse(alpha*pi/180, 'Duration', 3e-3, ...
    'SliceThickness', sliceThickness, 'apodization', 0.42, ...
    'use', 'excitation', ...
    'timeBwProduct', 4, 'system', sys);
gzReph = mr.makeTrapezoid('z', 'Area', -gz.area/2, 'Duration', t_pre, 'system', sys);

% Define other gradients and ADC events
deltak = 1/fov;
gx = mr.makeTrapezoid('x', 'FlatArea', Nx*deltak, 'FlatTime', Nx*dwell, 'system', sys);
adc = mr.makeAdc(Nx, 'Duration', gx.flatTime, 'Delay', gx.riseTime, 'system', sys);
gxPre = mr.makeTrapezoid('x', 'Area', -gx.area/2, 'Duration', t_pre, 'system',sys);
phaseAreas = ((0:Ny-1)-Ny/2)*deltak;
gyPre = mr.makeTrapezoid('y', 'Area', max(abs(phaseAreas)), ...
    'Duration', mr.calcDuration(gxPre), 'system', sys);
peScales = phaseAreas/gyPre.area;
gxSpoil = mr.makeTrapezoid('x', 'Area', 2*Nx*deltak, 'system', sys);
gzSpoil = mr.makeTrapezoid('z', 'Area', 4/sliceThickness, 'system', sys);

% trigger out (TTL) pulse
trig_out = mr.makeDigitalOutputPulse('ext1', 'delay', 200e-6, 'duration', 120e-6);

% Calculate delay to achieve desired TR
seqtmp = mr.Sequence(sys);
seqtmp.addBlock(rf, gz);
seqtmp.addBlock(gxPre, gyPre, gzReph, trig_out);
seqtmp.addBlock(gx);
seqtmp.addBlock(gxSpoil, gyPre, gzSpoil);
delayTR = ceil((TR - seqtmp.duration - ssi_time)/seq.gradRasterTime)*seq.gradRasterTime;
assert(delayTR > 100e-6, 'Requested TR is too short');

% Loop over phase encodes and define sequence blocks
% iY <= -10        Dummy shots to reach steady state
% -10 < iY <= 0    ADC is turned on and used for receive gain calibration on GE
% iY > 0           Image acquisition

nDummyShots = 20;  % shots to reach steady state
pislquant = 10;     % number of shots/ADC events used for receive gain calibration

rf_phase = 0;
rf_inc = 0;

for iY = (-nDummyShots-pislquant+1):Ny
    isDummyTR = iY <= -pislquant;
    isReceiveGainCalibrationTR = iY < 1 & iY > -pislquant;

    % RF spoiling
    rf.phaseOffset = rf_phase/180*pi;
    adc.phaseOffset = rf_phase/180*pi;
    rf_inc = mod(rf_inc+rfSpoilingInc, 360.0);
    rf_phase = mod(rf_phase+rf_inc, 360.0);
    
    % Excitation block
    % Mark start of segment (block group) by adding TRID label.
    % The TRID can be any integer, but must be unique to each segment.
    % Subsequent blocks in segment are NOT labelled.
    seq.addBlock(rf, gz, mr.makeLabel('SET', 'TRID', 1 + isDummyTR));

    % Slice-select refocus, readout prephasing, and trigger out pulse.
    % Set phase-encode gradients to zero while iY < 1.
    pesc = (iY>0) * peScales(max(iY,1));  % phase-encode gradient scaling
    pesc = pesc + (pesc == 0)*eps;        % non-zero scaling so that the trapezoid shape is preserved in the .seq file
    seq.addBlock(gxPre, mr.scaleGrad(gyPre, pesc), gzReph, trig_out);

    % Readout
    if isDummyTR
        seq.addBlock(gx);
    else
        seq.addBlock(gx, adc);
    end

    % Spoilers and PE rephasing
    seq.addBlock(gxSpoil, mr.scaleGrad(gyPre, -pesc), gzSpoil);

    % TR delay
    seq.addBlock(mr.makeDelay(delayTR));
end

%% Check sequence timing
[ok, error_report] = seq.checkTiming;
if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

%% Output for execution and plot
seq.setDefinition('FOV', [fov fov sliceThickness]);
seq.setDefinition('Name', 'gre2d');
seq.write('gre2d.seq')       % Write to pulseq file

seq.plot('timeRange', [0 3]*TR);

%% Optional slow step, but useful for testing during development,
%% e.g., for the real TE, TR or for staying within slewrate limits  
%rep = seq.testReport;
%fprintf([rep{:}]);
