% Write multiple TI inversion-recovery stack-of-spirals sequence (ir.seq)
% for measuring T1 and checking the inversion pulse

seq = mr.Sequence(sys);           

nx = 64;
ny = nx;
nz = 10;
alpha = 5;
FLIP = 5*ones(nz,1);
fov = [24 24 4]*1e-2;

% Inversion times
TImin = 10e-3;     % sec
TImax = 0.5;
nTI = 10;
TI = logspace(log10(TImin), log10(TImax), nTI);
TI = ceil(TI/sys.blockDurationRaster)*sys.blockDurationRaster;

% background suppression (adiabatic inversion)
sw = 3; % kHz
duration = 3; % ms
rfwav = genSech180(sw, duration); % raster time is 4us
rfamp = 0.15;  % Gauss
rf = mr.makeArbitraryRf(rfwav, pi/2, 'delay', sys.rfDeadTime, 'system', sys);
rf.signal = rf.signal/max(abs(rf.signal)) * rfamp * 1e-4 * sys.gamma;   % Hz

% cartesian readout for testing
deltak = 1/fov(1);
dwell = 4e-6;
gx = mr.makeTrapezoid('x', 'FlatArea', nx*deltak, 'FlatTime', nx*dwell, 'system', sys);
adc = mr.makeAdc(nx, 'Duration', gx.flatTime, 'Delay', gx.riseTime, 'system', sys);

% spiral readout events
nleaf = 1;

slabThick = fov(3)*0.8;
nCyclesSpoil = 2;               % number of spoiler cycles
rfSpoilingInc = 117;            % RF spoiling increment

% Create alpha-degree slice selection pulse and gradient
[ex.rf, ex.gz] = mr.makeSincPulse(alpha*pi/180, 'Duration', 2e-3, ...
                        'SliceThickness', slabThick, 'apodization', 0.42, ...
                        'timeBwProduct', 8, 'system', sys);
ex.gzReph = mr.makeTrapezoid('z', sys, 'Area', -ex.gz.area/2, 'system',sys);

% spiral readout gradient 
[sp.wav, sp.dur] = getspiral(nleaf, sys.gradRasterTime, fov(1)*100, nx);
for leaf = 1:nleaf
    phi = (leaf-1)/nleaf*2*pi;
    gspwavtmp = sp.wav * exp(1i*phi);
    sp.gx{leaf} = mr.makeArbitraryGrad('x', real(gspwavtmp)*1e-4*sys.gamma*100, sys, ... 
                        'delay', sys.adcDeadTime);  
    sp.gy{leaf} = mr.makeArbitraryGrad('y', imag(gspwavtmp)*1e-4*sys.gamma*100, sys, ...
                        'delay', sys.adcDeadTime);  
end
sp.dwell = 4e-6;
sp.nread = 4*ceil(sp.dur/sp.dwell/4);
sp.adc = mr.makeAdc(sp.nread, sys, ...
    'Duration', sp.nread*sp.dwell, ...
    'Delay', 0);
sp.blockDuration = sp.adc.delay + sp.adc.numSamples * sp.dwell; % + sp.delayAfter;

% z prephaser and spoilers
deltak = 1./fov;
gzPre = mr.makeTrapezoid('z', sys, ...
    'Area', nz*deltak(3)/2);   % PE2 gradient, max positive amplitude
gzSpoil = mr.makeTrapezoid('z', sys, 'Area', nx*deltak(1)*nCyclesSpoil);
gxSpoil = mr.makeTrapezoid('x', sys, 'Area', nx*deltak(1)*nCyclesSpoil);

% z PE steps
% avoid exactly zero so that scaled trapezoids are recognized as such by Matlab Pulseq toolbox
pe2Steps = ((0:nz-1)-nz/2)/nz*2 + eps;

rf_phase = 0;
rf_inc = 0;
					 
for n = 1:length(TI)
    % inversion pulse and delay
    seq.addBlock(rf, mr.scaleGrad(gzPre, eps), mr.makeLabel('SET', 'TRID', 1)); %, mr.makeDelay(100e-3));
    %seq.addBlock(rf, mr.makeLabel('SET', 'TRID', 1), mr.makeDelay(100e-3));
    seq.addBlock(mr.makeDelay(TI(n)));

    %seq.addBlock(rf, mr.makeLabel('SET', 'TRID', 1));
%    seq.addBlock(rf);
%    seq.addBlock(mr.makeDelay(100e-3));

    % readout
    leaf = 1;
    for iz = 1:nz
	    % RF spoiling
	    ex.rf.phaseOffset = rf_phase/180*pi;
	    sp.adc.phaseOffset = rf_phase/180*pi;
	    rf_inc = mod(rf_inc+rfSpoilingInc, 360.0);
	    rf_phase = mod(rf_phase+rf_inc, 360.0);

	    %-- start segment --%
		
	    % excitation
        %tmp = ex.rf.signal;
        %ex.rf.signal = ex.rf.signal*FLIP(iz)/alpha;  % set flip angle
	    seq.addBlock(ex.rf, ex.gz, mr.makeLabel('SET', 'TRID', 2));
        %ex.rf.signal = tmp;
%	    seq.addBlock(ex.gzReph);

	    % readout
        pesc = pe2Steps(iz);
        pesc = pesc + (pesc == 0)*eps;        % non-zero scaling so that the trapezoid shape is preserved in the .seq file
	    seq.addBlock(mr.scaleGrad(gzPre, pesc));
%	    seq.addBlock(gx, adc);
	    seq.addBlock(sp.gx{leaf}, sp.gy{leaf}, sp.adc, mr.makeDelay(sp.blockDuration*2));
	    seq.addBlock(mr.scaleGrad(gzPre, -pesc));

	    % spoiling 
	    seq.addBlock(gxSpoil, gzSpoil);

	    %-- end segment --%
    end
end

save seq seq

%keyboard

seq.setDefinition('FOV', sections.acquire.getDefinition('FOV'));
seq.setDefinition('Name', 'ir');

% Check sequence timing
checktiming(seq);

% Write to Pulseq file
seq.write([fn '.seq']);

