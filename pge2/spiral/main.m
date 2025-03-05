% actions
createSequenceFile = 1;
reconstruct = 0;

if createSequenceFile
    % write spiral.seq
    system('git clone --branch v1.5.0 git@github.com:pulseq/pulseq.git');
    addpath pulseq/matlab
    system('git clone --branch v1.9.1 git@github.com:toppeMRI/toppe.git');
    addpath toppe
    writeIntSpiralFW;   

    % convert to spiral.pge
    %system('git clone --branch v2.2.3 git@github.com:HarmonizedMRI/PulCeq.git');
    system('git clone --branch tv7 git@github.com:fmrifrey/PulCeq.git');
    addpath PulCeq/matlab
    ceq = seq2ceq('spiral.seq');
    pislquant = 1;   % number of ADC events used for receive gain calibration
    writeceq(ceq, 'spiral.pge', 'pislquant', pislquant);
end

if reconstruct
    addpath ~/Programs/orchestra-sdk-2.1-1.matlab/
    PinvRecon_IntSpiral;

    % or:
    % recon_nufft;
end

