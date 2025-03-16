function TRIDs = writeASL(sys, sections, fn, TRIDs)
% Write velocity-selective stack-of-spirals ASL sequence (asl.seq)
%
% Sequence is:
%
%  <sat/reset> - delay - <label> - delay - <inversion> - delay - <inversion> - <readout>

endOfSegmentGap = 116e-6;  % gap inserted by interpreter after each segment

nFrames = 1;   % number of time frames (tag-control pairs)

seq = mr.Sequence(sys);           

% The gradient heating check done by the pge2 interpreter requires
% that each segment contains at least one gradient event.
% So create a zero-amplitude gradient for this purpose.
gdummy = mr.makeTrapezoid('x', 'Area', 0.01*64/24e-2, 'Duration', 0.1e-3, 'system', sys);
gdummy = mr.scaleGrad(gdummy, eps);  % don't scale to exactly 0 so the trapezoid shape is preserved in the .seq file

% High-level sequence timing
delays.reset = 2;      % delay after 90 sat pulse (s)
delays.pld = 1.3;      % post label delay: time from end of label to start of data acquisition
delays.delta1 = 1.07;   % delay between label and 1st inversion (BGS) pulse
delays.delta2 = 0.12;   % delay between 1st and 2nd inversion pulse

delays.delta3 = delays.pld - delays.delta1 - sections.inv.duration - delays.delta2 - sections.inv.duration ...
    - sections.vascsuppress.duration - endOfSegmentGap; 

fprintf('Creating ASL sequence... ');
for f = 1:nFrames
    for label = 1:2  % tag or control
        % reset pulse: saturate and wait, to put spins in a consistent starting state
        seqappend(seq, sections.sat);
        seq.addBlock(gdummy, mr.makeDelay(delays.reset - sections.sat.duration - endOfSegmentGap)); 
        
        % ASL label
        switch label
            case 1
                seqappend(seq, sections.tag);
            case 2
                seqappend(seq, sections.control);
        end
        seq.addBlock(sections.gdummy, mr.makeDelay(delays.delta1 - endOfSegmentGap)); 

        % background suppression
        seqappend(seq, sections.inv);
        seq.addBlock(sections.gdummy, mr.makeDelay(delays.delta2 - sections.inv.duration - endOfSegmentGap)); 
        seqappend(seq, sections.inv);
        seq.addBlock(sections.gdummy, mr.makeDelay(delays.delta3));

        % vascular crusher
        seqappend(seq, sections.vascsuppress);

        % fast SPGR stack of spirals readout
        seqappend(seq, sections.acquire);
    end
end
fprintf('done\n');

seq.setDefinition('FOV', sections.acquire.getDefinition('FOV'));
seq.setDefinition('Name', 'asl');

% Check sequence timing
checktiming(seq);

% Write to Pulseq file
seq.write([fn '.seq']);

