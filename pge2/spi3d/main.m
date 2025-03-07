% actions
createSequenceFile = 1;
reconstruct = 0;

if createSequenceFile
    % write spiral.seq
    system('git clone --branch v1.5.0 git@github.com:pulseq/pulseq.git');
    addpath pulseq/matlab
    writeIntSpiralFW;   

    % convert to spiral.pge
    %system('git clone --branch v2.2.2 git@github.com:HarmonizedMRI/PulCeq.git');
    system('git clone --branch tv7 git@github.com:fmrifrey/PulCeq.git');
    addpath PulCeq/matlab
    ceq = seq2ceq('spi3d.seq');
    pislquant = 1;   % number of ADC events used for receive gain calibration
    writeceq(ceq, 'spi3d.pge', 'pislquant', pislquant);
end

if reconstruct
    addpath ~/code/packages/orchestra-sdk-2.1-1.matlab/
    PinvRecon_IntSpiral;

    % or:
    % recon_nufft;
end

