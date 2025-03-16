function seq = seqappend(seq, seq2)
% function seqappend(seq, seq2)
%
% This function modifies the input sequence 'seq' by appending
% the blocks in seq2 to it.
%
% Inputs
%  seq    Pulseq sequence object handle, passed by reference (this function modifies it)
%  seq2   Pulseq sequence object (handle) to append to seq
%
% Outputs
%  none -- the input sequence is modified in place

for n = 1:length(seq2.blockEvents)
    b = seq2.getBlock(n);
    seq.addBlock(b);
%    seq.addBlock(mr.makeDelay(b.blockDuration), b.rf, b.gx, b.gy, b.gz, b.adc, b.label);
end
