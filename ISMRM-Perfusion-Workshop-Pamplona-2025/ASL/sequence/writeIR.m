function TRIDs = writeIR(sys, sections, fn, TRIDs)
% Write multiple TI inversion-recovery stack-of-spirals sequence (ir.seq)
% for measuring T1 and checking the inversion pulse

seq = mr.Sequence(sys);           

% Inversion times
TImin = 50e-3;     % sec
TImax = 2;
nTI = 10;
TI = logspace(log10(TImin), log10(TImax), nTI);
TI = ceil(TI/sys.blockDurationRaster)*sys.blockDurationRaster;
save TI TI

% Create sequence
trid_recover = TRIDs(end);  TRIDs(end) = [];

textprogressbar('Creating IR sequence: ');
for n = 1:length(TI)
    textprogressbar(n/length(TI)*100);

    % inversion pulse
    seqappend(seq, sections.inv);

    % delay. Subtract spoiler duration.
    seq.addBlock(mr.makeDelay(TI(n) - sections.inv.getBlock(2).blockDuration));

    % fast SPGR stack of spirals readout
    seqappend(seq, sections.acquire);

    % Allow time for full recovery.
    % Needs its own TRID label (segment) since sections.acquire loops over spiral segment.
    % Also needs a dummy gradient since each segment needs at last one gradient
    % to make the gradient heating check happy (on the interpreter side).
    seq.addBlock(sections.gdummy, mr.makeDelay(5), mr.makeLabel('SET', 'TRID', trid_recover)); 
end
textprogressbar('');

seq.setDefinition('FOV', sections.acquire.getDefinition('FOV'));
seq.setDefinition('Name', 'ir');

% Check sequence timing
checktiming(seq);

% Write to Pulseq file
seq.write([fn '.seq']);
