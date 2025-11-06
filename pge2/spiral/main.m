% actions
createSequenceFile = 1;
reconstruct = 0;

fn = 'spiral';

if createSequenceFile
    % write spiral.seq
    writeIntSpiralFW;   

    % convert to spiral.pge
    ceq = seq2ceq([fn '.seq']);

    % Check the ceq object:
    % Define hardware parameters, and
    % check if 'ceq' is compatible with the parameters in 'sys'
    psd_rf_wait = 58e-6;  % RF-gradient delay, scanner specific (s)
    psd_grd_wait = 60e-6; % ADC-gradient delay, scanner specific (s)
    b1_max = 0.25;         % Gauss
    g_max = 5;             % Gauss/cm
    slew_max = 20;         % Gauss/cm/ms
    coil = 'xrm';          % MR750. See pge2.getsys()
    sysGE = pge2.getsys(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, coil);

    % validate and extract some sequence parameters that we will pass to writeceq()
    pars = pge2.validate(ceq, sysGE);

    % Plot the beginning of the sequence
    S = pge2.plot(ceq, sysGE, 'timeRange', [0 0.05], 'rotate', true); 

    % Write ceq object to file
    pislquant = 1;   % number of ADC events used for receive gain calibration
    writeceq(ceq, [fn '.pge'], 'pislquant', pislquant);
end

if reconstruct
    addpath ~/Programs/orchestra-sdk-2.1-1.matlab/
    PinvRecon_IntSpiral;

    % or:
    % recon_nufft;
end

