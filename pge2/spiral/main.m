% actions
createSequenceFile = true;
reconstruct = false;

version = 'pge2';   % 'tv6' or 'pge2'

if createSequenceFile
    % write spiral.seq
    system('git clone git@github.com:pulseq/pulseq.git');
    addpath pulseq/matlab
    writeIntSpiralFW;   

    % convert to spiral.tar (tv6) or spiral.pge (pge2)

    if strcmp(version, 'tv6')
        system('git clone --branch v1.10.6 git@github.com:HarmonizedMRI/PulCeq.git');
        addpath PulCeq/matlab

        sysGE = toppe.systemspecs('maxGrad', sys.maxGrad/sys.gamma*100, ...   % G/cm
            'maxSlew', sys.maxSlew/sys.gamma/10, ...                          % G/cm/ms
            'maxRF', 0.15, ...                   % recommend to keep this <= 0.15 G for accurate b1 scaling
            'rfDeadTime', 0, ...                 % us
            'rfRingdownTime', 0, ...             % us
            'adcDeadTime', 0);                   % us

        seq2ge('spiral.seq', sysGE, 'spiral.tar');
    end

    if strcmp(version, 'pge2')
        system('git clone --branch v2.1.2 git@github.com:HarmonizedMRI/PulCeq.git');
        addpath PulCeq/matlab
        ceq = seq2ceq('spiral.seq');
        pislquant = 1;   % number of ADC events used for receive gain calibration
        writeceq(ceq, 'spiral.pge', 'pislquant', pislquant);
    end
end

if reconstruct
    addpath ~/Programs/orchestra-sdk-2.1-1.matlab/

    archive = GERecon('Archive.Load', 'test.h5');

    % skip past receive gain calibration TRs (pislquant)
    for n = 1:pislquant
        currentControl = GERecon('Archive.Next', archive);
    end

    % read first phase-encode of first echo
    currentControl = GERecon('Archive.Next', archive);
    [nndat nc] = size(currentControl.Data);

    system('git clone --depth 1 git@github.com:JeffFessler/mirt.git');
    cd mirt; setup; cd ..;

    % im(im1); title('echo 1 (192x192, dwell = 20us)');
end

