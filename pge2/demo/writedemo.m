% writedemo.m
%
% "Official" demo/learning sequence for Pulseq on GE, using the
% community-developed pge2 interpreter
% (https://github.com/GEHC-External/pulseq-ge-interpreter).
%
% This script demonstrates:
%   - Recommended coding practices for writing Pulseq sequences in a
%     GE-compatible way.
%   - Use of two ADC events with different bandwidths and resolutions.
%   - Empty (zero-duration) blocks that contain only a TRID label.
%   - Two types of delay blocks:
%       (1) Constant-duration delays:
%           Implemented by pge2 by shifting the internal time marker within
%           the segment.
%       (2) Variable-duration delays:
%           Implemented by pge2 via a WAIT pulse, whose duration is set
%           dynamically from the values in the ceq.loop array.
%           Important note: WAIT pulses can interact with nearby Pulseq
%           events (e.g., RF and ADC), so it is useful to recognize when
%           they are being created.
%           Changing the duration of a pure delay block does *not* require
%           assigning a new TRID.
%   - "Noise scans": segments containing only an ADC event and delay blocks.

% System/design parameters.
% Because block boundaries “disappear” inside a segment, it is often useful
% to set dead time and ringdown time to zero. This prevents the +mr toolbox
% from silently inserting delays you may not intend.
%
% The parameter values below do not need to match the actual hardware limits.
% Gradient amplitudes are reduced by 1/sqrt(3) to accommodate oblique scans.
%
% Note: pge2.check() performs PNS verification automatically.
sys = mr.opts('maxGrad', 50/sqrt(3), 'gradUnit','mT/m', ...
              'maxSlew', 120/sqrt(3), 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 100e-6, ...     % or 0
              'rfRingdownTime', 60e-6, ...  % or 0
              'adcDeadTime', 40e-6, ...     % or 0
              'adcRasterTime', 2e-6, ...    % GE dwell time must be a multiple of 2us
              'rfRasterTime', 4e-6, ...        % 2e-6, or any integer multiple thereof
              'gradRasterTime', 4e-6, ...      % 4e-6, or any integer multiple thereof
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
[rf, gz] = mr.makeSincPulse(alpha*pi/180, 'Duration', 1.0e-3, ...
    'SliceThickness', sliceThickness, 'apodization', 0.42, ...
    'use', 'excitation', ...
    'timeBwProduct', 4, 'system', sys);
gzReph = mr.makeTrapezoid('z', 'Area', -gz.area/2, 'Duration', t_pre, 'system', sys);

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

% Done creating events for the SPGR/FLASH portion of the sequence. 
% These will serve as the “base blocks” in the Ceq sequence representation.
%
% Next, define the scan loop. We intentionally avoid creating new events
% inside the loop, because events generated on the fly can differ—sometimes
% subtly—from those defined above.
%
% The only exception is pure delay blocks created with mr.makeDelay(), which
% are safe to generate dynamically to adjust timing during the scan loop
% (see example below).


% 2D spin-warp (Cartesian) SPGR/FLASH sequence
% iY <= -pislquant        Dummy shots to reach steady state
% -pislquant < iY <= 0    ADC is turned on and used for receive gain calibration on GE
% iY > 0           Image acquisition

nDummyShots = 20;  % shots to reach steady state (before turning on ADC)

rf_phase = 0;
rf_inc = 0;

for iY = (-nDummyShots-pislquant+1):Ny
    isDummyTR = iY <= -pislquant;
    isReceiveGainCalibrationTR = iY < 1 & iY > -pislquant;

    % Set phase for RF spoiling
    rf.phaseOffset = rf_phase/180*pi;
    adc.phaseOffset = rf_phase/180*pi;
    adc2.phaseOffset = adc.phaseOffset;
    rf_inc = mod(rf_inc+rfSpoilingInc, 360.0);
    rf_phase = mod(rf_phase+rf_inc, 360.0);

    % Mark the start of a segment instance (block group) by adding a TRID label.
    % TRID may be any positive integer, but it must be unique for each segment.
    % Only the first block in the block group is labeled; subsequent blocks are
    % unlabeled (similar to how SEQLENGTH defines segments/cores in EPIC).
    % A TRID label can be attached to a block that contains zero or more events.
    %
    % Important distinction between 'segment' and 'segment instance':
    %
    %   segment:
    %       A virtual segment definition represented in hardware using normalized
    %       waveform amplitudes. It is “virtual” because the amplitudes have not yet
    %       been assigned physical units, yet it is ultimately realized on hardware.
    %       The TRID label identifies this virtual segment.
    %
    %   segment instance:
    %       One execution of a virtual segment, with amplitudes expressed in
    %       physical units (e.g., G/cm). Each instance is tied to the TRID of the
    %       virtual segment it represents. All instances have the same sequence of
    %       blocks, but typically differ in:
    %           - RF and gradient waveform amplitudes
    %           - RF frequency offset
    %           - RF/ADC phase offsets
    %           - Durations of pure delay blocks (see below)
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
    seq.addBlock(mr.makeDelay(dt));  % variable delay, implemented as a WAIT pulse by the interpreter
    seq.addBlock(gzSpoil);
    seq.addBlock(mr.makeDelay(delayTR-dt));  % another variable delay block

    % We're now at the end of a segment instance
end

% Add on a few rotated spiral gradients, 
% to illustrate arbitrary gradients and rotation events.
% NB! If any of the blocks inside a segment contains a rotation event,
% that rotation will be applied to the entire segment!
T = 8e-3;              % duration of spiral
t = sys.gradRasterTime*[1:round(T/sys.gradRasterTime)] - sys.gradRasterTime/2;   % sample at center of raster intervals
g = 20e-3 * t/T .* exp(1i*4*2*pi/T*t);   % T/m
g = [g linspace(g(end), 0, 100)];        % ramp to zero

sp.gx = mr.makeArbitraryGrad('x', real(g)*sys.gamma, ...  % input in Hz/m
    'Delay', 0, ...
    'system', sys, ...
    'first', 0, 'last', 0);   % values at raster edges
sp.gy = mr.makeArbitraryGrad('y', imag(g)*sys.gamma, ...  
    'Delay', sp.gx.delay, ...
    'system', sys, ...
    'first', 0, 'last', 0);  

Nint = 3;   % number of rotations
for ii = 1:Nint
    % Define new (virtual) segment by defining a new TRID
    seq.addBlock(mr.makeLabel('SET', 'TRID', 47));
    th = (ii-1)*2*pi/Nint;    % rotation angle
    th = angle(exp(1i*th));   % wrap to [-pi pi] range
    rot = mr.makeRotation([0 0 1], th);  % rotation event. axis-angle notation
    seq.addBlock(sp.gx, sp.gy, rot);

    % NB: On a GE scanner, the rotation applies to the entire segment. This means
    % any gradients added within the same segment, e.g.,
    %     seq.addBlock(mr.scaleGrad(gx, 1));
    % will also be rotated along with the spiral, which is usually not desired.
    %
    % In this example, adding gz is safe because the rotation is about the z-axis,
    % so the z-gradient is unaffected and can reside in the same segment as the spiral.
    seq.addBlock(gz);
end

% Insert noise scan.
% For this we need to define a different sub-sequence (segment),
% so we again need to label start of segment instance with a new unique TRID.
seq.addBlock(mr.makeLabel('SET', 'TRID', 48));  % any unique positive int
seq.addBlock(mr.makeDelay(1));  % pure delay block
seq.addBlock(adc);
seq.addBlock(mr.makeDelay(5e-3)); % make room for psd_grd_wait (gradient/ADC delay) and ADC ringdown

%% Check sequence timing
[ok, error_report] = seq.checkTiming;
if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

%% Output for execution
seq.setDefinition('FOV', [fov fov sliceThickness]);
seq.setDefinition('Name', fn);
seq.write([fn '.seq'])       % Write to pulseq file

% Optional slow step, but useful for testing during development,
% e.g., for the real TE, TR or for staying within slewrate limits  
% rep = seq.testReport;
% fprintf([rep{:}]);

% Next, convert to a .pge file and execute that file on a GE scanner. See main.m
