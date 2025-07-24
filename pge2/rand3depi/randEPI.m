% Pseudo-random 3D EPI sequence w/ z blips for CAIPI-like shifting
% Continuous readout gradient for speed.
% Create blocks without splitting blips.
% Represent readout gradients as arbitrary instead of trapezoids.
% CAIPI added to sample multiple kz locations per RF excitation
% Rex Fung

%% Define experiment parameters
run('params.m');

% Temporary modifications
NframesPerLoop = 1; % Only one frame for plotting k-space trajectory

%% Path and options
seqname = 'randEPI';

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

%% Generate temporally incoherent sampling masks
% Gaussian sampling weights
weights_y = normpdf(1:Ny, mean(1:Ny), Ny/6);
weights_z = normpdf(1:Nz, mean(1:Nz), Nz/6);

omegas = zeros(Ny,Nz,NframesPerLoop);
acs_indices_z = zeros(round(Nz*acs(2)), 1); % same for all frames
nacs_indices_z = zeros(round(Nz/Rz/caipi_z) - round(Nz*acs(2)), NframesPerLoop);
for frame = 1:NframesPerLoop
    % Create pseudo-random 2D sampling mask. Save for recon
    rng(frame); % A different mask per frame
    [omegas(:,:,frame), ...
     acs_indices_z, ...
     nacs_indices_z(:,frame)] ...
     = randsamp2dcaipi(N(2:end), R, acs, weights_y, weights_z, max_ky_step, caipi_z);
end

%% Define readout gradients and ADC event
% The Pulseq toolbox really shines here!

% Define k-space spacing for fully-sampled data
deltak = 1./fov;

% Start with the blips. Ensure long enough to support the largest blips
gyBlip = mr.makeTrapezoid('y', sys, 'area', max_ky_step*deltak(2));
gyBlip = mr.scaleGrad(gyBlip, 1/max_ky_step, sys);
gyBlip = trap4ge(gyBlip,CRT,sys);
if caipi_z > 1
    gzBlip = mr.makeTrapezoid('z', sys, 'area', max_kz_step*deltak(3));
    gzBlip = mr.scaleGrad(gzBlip, 1/max_kz_step, sys);
elseif caipi_z == 1
    gzBlip = mr.makeTrapezoid('z', sys, 'area', 0);
end
gzBlip = trap4ge(gzBlip,CRT,sys);

% Match blip durations
if mr.calcDuration(gyBlip) > mr.calcDuration(gzBlip) % biggest blip in y
    maxBlipArea = max_ky_step*deltak(2);
    blipDuration = mr.calcDuration(gyBlip);
    if caipi_z > 1
        gzBlip = mr.makeTrapezoid('z', sys, 'area', max_kz_step*deltak(3), 'duration', blipDuration);
        gzBlip = mr.scaleGrad(gzBlip, 1/max_kz_step, sys);
    elseif caipi_z == 1
        gzBlip = mr.makeTrapezoid('z', sys, 'area', 0);
    end
else % biggest blip in z
    maxBlipArea = max_kz_step*deltak(3);
    blipDuration = mr.calcDuration(gzBlip);
    gyBlip = mr.makeTrapezoid('y', sys, 'area', max_ky_step*deltak(2));
    gyBlip = mr.scaleGrad(gyBlip, 1/max_ky_step, sys);
end

% Readout trapezoid
systmp = sys;
systmp.maxGrad = deltak(1)/dwell;  % to ensure Nyquist sampling
gro = mr.makeTrapezoid('x', systmp, 'Area', Nx*deltak(1) + maxBlipArea);
gro = trap4ge(gro,CRT,sys);

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
      + (2*round(Ny/Ry/2)/2 - 0.5) * mr.calcDuration(gro);
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
      + 2*round(Ny/Ry/2) * mr.calcDuration(gro)...
      + max([mr.calcDuration(gxSpoil), mr.calcDuration(gySpoil), mr.calcDuration(gzSpoil)]);
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

% log the sequence of k-space locations sampled (ky and kz)
samp_log = zeros(NframesPerLoop, ...
                 round(Nz/caipi_z/Rz)*2*ceil(Ny/Ry/2), ...
                 2);

% RF spoiling trackers
rf_count = 1;
rf_phase = rf_phase_0;

for frame = 1:NframesPerLoop
    fprintf('Writing frame %d\n', frame)
    % Load in kz-ky sampling mask
    omega = omegas(:,:,frame);

    % Reset sample count
    samp_count = 1;

    % kz encoding loop
    % Each "z_loc" is the starting point of a partition of kz locations
    z_locs = sort([acs_indices_z, nacs_indices_z(:,frame)']);
    for z = z_locs
        % Label the first block in each "unique" section with TRID (see Pulseq on GE manual)
        TRID = 1;

        % Fat-sat
        seq.addBlock(rfsat, mr.makeLabel('SET','TRID',TRID));
        seq.addBlock(gxSpoil, gzSpoil);

        % RF spoiling
        rf_phase = mod(0.5 * rf_phase_0 * rf_count^2, 360.0);
        rf.phaseOffset = rf_phase/180*pi;
        adc.phaseOffset = rf_phase/180*pi;
        rf_count = rf_count + 1;

        % Slab-selective RF excitation + rephase
        seq.addBlock(rf, gzSS);
        seq.addBlock(gzSSR);

        % TE delay
        if TE > minTE
            seq.addBlock(mr.makeDelay(TEdelay));
        end

        % Infer caipi shifts from sampling mask
        z_shifts = zeros(1, 2*round(Ny/Ry/2));
        if ismember(z, nacs_indices_z(:,frame))
            caipi_z_range = (1:caipi_z) - round(caipi_z/2); % Compute range of caipi shifts
            part = omega(:,z + caipi_z_range);
            y_locs = find(sum(part,2));
            for i = 1:length(y_locs)
                z_shifts(i) = find(part(y_locs(i),:)) - 1;
            end
        else
            y_locs = find(omega(:,z));
        end

        % Move to corner of k-space
        gzPreTmp = mr.scaleGrad(gzPre, (z + z_shifts(1) - Nz/2 - 1)/(-Nz/2));
        gyPreTmp = mr.scaleGrad(gyPre, (y_locs(1) - Ny/2 - 1)/(-Ny/2));
        seq.addBlock(gxPre, gyPreTmp, gzPreTmp);

        % Begin ky encoding
        % Zip through k-space with EPI trajectory
        seq.addBlock(gro1);
        for iy = 1:(length(y_locs) - 1)
            % Log sampling locations
            samp_log(frame,samp_count,:) = [y_locs(iy); z + z_shifts(iy)];
            samp_count = samp_count + 1;

            % Sample
            seq.addBlock(adc, mr.scaleGrad(gro, (-1)^(iy-1)),...
                mr.scaleGrad(gyBlip, y_locs(iy + 1) - y_locs(iy)),...
                mr.scaleGrad(gzBlip, z_shifts(iy + 1) - z_shifts(iy))...
                );
        end

        % Last line
        % Log sampling locations
        samp_log(frame,samp_count,:) = [y_locs(end); z + z_shifts(end)];
        samp_count = samp_count + 1;

        % Sample
        seq.addBlock(adc, mr.scaleGrad(gro2, (-1)^iy));

        % End ky encoding

        % Gx, Gz spoilers. Gy rewinder gradients
        seq.addBlock(gxSpoil, ...
            mr.scaleGrad(gySpoil, -(y_locs(end) - Ny/2 - 1)*deltak(2)/gySpoil.area), ...
            mr.scaleGrad(gzSpoil, (gzSpoil.area - (z + z_shifts(end) - Nz/2)*deltak(3))/gzSpoil.area));

        % Achieve desired TR
        if TR > minTR
            seq.addBlock(mr.makeDelay(TRdelay));
        end
    end
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

%% Save sampling log for recon
save('samp_log.mat','samp_log','-v7.3');

%% Save k-space trajectory for EPI ghost correction
[ktraj_adc, t_adc, ktraj, t_ktraj, t_excitation, t_refocusing] = seq.calculateKspacePP();
kxo = ktraj_adc(1, 1:Nfid);
kxe = ktraj_adc(1, Nfid+1:Nfid*2);

save(sprintf('kxoe%d.mat', Nx),'kxo','kxe','-v7.3');

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

%% Plot trajectories stringing together samples (ChatGPT)
figure('WindowState','maximized');
hold on;

% Loop over each excitation
for i = 1:length(t_excitation)
    t_start = t_excitation(i);
    
    % Use end of current excitation or end of ADC window
    if i < length(t_excitation)
        t_end = t_excitation(i+1);
    else
        t_end = t_adc(end) + 1e-6;  % Small buffer
    end

    % Find ADC times within this excitation window
    adc_mask = t_adc >= t_start & t_adc < t_end;
    t_adc_segment = t_adc(adc_mask);

    % Map ADC times to indices in t_ktraj
    adc_indices = arrayfun(@(t) find(abs(t_ktraj - t) < 1e-9, 1, 'first'), t_adc_segment);

    % Extract corresponding k-space trajectory points
    ktraj_segment = ktraj(:, adc_indices);

    % Plot this segment as a separate line
    if ~isempty(ktraj_segment)
        plot(ktraj_segment(2,:), ktraj_segment(3,:), 'b', 'LineWidth', 1.5);
    end
end

plot(ktraj_adc(2,:), ktraj_adc(3,:),'r.', 'MarkerSize', 10); % plot the sampling points

axis equal;
title(sprintf('Random 3D-EPI trajectory. R = %d', round(Ry*Rz*caipi_z)), 'FontSize', 18);
xlabel('k_y (m^{-1})', 'FontSize', 18); ylabel('k_z (m^{-1})', 'FontSize', 18);

return;

%% Plot in TOPPE
% tv6
% toppe.plotseq(sysGE, 'timeRange', [0 (Ndummyframes + 1)*TR]);

% tv7/pge2
figure;
S = pge2.constructvirtualsegment(ceq.segments(1).blockIDs, ceq.parentBlocks, sysPGE2, true);

return;

%% Calculate and plot k-space trajectory
figure('WindowState','maximized');
plot(ktraj(2,:),ktraj(3,:),'b'); % a 2D k-space plot
axis('equal'); % enforce aspect ratio for the correct trajectory display
hold; plot(ktraj_adc(2,:),ktraj_adc(3,:),'r.', 'MarkerSize', 10); % plot the sampling points
title('full k-space trajectory (k_y x k_z)'); 
xlabel('k_y'); ylabel('k_z');

return;

%% Detailed sequence report
% Slow but useful for testing during development,
% e.g., for the real TE, TR or for staying within slew rate limits
rep = seq.testReport;
fprintf([rep{[1:9, 11:end]}]); % print report except warnings

return;