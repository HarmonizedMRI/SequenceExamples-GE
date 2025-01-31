% Adapt https://github.com/pulseq/pulseq/blob/master/matlab/demoSeq/writeSpiral.m
% to tv6 interpreter for GE
%
% Key changes:
%  * Add TRID label
%  * ADC raster time = 2us
%  * Adjust timing so that durations and edge points lie on a 20us boundary (commonRasterTime).
%    This is done by wrapping gradient events in trap4ge/arb4ge/exttrap4ge calls.

dtDelay=1e-3;  % extra delay
fov=256e-3; mtx=64; Nx=mtx; Ny=mtx;        % Define FOV and resolution
Gmax=0.030;  % T/m
Smax=120; % T/m/s
sliceThickness=3e-3;             % slice thickness
Nslices=1;
Oversampling=2; % by looking at the periphery of the spiral I would say it needs to be at least 2
deltak=1/fov;

% Set system limits
% For tv6, just use default RF and gradient raster times (1us and 10us, respectively),
% since seq2ge.m will interpolate all waveforms to 4us raster time anyway,
% and since the Pulseq toolbox seems to have been more fully tested with these default settings.
% After creating the events, we'll do a bit of surgery below to make sure everything
% falls on 4us boundaries
sys = mr.opts('MaxGrad',Gmax*1e3, 'GradUnit', 'mT/m',...
    'MaxSlew', Smax, 'SlewUnit', 'T/m/s',...
    'rfDeadTime', 100e-6, ...
    'rfRingdownTime', 60e-6, ...
    'adcRasterTime', 2e-6, ...
    'gradRasterTime', 4e-6, ...
    'rfRasterTime', 2e-6, ...
    'blockDurationRaster', 4e-6, ...
    'B0', 3, ...
    'adcDeadTime', 0e-6); % , 'adcSamplesLimit', 8192);  

seq = mr.Sequence(sys);          % Create a new sequence object
warning('OFF', 'mr:restoreShape'); % restore shape is not compatible with spirals and will throw a warning from each plot() or calcKspace() call

% Create 90 degree slice selection pulse and gradient
[rf, gz] = mr.makeSincPulse(pi/2,'system',sys,'Duration',3e-3,...
    'SliceThickness',sliceThickness,'apodization',0.5,'timeBwProduct',4,'system',sys);
gzReph = mr.makeTrapezoid('z',sys,'Area',-gz.area/2,'system',sys);

% define k-space parameters

res=fov/mtx;        % [m]
Gmax=0.030;         % [T/m]
Smax=120;           % [T/(m*s)]
BW=125e3;           % [Hz]
dt=1/(2*BW);        % [s]
[k,g,s,time,r,theta]=vds(Smax*1e2,Gmax*1e2,dt,1,[fov*1e2,0],1/(2*res*1e2));
nRaiseTime=ceil(Gmax/Smax/sys.gradRasterTime);
gSpiral=[g,linspace(g(end),0,nRaiseTime)]/1e2*sys.gamma;
figure, plot(real(gSpiral)); hold on, plot(imag(gSpiral));
clear spiral_grad_shape;
spiral_grad_shape(1,:)=real(gSpiral);
spiral_grad_shape(2,:)=imag(gSpiral);
nspiral=size(spiral_grad_shape,2);

nADC=floor(sys.gradRasterTime/sys.adcRasterTime*nspiral/sys.adcSamplesDivisor)*sys.adcSamplesDivisor;
tADC=sys.adcRasterTime*nADC;
adc=mr.makeAdc(nADC,'Duration',tADC,'Delay',mr.calcDuration(gzReph)+dtDelay,'system',sys);
spiral_grad_shape = [spiral_grad_shape spiral_grad_shape(:,end)];
% extend spiral_grad_shape by repeating the last sample
% this is needed to accomodate for the ADC tuning delay
spiral_grad_shape = [spiral_grad_shape spiral_grad_shape(:,end)];

% readout grad 
gx = mr.makeArbitraryGrad('x',spiral_grad_shape(1,:),'Delay',mr.calcDuration(gzReph)+dtDelay,'system',sys);
gy = mr.makeArbitraryGrad('y',spiral_grad_shape(2,:),'Delay',mr.calcDuration(gzReph)+dtDelay,'system',sys);

% spoilers
gz_spoil=mr.makeTrapezoid('z',sys,'Area',deltak*Nx*8,'system',sys);

% Define sequence blocks
for s=1:Nslices
    % seq.addBlock(rf_fs,gz_fs, mr.makeLabel('SET', 'TRID', 1)); % fat-sat      % adding the TRID label needed by the GE interpreter
    rf.freqOffset = 0; %gz.amplitude*sliceThickness*(s-1-(Nslices-1)/2);
    seq.addBlock(rf, gz,mr.makeLabel('SET', 'TRID', 1));
    % seq.addBlock(gzReph);
    % seq.addBlock(mr.makeDelay(1e-3));
    % seq.addBlock(gx,gy,adc);
    seq.addBlock(gzReph,gx,gy,adc);
    seq.addBlock(gz_spoil);
end

% check whether the timing of the sequence is correct
[ok, error_report]=seq.checkTiming;

if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

%
seq.setDefinition('FOV', [fov fov sliceThickness]);
seq.setDefinition('Name', 'spiral');
% seq.setDefinition('MaxAdcSegmentLength', adcSamplesPerSegment); % this is important for making the sequence run automatically on siemens scanners without further parameter tweaking

seq.write('spiral.seq');   % Output sequence for scanner

% the sequence is ready, so let's see what we got 
seq.plot();             % Plot sequence waveforms

return

