% writeSliceProfile.m
%
% 2D SPGR sequence for imaging slice profile

% Gradients are reduced by a factor of 1/sqrt(3) to accommodate oblique
% orientations.
sys = mr.opts('maxGrad', 30/sqrt(3), 'gradUnit','mT/m', ...
              'maxSlew', 100/sqrt(3), 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 100e-6, ...     % or 0
              'rfRingdownTime', 60e-6, ...  % or 0
              'adcDeadTime', 40e-6, ...     % or 0
              'adcRasterTime', 2e-6, ...    % GE dwell time must be a multiple of 2us
              'rfRasterTime', 4e-6, ...     % 2e-6, or any integer multiple thereof
              'gradRasterTime', 4e-6, ...   % 4e-6, or any integer multiple thereof
              'blockDurationRaster', 4e-6, ... % 4e-6, or any integer multiple thereof
              'B0', 3.0);

% Create a new sequence object
seq = mr.Sequence(sys);             

% Acquisition parameters 
TR = 0.05;                             % sec
fov = 220e-3; 
Nx = 2*220; Ny = 32;                % 
dwell = 20e-6;                      % ADC sample time (s)
sliceThickness = fov/4;             % slice thickness (m)
rfSpoilingInc = 117;                % RF spoiling increment

t_pre = 2e-3; % duration of x pre-phaser

% RF pulse
sys2 = mr.opts('maxGrad', 40, 'gradUnit','mT/m', ...
              'maxSlew', 130, 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 100e-6, ...     % or 0
              'rfRingdownTime', 60e-6, ...  % or 0
              'adcDeadTime', 40e-6, ...     % or 0
              'adcRasterTime', 2e-6, ...    % GE dwell time must be a multiple of 2us
              'rfRasterTime', 4e-6, ...     % 2e-6, or any integer multiple thereof
              'gradRasterTime', 4e-6, ...   % 4e-6, or any integer multiple thereof
              'blockDurationRaster', 4e-6, ... % 4e-6, or any integer multiple thereof
              'B0', 3.0);

 [rf, gz] = mr.makeSincPulse(90*pi/180, 'Duration', 4e-3, ...
                            'SliceThickness', sliceThickness, 'apodization', 0.42, ...
                            'use', 'excitation', ...
                            'timeBwProduct', 8, 'system', sys2);
gzReph = mr.makeTrapezoid('z', sys, 'Area', -gz.area/2, 'system', sys2);
gz.channel = 'x';
gzReph.channel = 'x';

% Simulate slice profile
pulseqBlochSim({{rf,gz}, {[],gzReph}}, sys, [fov fov fov]);

% Define other gradients and ADC events.
% Define them once here, then scale amplitudes as needed in the scan loop.
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

% Scan loop
rf_phase = 0;
rf_inc = 0;

for iY = 1:Ny
    % Set phase for RF spoiling
    rf.phaseOffset = rf_phase/180*pi;
    adc.phaseOffset = rf_phase/180*pi;
    adc2.phaseOffset = adc.phaseOffset;
    rf_inc = mod(rf_inc+rfSpoilingInc, 360.0);
    rf_phase = mod(rf_phase+rf_inc, 360.0);

    seq.addBlock(mr.makeLabel('SET', 'TRID', 1));

    % excite
    seq.addBlock(rf, gz);   
    seq.addBlock(gzReph);

    % Slice-select refocus and readout prephasing block
    % Set phase-encode gradients to ~zero while iY < 1
    pesc = (iY>0) * peScales(max(iY,1));  % phase-encode gradient scaling
    pesc = pesc + (pesc == 0)*eps;        % non-zero scaling so that the trapezoid shape is preserved in the .seq file
    seq.addBlock(gxPre, mr.scaleGrad(gyPre, pesc));

    % read
    seq.addBlock(gx, adc);

    % Spoil and PE rephasing
    seq.addBlock(gxSpoil, mr.scaleGrad(gyPre, -pesc), gzSpoil);

    % add delay to achieve desired TR
    if iY == 1
        delayTR = max(0, TR - seq.duration);
    end

    seq.addBlock(mr.makeDelay(delayTR));
end

% Check sequence timing
[ok, error_report] = seq.checkTiming;
if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

% Output for execution and plot
seq.setDefinition('FOV', [fov fov sliceThickness]);
seq.setDefinition('Name', fn);
seq.write([fn '.seq'])       % Write to pulseq file

seq.plot('timeRange', [0 3]*TR);

% Optional slow step, but useful for testing during development,
% e.g., for the real TE, TR or for staying within slewrate limits  
%rep = seq.testReport;
%fprintf([rep{:}]);
