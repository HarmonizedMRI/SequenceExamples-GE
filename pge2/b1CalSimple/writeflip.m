% flipcal.m
% Simple flip angle mapping sequence.
% Just excite and record FID, for prescribed flip angles = 10:10:180

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

% Create a new sequence object
seq = mr.Sequence(sys);             

% Acquisition parameters 
% The second echo has matrix size [Nx/2 Ny] and dwell time 40e-6
sliceThickness = 10e-3;        % slice thickness (m)

% Create 180-degree slice selection pulse and gradient
[rf, gz] = mr.makeSincPulse(pi, 'Duration', 4e-3, ...
    'SliceThickness', sliceThickness, 'apodization', 0.42, ...
    'use', 'excitation', ...
    'timeBwProduct', 4, 'system', sys);
gzReph = mr.makeTrapezoid('z', 'Area', -gz.area/2, 'Duration', 1e-3, 'system', sys);

% Define ADC event
dwell = 20e-6;  % s
N = 128;
adc = mr.makeAdc(N, 'Duration', N*dwell, 'system', sys);

for flip = [90:-10:10 100:10:180]  % start with 90 to maximimize signal during receive gain calibration in Auto prescan

    % set flip angle
    rf.signal = rf.signal * flip/180 ;  

    seq.addBlock(mr.makeLabel('SET', 'TRID', 47));  % any unique int
    seq.addBlock(mr.makeDelay(5));   % for T1 recovery
    seq.addBlock(rf, gz);
    seq.addBlock(gzReph);
    seq.addBlock(adc);
    seq.addBlock(mr.makeDelay(400e-6)); % make room for psd_grd_wait (ADC delay) and ADC ringdown

    % reset flip angle
    rf.signal = rf.signal * 180/flip;
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
seq.setDefinition('Name', 'flip');
seq.write('flip.seq')       % Write to pulseq file

seq.plot();

%% Optional slow step, but useful for testing during development,
%% e.g., for the real TE, TR or for staying within slewrate limits  
%rep = seq.testReport;
%fprintf([rep{:}]);
