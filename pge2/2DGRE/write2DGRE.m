% write2DGRE.m
%
% 'Official' demo/learning sequence for Pulseq on GE 
% using the community-developed pge2 interpreter
% (https://github.com/GEHC-External/pulseq-ge-interpreter).
%
% Demonstrates the following:
%  - good coding practices for writing a Pulseq sequence in a GE-friendly way
%  - two different ADC events with different bandwidth and resolution
%  - empty blocks (zero duration) containing nothing but a (TRID) label
%  - two kinds of delay blocks: 
%    (1) those with constant duration throughout the scan. 
%        The pge2 interpreter implements these by simply 
%        moving the time marker within the segment.
%    (2) those with variable duration throughout the scan. 
%        The pge2 interpreter implements these by creating a WAIT pulse
%        whose duration varies dynamically as specified in the ceq.loop array.
%    It is good to be aware of the difference, since the presence of WAIT pulses
%    can potentially interfere with other nearby Pulseq events (RF and ADC).
%    Varying the duration of a pure delay block does not require a new TRID to be assigned.
%  - 'noise scans': segments consisting of nothing but an ADC event and delays 
%
% See also ../README.md

% System parameters for sequence design.
%
% Because block boundaries are invisible inside a segment, it is often best
% to set the dead time and ringdown time to zero. Otherwise, the +mr toolbox
% may silently insert delays that you did not intend.
%
% Gradients are reduced by a factor of 1/sqrt(3) to accommodate oblique
% orientations.
sys = mr.opts('maxGrad', 50/sqrt(3), 'gradUnit','mT/m', ...
              'maxSlew', 120/sqrt(3), 'slewUnit', 'T/m/s', ...
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
% The second echo has matrix size [Nx/2 Ny] and dwell time 40e-6
fov = 240e-3; 
Nx = 192; Ny = 192;                 % 
dwell = 20e-6;                      % ADC sample time (s)
sliceThickness = 5e-3;              % slice thickness (m)
alpha = 6;                          % flip angle (degrees)
delayTR = 5e-3;                     % for demonstrating variable delays
rfSpoilingInc = 117;                % RF spoiling increment

t_pre = 1e-3; % duration of x pre-phaser

% Create alpha-degree slice selection pulse and gradient
[rf, gz] = mr.makeSincPulse(alpha*pi/180, 'Duration', 3e-3, ...
    'SliceThickness', sliceThickness, 'apodization', 0.42, ...
    'use', 'excitation', ...
    'timeBwProduct', 4, 'system', sys);
gzReph = mr.makeTrapezoid('z', 'Area', -gz.area/2, 'Duration', t_pre, 'system', sys);
% TODO: replace with arbitrary RF waveform to demonstrate setting b1 amplitude correctly

% Define other gradients and ADC events.
% Define them once here, then scale amplitudes as needed in the scan loop.
deltak = 1/fov;
gx = mr.makeTrapezoid('x', 'FlatArea', Nx*deltak, 'FlatTime', Nx*dwell, 'system', sys);
adc = mr.makeAdc(Nx, 'Duration', gx.flatTime, 'Delay', gx.riseTime, 'system', sys);
adc2 = mr.makeAdc(Nx/4, 'Duration', gx.flatTime/2, 'Delay', gx.riseTime + gx.flatTime/4, 'system', sys);
gxPre = mr.makeTrapezoid('x', 'Area', -gx.area/2, 'Duration', t_pre, 'system',sys);
phaseAreas = ((0:Ny-1)-Ny/2)*deltak;
gyPre = mr.makeTrapezoid('y', 'Area', max(abs(phaseAreas)), ...
    'Duration', mr.calcDuration(gxPre), 'system', sys);
peScales = phaseAreas/gyPre.area;
gxSpoil = mr.makeTrapezoid('x', 'Area', 2*Nx*deltak, 'system', sys);
gzSpoil = mr.makeTrapezoid('z', 'Area', 4/sliceThickness, 'system', sys);

% Done creating events. These will become the 'base blocks' in the Ceq sequence representation.
% Next, define the scan loop, where we will NOT define any new events, since any events
% defined on the fly *might* differ from those defined above in sometimes subtle ways.
% The only exception is that it is safe to create pure delay blocks with mr.makeDelay(), 
% to vary the timing dynamically in the scan loop (see example below).

%% Scan loop
% iY <= -10        Dummy shots to reach steady state
% -10 < iY <= 0    ADC is turned on and used for receive gain calibration on GE
% iY > 0           Image acquisition

nDummyShots = 20;  % shots to reach steady state

rf_phase = 0;
rf_inc = 0;

TRisSet = false;
for iY = (-nDummyShots-pislquant+1):Ny
    isDummyTR = iY <= -pislquant;
    isReceiveGainCalibrationTR = iY < 1 & iY > -pislquant;

    % Set phase for RF spoiling
    rf.phaseOffset = rf_phase/180*pi;
    adc.phaseOffset = rf_phase/180*pi;
    adc2.phaseOffset = adc.phaseOffset;
    rf_inc = mod(rf_inc+rfSpoilingInc, 360.0);
    rf_phase = mod(rf_phase+rf_inc, 360.0);

    % Mark start of segment instance (block group) by adding TRID label.
    % The TRID can be any postivie integer, but must be unique to each segment.
    % Subsequent blocks in block group are NOT labelled (this is akin to 
    % the use of SEQLENGTH in EPIC to define segments/cores).
    % The TRID label can belong to a block with zero or more other events.
    %
    % Note the distinction here between 'segment' and 'segment instance':
    %
    %  'segment': 
    %       A virtual segment definition, represented in hardware 
    %       using normalized waveform amplitudes. So it is 'virtual'
    %       in the sense that it hasn't been assigned physical amplitudes/units,
    %       but it is very real since it is physically implemented in hardware!
    %
    %  'segment instance': 
    %       One executation/instance of a segment, with amplitudes
    %       in physical units (G/cm, etc). Each segment instance is associated
    %       with the TRID of the virtual segment it is an instance of. 
    %       The different segment instances contain the same sequence of blocks,
    %       except (generally) with different values of the following properties:
    %          - RF and gradient waveform amplitude
    %          - RF frequency offset
    %          - RF/ADC phase offsets
    %          - duration of pure delay blocks (see below)
    seq.addBlock(mr.makeLabel('SET', 'TRID', 1 + isDummyTR + 2*isReceiveGainCalibrationTR));
    seq.addBlock(rf, gz);   % excitation block
    % Alternative:
    % seq.addBlock(rf, gz, mr.makeLabel('SET', 'TRID', 1 + isDummyTR + 2*isReceiveGainCalibrationTR));

    % Slice-select refocus and readout prephasing block
    % Set phase-encode gradients to ~zero while iY < 1
    pesc = (iY>0) * peScales(max(iY,1));  % phase-encode gradient scaling
    pesc = pesc + (pesc == 0)*eps;        % non-zero scaling so that the trapezoid shape is preserved in the .seq file

    seq.addBlock(gxPre, mr.scaleGrad(gyPre, pesc), gzReph);

    % Empty blocks with a label is ok -- for now they are ignored by the GE interpreter.
    % These are just dummy examples to make the point.
    seq.addBlock(mr.makeLabel('SET','LIN', max(1,iY)) ) ;
    seq.addBlock(mr.makeLabel('SET','AVG', 0));

    % Non-flyback 2-echo readout
    if isDummyTR
        seq.addBlock(gx);
        seq.addBlock(mr.scaleGrad(gx, -1));
    else
        seq.addBlock(gx, adc);
        if isReceiveGainCalibrationTR
            seq.addBlock(mr.scaleGrad(gx, -1));  % don't acquire 2nd echo during receive gain calibration
        else
            seq.addBlock(mr.scaleGrad(gx, -1), adc2);
        end
    end

    % Spoil and PE rephasing, and TR delay
    % Shift z spoiler position using variable delays, for fun
    seq.addBlock(gxSpoil, mr.scaleGrad(gyPre, -pesc));
    dt = 20e-6*max(1,iY);
    seq.addBlock(mr.makeDelay(dt));
    seq.addBlock(gzSpoil);
    seq.addBlock(mr.makeDelay(delayTR-dt));

    if ~TRisSet
        TR = seq.duration;
        TRisSet = true;
    end

    % We're now at the end of a segment instance
end

%% Noise scans
nNoiseScans = 5;
for s = 1:nNoiseScans
    % Now we need to define a different sub-sequence,
    % so we need to label start of segment instance with a new unique TRID
    seq.addBlock(mr.makeLabel('SET', 'TRID', 48));  % any unique positive int
    seq.addBlock(mr.makeDelay(1)); 
    seq.addBlock(adc);
    seq.addBlock(mr.makeDelay(500e-6)); % make room for psd_grd_wait (gradient/ADC delay) and ADC ringdown
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
seq.setDefinition('Name', fn);
seq.write([fn '.seq'])       % Write to pulseq file

seq.plot('timeRange', [0 3]*TR);

% Done creating the .seq file! 
% Now you can use the various plot/checks available in the Pulseq toolbox.
% Then convert the .seq file to a .pge file and check the result -- see main.m.

%% Optional slow step, but useful for testing during development,
%% e.g., for the real TE, TR or for staying within slewrate limits  
%rep = seq.testReport;
%fprintf([rep{:}]);
