function [sections, readout, TRIDs] = getsections(sys, TRIDs)
% Define various sequence sections.
% Each section contains one or more Pulseq blocks.
% The calling script (e.g., writeIR.m) assembles these sections
% into a sequence.
%
% Inputs
%  sys      Pulseq system struct
%  TRIDs    [1]   vector of unique integers
%
% Outputs
%  sections.tag       Pulseq sequence object handle     VS tag
%  sections.control   Pulseq sequence object handle     VS control
%  sections.inv       Pulseq sequence object handle     Adiabatic inversion
%  sections.acquire   Pulseq sequence object handle     stack of spirals readout
%  TRIDs    [1]       Same as input, except with the last few entries removed

sections.gdummy = mr.makeTrapezoid('x', 'Area', 0.01*64/24e-2, 'Duration', 0.1e-3, 'system', sys);
sections.gdummy = mr.scaleGrad(sections.gdummy, eps);  % don't scale to exactly 0 so the trapezoid shape is preserved in the .seq file

% global sat pulse
[sat.rf] = mr.makeSincPulse(90*pi/180, 'Duration', 2e-3, ...
                        'SliceThickness', 1, 'apodization', 0.42, ...
                        'use', 'excitation', ...
                        'timeBwProduct', 2, 'system', sys);
sat.gx = mr.makeTrapezoid('x', 'Area', 2*64/24e-2, 'Duration', 2e-3, 'system', sys);
sat.gz = mr.makeTrapezoid('z', 'Area', 2*64/24e-2, 'Duration', 2e-3, 'system', sys);
sections.sat = mr.Sequence(sys);
sections.sat.addBlock(sat.rf, mr.makeLabel('SET', 'TRID', TRIDs(end)));
TRIDs(end) = [];   % make sure we don't reuse the last TRID
sections.sat.addBlock(sat.gx, sat.gz);

% Velocity-selective labeling (tag/control) pulses
if false
    % BIR VS sat 
    [rfwav, gwav] = readaslprep('06800');   % velocity sat pulse?
else
    % FT VSI
    addpath sim
    [rfwav, gwav] = genVSI(0, 15, sys.gradRasterTime);    % this is the nominal tag pulse
    rfwav = [rfwav rfwav];
    gwav = [gwav abs(gwav)];
end
maxB1_G = max(abs(rfwav(:)));  % Gauss
for label = 1:2    % 1: tag; 2: control
    rf{label} = mr.makeArbitraryRf(rfwav(:,label), pi/2, 'delay', sys.rfDeadTime, 'system', sys, ...
                        'use', 'excitation');
    rf{label}.signal = rf{label}.signal/max(abs(rf{label}.signal)) * maxB1_G * 1e-4 * sys.gamma;   % Scale to desired amplitude (in Hz).
    g{label} = mr.makeArbitraryGrad('z', gwav(:,label)*1e-4*sys.gamma*100, sys, ... 
                                'first', 0, 'last', 0, ...
                                'delay', sys.adcDeadTime); % input to function is waveform in Hz/m
end

sections.tag = mr.Sequence(sys);           
label = 1;
sections.tag.addBlock(rf{label}, g{label}, mr.makeLabel('SET', 'TRID', TRIDs(end)));
sections.tag.addBlock(sections.gdummy, mr.makeDelay(1e-3));  % a segment needs more than one block
TRIDs(end) = [];
sections.tag.setDefinition('Name', 'tag');

sections.control = mr.Sequence(sys);           
label = 2;
sections.control.addBlock(rf{label}, g{label}, mr.makeLabel('SET', 'TRID', TRIDs(end)));
sections.tag.addBlock(sections.gdummy, mr.makeDelay(1e-3));  % a segment needs more than one block
TRIDs(end) = [];
sections.control.setDefinition('Name', 'control');

% VSI QA section.
% Velocity-selective inversion labeling (tag/control) pulses.
% Add a reference scan with a small velocity-mimicking gradient blip so that
% the 'velocity' profile can be measured in a stationary phantom.
% Note that velocity-selectivity is along x (in plane).
addpath sim
[rfwav, gwav] = genVSI(0, 15, sys.gradRasterTime);    % this is the nominal tag pulse
[tmp, gwavmimick] = genVSI(pi/2, 15, sys.gradRasterTime);   % same but with gradient blips added to mimick flow
rfwav = [rfwav rfwav rfwav];
gwav = [gwav abs(gwav) gwavmimick];
maxB1_G = max(abs(rfwav(:)));  % Gauss
for label = 1:3    % 1: tag; 2: control; 3: velocity-mimicking gradient blips
    rf{label} = mr.makeArbitraryRf(rfwav(:,label), pi/2, 'delay', sys.rfDeadTime, 'system', sys, ...
                        'use', 'excitation');
    rf{label}.signal = rf{label}.signal/max(abs(rf{label}.signal)) * maxB1_G * 1e-4 * sys.gamma;   % Scale to desired amplitude (in Hz).
    g{label} = mr.makeArbitraryGrad('x', gwav(:,label)*1e-4*sys.gamma*100, sys, ... 
                                'first', 0, 'last', 0, ...
                                'delay', sys.adcDeadTime); % input to function is waveform in Hz/m
end

sections.qatag = mr.Sequence(sys);           
label = 1;
sections.qatag.addBlock(rf{label}, g{label}, mr.makeLabel('SET', 'TRID', TRIDs(end)));
TRIDs(end) = [];
sections.qatag.addBlock(sections.gdummy, mr.makeDelay(1e-3));  % a segment needs more than one block
sections.qatag.setDefinition('Name', 'qatag');

sections.qacontrol = mr.Sequence(sys);           
label = 2;
sections.qacontrol.addBlock(rf{label}, g{label}, mr.makeLabel('SET', 'TRID', TRIDs(end)));
TRIDs(end) = [];
sections.qacontrol.addBlock(sections.gdummy, mr.makeDelay(1e-3));  % a segment needs more than one block
sections.qacontrol.setDefinition('Name', 'qacontrol');

sections.qaref = mr.Sequence(sys);           
label = 3;
sections.qaref.addBlock(rf{label}, g{label}, mr.makeLabel('SET', 'TRID', TRIDs(end)));
TRIDs(end) = [];
sections.qaref.addBlock(sections.gdummy, mr.makeDelay(1e-3));  % a segment needs more than one block
sections.qaref.setDefinition('Name', 'qaref');

% vascular suppression pulse
[rfwav, gwav] = readaslprep('06850'); 
maxB1_G = max(abs(rfwav(:)));  % Gauss
label = 1;  
rf{label} = mr.makeArbitraryRf(rfwav(:,label), pi/2, 'delay', sys.rfDeadTime, 'system', sys, 'use', 'excitation'); 
rf{label}.signal = rf{label}.signal/max(abs(rf{label}.signal)) * maxB1_G * 1e-4 * sys.gamma;   % Scale to desired amplitude (in Hz).
g{label} = mr.makeArbitraryGrad('z', gwav(:,label)*1e-4*sys.gamma*100, sys, ...
                                'first', 0, 'last', 0, ...
                                'delay', sys.adcDeadTime); % input to function is waveform in Hz/m

sections.vascsuppress = mr.Sequence(sys);           
sections.vascsuppress.addBlock(rf{label}, g{label}, mr.makeLabel('SET', 'TRID', TRIDs(end)));
TRIDs(end) = [];
sections.vascsuppress.addBlock(sections.gdummy, mr.makeDelay(1e-3));  % a segment needs more than one block
sections.vascsuppress.setDefinition('Name', 'vascsuppress');

% background suppression (adiabatic inversion)
sw = 3; % kHz
dur_ms = 3;
rfwav = genSech180(sw, dur_ms, sys.gradRasterTime*1e3); 
rfamp = 0.15;  % Gauss
%rfwav = geninv(rfamp, 672, 5, 10e-3);  % also works (observed inversion efficiency about -0.9)
rf = mr.makeArbitraryRf(rfwav, pi/2, 'delay', sys.rfDeadTime, 'system', sys, 'use', 'excitation');
rf.signal = rf.signal/max(abs(rf.signal)) * rfamp * 1e-4 * sys.gamma;   % Hz
sections.inv = mr.Sequence(sys);           
sections.inv.addBlock(rf, mr.makeLabel('SET', 'TRID', TRIDs(end)));
gspoil = mr.makeTrapezoid('z', 'Area', 4*64/24e-2, 'Duration', 2e-3, 'system', sys);
sections.inv.addBlock(gspoil);
TRIDs(end) = [];
					  
% stack of spirals readout
readout.fov = [240e-3 240e-3 150e-3];   % FOV (m)
readout.nx = 64; readout.nz = 30; readout.nleaf = 1;
FLIP = 10*ones(readout.nz*readout.nleaf,1);  % constant flip angle
[sections.acquire, readout.kx, readout.ky] = getSoSreadout(sys, readout.fov, readout.nx, ...
    readout.nz, readout.nleaf, TRIDs(end), FLIP);
TRIDs(end) = [];

