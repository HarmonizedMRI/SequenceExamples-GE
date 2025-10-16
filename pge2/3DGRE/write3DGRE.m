% write3DGRE.m
%
% 3D GRE demo sequence for Pulseq on GE v1.0 User Guide

% System/design parameters.
sys = mr.opts('MaxGrad', 22, 'GradUnit', 'mT/m',...
    'MaxSlew', 150, 'SlewUnit', 'T/m/s',...
    'rfDeadTime', 100e-6, ...
    'rfRingdownTime', 60e-6, ...
    'adcRasterTime', 2e-6, ...
    'gradRasterTime', 4e-6, ...
    'rfRasterTime', 4e-6, ...
    'blockDurationRaster', 4e-6, ...
    'B0', 3, ...
    'adcSamplesDivisor', 2, ...   % 4 on Siemens; 1 on GE
    'adcDeadTime', 40e-6); % , 'adcSamplesLimit', 8192); 

% Acquisition parameters
fov = [240e-3 240e-3 240e-3];   % FOV (m)
Nx = 48; Ny = Nx; Nz = Nx;    % Matrix size
dwell = 10e-6;                  % ADC sample time (s)
alpha = 5;                      % flip angle (degrees)
alphaPulseDuration = 0.2e-3;
nCyclesSpoil = 2;               % number of spoiler cycles
Tpre = 1.0e-3;                  % prephasing trapezoid duration
rfSpoilingInc = 117;            % RF spoiling increment

% Create a new sequence object
seq = mr.Sequence(sys);           

% Create non-selective pulse
[rf] = mr.makeBlockPulse(alpha/180*pi, sys, 'Duration', alphaPulseDuration, ...
    'use', 'excitation');

% Define other gradients and ADC events
% Cut the redaout gradient into two parts for optimal spoiler timing
deltak = 1./fov;
Tread = Nx*dwell;

gyPre = mr.makeTrapezoid('y', sys, ...
    'Area', Ny*deltak(2)/2, ...   % PE1 gradient, max positive amplitude
    'Duration', Tpre);
gzPre = mr.makeTrapezoid('z', sys, ...
    'Area', Nz*deltak(3)/2, ...   % PE2 gradient, max positive amplitude
    'Duration', Tpre);

gxtmp = mr.makeTrapezoid('x', sys, ...  % readout trapezoid, temporary object
    'Amplitude', Nx*deltak(1)/Tread, ...
    'FlatTime', Tread);
gxPre = mr.makeTrapezoid('x', sys, ...
    'Area', -gxtmp.area/2, ...
    'Duration', Tpre);

adc = mr.makeAdc(Nx, sys, ...
    'Duration', Tread,...
    'Delay', gxtmp.riseTime);

% extend flat time so we can split at end of ADC dead time
gxtmp2 = mr.makeTrapezoid('x', sys, ...  % temporary object
    'Amplitude', Nx*deltak(1)/Tread, ...
    'FlatTime', Tread + adc.deadTime);   
[gx, ~] = mr.splitGradientAt(gxtmp2, gxtmp2.riseTime + gxtmp2.flatTime, 'system', sys);

gzSpoil = mr.makeTrapezoid('z', sys, ...
    'Area', Nx*deltak(1)*nCyclesSpoil);
gxSpoil = mr.makeExtendedTrapezoidArea('x', gxtmp.amplitude, 0, gzSpoil.area, sys);

% y/z PE steps
pe1Steps = ((0:Ny-1)-Ny/2)/Ny*2;
pe2Steps = ((0:Nz-1)-Nz/2)/Nz*2;

% Loop over phase encodes and define sequence blocks
% iZ < 0: Dummy shots to reach steady state
% iZ = 0: ADC is turned on and used for receive gain calibration on GE scanners
% iZ > 0: Image acquisition

nDummyZLoops = 1;

rf_phase = 0;
rf_inc = 0;

for iZ = -nDummyZLoops:Nz
    isDummyTR = iZ < 0;

    msg = sprintf('z encode %d of %d   ', iZ, Nz);
    for ibt = 1:(length(msg) + 2)
        fprintf('\b');
    end
    fprintf(msg);

    for iY = 1:Ny
        % Turn on y and z prephasing lobes, except during dummy scans and
        % receive gain calibration (auto prescan)
        yStep = (iZ > 0) * pe1Steps(iY);
        zStep = (iZ > 0) * pe2Steps(max(1,iZ));

        % Update RF phase
        rf.phaseOffset = rf_phase/180*pi;
        adc.phaseOffset = rf_phase/180*pi;
        rf_inc = mod(rf_inc+rfSpoilingInc, 360.0);
        rf_phase = mod(rf_phase+rf_inc, 360.0);
        
        % Mark start of segment (block group) by adding TRID label
        seq.addBlock(rf, mr.makeLabel('SET', 'TRID', 2-isDummyTR));

        % Excitation
%        seq.addBlock(rf);
        
        % Encoding
        seq.addBlock(gxPre, ...
            mr.scaleGrad(gyPre, yStep), ...
            mr.scaleGrad(gzPre, zStep));
        if isDummyTR
            seq.addBlock(gx);
        else
            seq.addBlock(gx, adc);
        end

        % rephasing/spoiling
        seq.addBlock(gxSpoil, ...
            mr.scaleGrad(gyPre, -yStep), ...
            mr.scaleGrad(gzPre, -zStep));
    end
end
fprintf('Sequence ready\n');

% Check sequence timing
[ok, error_report]=seq.checkTiming;
if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

% Output for execution
seq.setDefinition('FOV', fov);
seq.setDefinition('Name', 'gre');
seq.write('gre3d.seq');

%% Optional plots

% Plot sequence
Noffset = Ny*(nDummyZLoops+1);
seq.plot('timerange',[Noffset Noffset+4]*TR, 'timedisp', 'ms');

return

% Plot k-space (2d)
[ktraj_adc,t_adc,ktraj,t_ktraj,t_excitation,t_refocusing] = seq.calculateKspacePP();
figure; plot(ktraj(1,:),ktraj(2,:),'b'); % a 2D k-space plot
axis('equal'); % enforce aspect ratio for the correct trajectory display
hold;plot(ktraj_adc(1,:),ktraj_adc(2,:),'r.'); % plot the sampling points
title('full k-space trajectory (k_x x k_y)');
