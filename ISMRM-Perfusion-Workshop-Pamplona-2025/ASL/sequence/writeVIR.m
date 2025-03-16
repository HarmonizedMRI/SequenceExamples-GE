function TRIDs = writeVIR(sys, sections, fn, TRIDs)
% Write vir.seq, a multiple TI velocity-selective inversion-recovery stack-of-spirals sequence.
% Can be used to measure the inversion efficiency.

seq = mr.Sequence(sys);           

% Inversion times
TImin = 50e-3;     % sec
TImax = 2;
nTI = 10;
TI = logspace(log10(TImin), log10(TImax), nTI);
TI = ceil(TI/sys.blockDurationRaster)*sys.blockDurationRaster;
save TI TI

% Create sequence
% 'Use up' one of the TRIDs
trid_recover = TRIDs(end);  TRIDs(end) = [];

textprogressbar('Creating VIR sequence: ');

for n = 1:length(TI)

    textprogressbar(n/length(TI)*100);

    for label = 1:3  % tag or control
        % VSI pulse
        switch label
            case 1
                seqappend(seq, sections.qatag);
            case 2
                seqappend(seq, sections.qacontrol);
            case 3
                seqappend(seq, sections.qaref);
        end

        % TI delay
        seq.addBlock(mr.makeDelay(TI(n)));

        % fast SPGR stack of spirals readout
        seqappend(seq, sections.acquire);

        % Allow time for full recovery.
        % Needs its own TRID (segment) label since sections.acquire loops over spiral segment.
        % Also needs a dummy gradient since each segment needs at last one gradient
        % to make the gradient heating check happy (on the interpreter side).
        seq.addBlock(sections.gdummy, mr.makeDelay(5), mr.makeLabel('SET', 'TRID', trid_recover)); 
        seq.addBlock(sections.gdummy);   % a segment needs more than one block
    end
end
textprogressbar('');

seq.setDefinition('FOV', sections.acquire.getDefinition('FOV'));
seq.setDefinition('Name', 'ir');

% Check sequence timing
checktiming(seq);

% Write to Pulseq file
seq.write([fn '.seq']);
