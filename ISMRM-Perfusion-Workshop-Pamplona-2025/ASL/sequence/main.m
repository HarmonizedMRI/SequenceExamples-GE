% Write magnetization-prepared stack of spirals sequence for pge2 Pulseq interpreter

% the official Pulseq toolbox
system('git clone --branch v1.5.0 git@github.com:pulseq/pulseq.git');
addpath pulseq/matlab

% functions for converting a Pulseq file (.seq) to a format suitable for GE
system('git clone --branch v2.4.0-alpha git@github.com:HarmonizedMRI/PulCeq.git');
addpath PulCeq/matlab

% we also need a few helper functions from here (for now)
system('git clone --branch v1.9.1 git@github.com:toppeMRI/toppe.git');   
addpath toppe

% System/design parameters
%sys = mr.opts('maxGrad', 26, 'gradUnit','mT/m', ...
%              'maxSlew', 45, 'slewUnit', 'T/m/s', ...
sys = mr.opts('maxGrad', 40, 'gradUnit','mT/m', ...
              'maxSlew', 130, 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 100e-6, ...
              'rfRingdownTime', 60e-6, ...
              'adcDeadTime', 40e-6, ...
              'adcRasterTime', 10e-6, ...
              'gradRasterTime', 10e-6, ...
              'rfRasterTime', 10e-6, ...
              'blockDurationRaster', 10e-6, ...
              'B0', 3.0);

% It is important to properly assign TRID labels to various segments.
% Define a list of them here, then use one at a time and remove it as one goes.
TRIDs = 100:-1:1;   % any set of unique integers, in no particular order

% get sequence sections (ASL label, background suppression, readout, ...)
[sections, readout, TRIDs] = getsections(sys, TRIDs);

% The interpreter inserts a gap after each segment.
% See https://github.com/HarmonizedMRI/SequenceExamples-GE/tree/main/pge2
endOfSegmentGap = 116e-6;   % sec

% write ir.seq and convert to ir.pge for execution on GE
fn = 'ir';
TRIDs = writeIR(sys, sections, fn, TRIDs);
ceq = seq2ceq([fn '.seq']);
pislquant = readout.nz;   % number of ADC events used for receive gain calibration
writeceq(ceq, [fn '.pge'], 'pislquant', pislquant);

% write vir.seq and convert to vir.pge for execution on GE
fn = 'vir';
TRIDs = writeVIR(sys, sections, fn, TRIDs);
ceq = seq2ceq([fn '.seq']);
pislquant = readout.nz;   % number of ADC events used for receive gain calibration
writeceq(ceq, [fn '.pge'], 'pislquant', pislquant);

% write asl.seq and convert to asl.pge for execution on GE
fn = 'asl';
TRIDs = writeASL(sys, sections, fn, TRIDs);
ceq = seq2ceq([fn '.seq']);
pislquant = readout.nz;   % number of ADC events used for receive gain calibration
writeceq(ceq, [fn '.pge'], 'pislquant', pislquant);

save readout readout
