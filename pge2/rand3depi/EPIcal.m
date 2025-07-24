% Calibration scan sequence for EPI
%
% This short sequence first excites the volume to steady state, then 
% acquires many readout lines without Gy and Gz blips to:
% 1. Allow the scanner to tune receiver gains
% 2. Collect data used for EPI ghost correciton

%% Define experiment parameters
run('params.m');

%% Path and options
seqname = 'EPIcal';

%% Excitation pulse
% Target a slightly thinner slice to alleviate aliasing
[rf, gzSS, gzSSR, delay] = mr.makeSincPulse(alpha/180*pi,...
                                     'duration',rfDur,...
                                     'sliceThickness',0.9*fov(3),...
                                     'system',sys,...
                                     'use','excitation');
gzSS = trap4ge(gzSS,CRT,sys);
gzSS.delay = rf.delay - gzSS.riseTime; % Sync up rf pulse and slice select gradient
gzSSR = trap4ge(gzSSR,CRT,sys);

%% Fat-sat
fatsat.flip    = 90;      % degrees
fatsat.slThick = 1e5;     % dummy value (determines slice-select gradient, but we won't use it; just needs to be large to reduce dead time before+after rf pulse)
fatsat.tbw     = 3;       % time-bandwidth product
fatsat.dur     = 6.0;     % pulse duration (ms)

% RF waveform in Gauss
wav = toppe.utils.rf.makeslr(fatsat.flip, fatsat.slThick, fatsat.tbw, fatsat.dur, 1e-6, toppe.systemspecs(), ...
    'type', 'ex', ... % fatsat pulse is a 90 so is of type 'ex', not 'st' (small-tip)
    'ftype', 'min', ...
    'writeModFile', false);

% Convert from Gauss to Hz, and interpolate to sys.rfRasterTime
rfp = rf2pulseq(wav, 4e-6, sys.rfRasterTime);

% Create pulseq object
% Try to account for the fact that makeArbitraryRf scales the pulse as follows:
% signal = signal./abs(sum(signal.*opt.dwell))*flip/(2*pi);
flip_ang = fatsat.flip/180*pi;
flipAssumed = abs(sum(rfp));
rfsat = mr.makeArbitraryRf(rfp, ...
    flip_ang*abs(sum(rfp*sys.rfRasterTime))*(2*pi), ...
    'system', sys, ...
    'use', 'saturation');
rfsat.signal = rfsat.signal/max(abs(rfsat.signal))*max(abs(rfp)); % ensure correct amplitude (Hz)
rfsat.freqOffset = -fatOffresFreq; % Hz

%% Define readout gradients and ADC event
% The Pulseq toolbox really shines here!

% Define k-space spacing for fully-sampled data
deltak = 1./fov;

% Start with the blips. Ensure long enough to support the largest blips
gyBlip = mr.scaleGrad(mr.makeTrapezoid('y', sys, 'area', max_ky_step*deltak(2)), 1/max_ky_step);
gyBlip = trap4ge(gyBlip,CRT,sys);
if caipi_z > 1
    gzBlip = mr.scaleGrad(mr.makeTrapezoid('z', sys, 'area', (caipi_z - 1)*deltak(3)), 1/(caipi_z - 1));
else
    gzBlip = mr.scaleGrad(mr.makeTrapezoid('z', sys, 'area', (caipi_z - 1)*deltak(3)), 1);
end
gzBlip = trap4ge(gzBlip,CRT,sys);

% Area and duration of the longest blip (in y or z)
if mr.calcDuration(gyBlip) > mr.calcDuration(gzBlip) % biggest blip in y
    maxBlipArea = max_ky_step*deltak(2);
    blipDuration = mr.calcDuration(gyBlip);

    % Remake the other blips to match duration
    gzBlip = mr.makeTrapezoid('z', sys, 'area', deltak(3), 'duration', blipDuration);
    % gzBlip = trap4ge(gzBlip,CRT,sys);
else % biggest blip in z
    maxBlipArea = (caipi_z - 1)*deltak(3);
    blipDuration = mr.calcDuration(gzBlip);

    % Remake the other blips to match duration
    gyBlip = mr.makeTrapezoid('y', sys, 'area', deltak(2), 'duration', blipDuration);
    % gyBlip = trap4ge(gyBlip,CRT,sys);
end

% Readout trapezoid
systmp = sys;
systmp.maxGrad = deltak(1)/dwell;  % to ensure Nyquist sampling
gro = trap4ge(mr.makeTrapezoid('x', systmp, 'Area', Nx*deltak(1) + maxBlipArea),CRT,sys);

% Circularly shift gro waveform to contain blips within each block
[gro1, gro2] = mr.splitGradientAt(gro, blipDuration/2);
gro2.delay = 0;
gro1.delay = gro2.shape_dur;
gro = mr.addGradients({gro2, mr.scaleGrad(gro1, -1)}, sys);
gro1.delay = 0; % This piece is necessary at the very beginning of the readout

% ADC event
Tread = mr.calcDuration(gro) - blipDuration;
Nfid = floor(Tread/dwell/4)*4;
adc = mr.makeAdc(Nfid, 'Dwell', dwell);

% Delay blips so they play after adc stops
gyBlip.delay = Tread;
gzBlip.delay = Tread;

% Prephasers (Make duration long enough to support all 3 directions)
gxPre = trap4ge(mr.makeTrapezoid('x',sys,'Area',-(Nx*deltak(1) + maxBlipArea)/2),CRT,sys);
gyPre = trap4ge(mr.makeTrapezoid('y',sys,'Area',-Ny/2*deltak(2)),CRT,sys);
gzPre = trap4ge(mr.makeTrapezoid('z',sys,'Area',-Nz/2*deltak(3)),CRT,sys);

% Spoilers (conventionally only in x and z because ??, might as well do so in y)
gxSpoil = trap4ge(mr.makeTrapezoid('x', sys, ...
    'Area', Nx*deltak(1)*NcyclesSpoil),CRT,sys);
gySpoil = trap4ge(mr.makeTrapezoid('y', sys, ...
    'Area', Ny*deltak(2)*NcyclesSpoil),CRT,sys);
gzSpoil = trap4ge(mr.scaleGrad(...
    mr.makeTrapezoid('z', sys, 'Area', Nz*deltak(3)*(NcyclesSpoil + 0.5)),...
    NcyclesSpoil/(NcyclesSpoil + 0.5)),CRT,sys);

%% Calculate delay to achieve desired TE
minTE = 0.5*mr.calcDuration(rf)...
      + mr.calcDuration(gzSSR)...
      + max([mr.calcDuration(gxPre), mr.calcDuration(gyPre), mr.calcDuration(gzPre)])...
      + (2*ceil(Ny/Ry/2)/2 - 0.5) * mr.calcDuration(gro);
if TE >= minTE
    TEdelay = floor((TE - minTE)/sys.blockDurationRaster) * sys.blockDurationRaster;
else
    warning(sprintf('Minimum achievable TE (%d) exceeds prescribed TE (%d)',...
                    minTE, TE))
    TEdelay = 0;
end

%% Calculate delay to achieve desired TR
minTR = mr.calcDuration(rfsat)...
      + max([mr.calcDuration(gxSpoil), mr.calcDuration(gzSpoil)])...
      + max([mr.calcDuration(rf), mr.calcDuration(gzSS)])...
      + mr.calcDuration(gzSSR)...
      + TEdelay...
      + max([mr.calcDuration(gxPre), mr.calcDuration(gyPre), mr.calcDuration(gzPre)])...
      + 2*ceil(Ny/Ry/2) * mr.calcDuration(gro)...
      + mr.calcDuration(gzPre)...
      + max([mr.calcDuration(gxSpoil), mr.calcDuration(gzSpoil)]);
if TR >= minTR
    TRdelay = floor((TR - minTR)/sys.blockDurationRaster)*sys.blockDurationRaster;
else
    warning(sprintf('Minimum achievable TR (%d) exceeds prescribed TR (%d)',...
                    minTR, TR))
    TRdelay = 0;
end

%% Assemble sequence
% manually set to 0 to avoid annoying warnings. 
% Shouldn't be a problem since I don't have back-to-back blocks with adc.
sys.adcDeadTime = 0;

seq = mr.Sequence(sys);

% RF spoiling trackers
rf_count = 1;
rf_phase = rf_phase_0;

% kz encoding loop (fake)
z_locs = 1:caipi_z:(Nz - caipi_z + 1);
for iz = -Ndummyframes:length(z_locs)
    % Convenience booleans for turning off adc
    isDummyFrame = iz < 0;
    isCalFrame = iz > 0;

    % Label the first block in each segment with the TRID (see Pulseq on GE manual)
    if isDummyFrame
        TRID = 1;
    elseif isCalFrame
        TRID = 2;
    end

    % turn off kz encoding
    gzPreTmp = mr.scaleGrad(gzPre, 0);

    % Fat-sat
    seq.addBlock(rfsat,mr.makeLabel('SET','TRID',TRID));
    seq.addBlock(gxSpoil, gzSpoil);

    % RF spoiling
    rf_phase = mod(0.5 * rf_phase * rf_count^2, 360.0);
    rf.phaseOffset = rf_phase/180*pi;
    adc.phaseOffset = rf_phase/180*pi;
    rf_count = rf_count + 1;

    % Slab-selective RF excitation + rephase
    seq.addBlock(rf,gzSS);
    seq.addBlock(gzSSR);

    % TE delay
    if TE > minTE
        seq.addBlock(mr.makeDelay(TEdelay));
    end

    % fake ky encoding
        % Move to corner of k-space
        gyPreTmp = mr.scaleGrad(gyPre, 0); % turn off ky encoding
        seq.addBlock(gxPre, gyPreTmp, gzPreTmp);
    
        % Zip through k-space with EPI trajectory
        seq.addBlock(gro1);
        for iy = 1:(2*ceil(Ny/Ry/2) - 1)
            if isCalFrame
                seq.addBlock(adc, mr.scaleGrad(gro, (-1)^(iy-1)),...
                    mr.scaleGrad(gyBlip, 0));
            else
                seq.addBlock(mr.scaleGrad(gro, (-1)^(iy-1)),...
                    mr.scaleGrad(gyBlip, 0));
            end
        end
    
        % Last line
        if isCalFrame
            seq.addBlock(adc, mr.scaleGrad(gro2, (-1)^iy));
        else
            seq.addBlock(mr.scaleGrad(gro2, (-1)^iy));
        end
    % end ky encoding

    % spoil
    seq.addBlock(gxSpoil, gzSpoil);

    % Achieve desired TR
    if TR > minTR
        seq.addBlock(mr.makeDelay(TRdelay));
    end
end

%% Check sequence timing
[ok, error_report]=seq.checkTiming;
if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

%% Write to .seq file
seq.setDefinition('FOV', fov);
seq.setDefinition('Name', seqname);
seq.write(strcat(seqname, '.seq'));

%% Interpret to GE via TOPPE
% manually set to 0 to avoid annoying warnings. 
% Shouldn't be a problem since I don't have back-to-back blocks with adc.
sysGE.adcDeadTime = 0;

% tv6
% seq2ge(strcat(seqname, '.seq'), sysGE, strcat(seqname, '.tar'))
% system(sprintf('tar -xvf %s', strcat(seqname, '.tar')));

% write to GE compatible files
ceq = seq2ceq(strcat(seqname, '.seq'));

% Define hardware parameters
psd_rf_wait = 150e-6;  % RF-gradient delay, scanner specific (s)
psd_grd_wait = 120e-6; % ADC-gradient delay, scanner specific (s)
b1_max = 0.25;         % Gauss
g_max = 5;             % Gauss/cm
slew_max = 20;         % Gauss/cm/ms
gamma = 4.2576e3;      % Hz/Gauss
sysPGE2 = pge2.getsys(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, gamma);

% Check if 'ceq' is compatible with the parameters in 'sys'
pge2.validate(ceq, sysPGE2);

% Write Ceq object to file
pislquant = 10;  % number of ADC events at start of scan for receive gain calibration
writeceq(ceq, strcat(seqname, '.pge'), 'pislquant', pislquant);   % write Ceq struct to file

%% Plot in pulseq
seq.plot('timeRange', [0 max(minTR, TR)]);

return;
%% Plot
figure('WindowState','maximized');
% tv6
% toppe.plotseq(sysGE, 'timeRange', [0 (Ndummyframes + 1)*TR]);

% tv7/pge2
S = pge2.constructvirtualsegment(ceq.segments(1).blockIDs, ceq.parentBlocks, sysPGE2, true);

return;

%% Detailed sequence report
% Slow but useful for testing during development,
% e.g., for the real TE, TR or for staying within slew rate limits
rep = seq.testReport;
fprintf([rep{[1:9, 11:end]}]); % print report except warnings

return;