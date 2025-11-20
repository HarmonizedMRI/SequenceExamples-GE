% Create and inspect/validate the sequence files,
% and reconstruct the data

% actions
createSequenceFile = true;
reconstruct = false;

fn = 'gre2d';       % Pulseq file name (without the .seq extension)

pislquant = 10;     % number of shots/ADC events used for receive gain calibration

if createSequenceFile

    %---------------------------------------------------------------
    % Write the .seq file
    %---------------------------------------------------------------
    write2DGRE;

    %---------------------------------------------------------------
    % Convert .seq file to a Ceq object
    %---------------------------------------------------------------
    ceq = seq2ceq([fn '.seq']);   % ,'usesRotationEvents', false);

    %---------------------------------------------------------------
    % Define hardware parameters for your scanner
    %---------------------------------------------------------------
    psd_rf_wait  = 100e-6;   % RF–gradient delay (s), scanner-specific
    psd_grd_wait = 100e-6;   % ADC–gradient delay (s), scanner-specific
    b1_max   = 0.25;         % Gauss
    g_max    = 5;            % Gauss/cm
    slew_max = 20;           % Gauss/cm/ms
    coil     = 'xrm';        % 'hrmbuhp' (UHP), 'xrm' (MR750), ...

    sysGE = pge2.opts(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, coil);

    %---------------------------------------------------------------
    % Check PNS, timing, and b1/gradient limits
    % (gradient heating, SAR, and other RF checks are evaluated by the
    % interpreter at scan time.)
    %---------------------------------------------------------------
    params = pge2.check(ceq, sysGE);

    %---------------------------------------------------------------
    % Plot the ceq sequence
    %---------------------------------------------------------------
    S = pge2.plot(ceq, sysGE, 'blockRange', [1 2], 'rotate', false, 'interpolate', false);
    S = pge2.plot(ceq, sysGE, 'timeRange',  [0 0.02], 'rotate', true);

    %---------------------------------------------------------------
    % Validate ceq representation against the original .seq file
    %---------------------------------------------------------------
    seq = mr.Sequence();
    seq.read([fn '.seq']);

    % Cycle through all segment instances and stop on first mismatch
    pge2.validate(ceq, sysGE, seq, [], 'row', [], 'plot', false);

    % Plot each segment instance before proceeding
    pge2.validate(ceq, sysGE, seq, [], 'row', [], 'plot', true);

    % Check only segments beginning at/after block 1000
    pge2.validate(ceq, sysGE, seq, [], 'row', 1000, 'plot', true);

    %---------------------------------------------------------------
    % Write Ceq object to .pge file
    % pislquant = # of ADC events used to set Rx gains in Auto Prescan
    %---------------------------------------------------------------
    pge2.writeceq(ceq, [fn '.pge'], 'pislquant', pislquant, 'params', params);

    %---------------------------------------------------------------
    % Validate the GE simulator XML output (created by WTools/Pulse View)
    % against the original .seq file.  For MR30.2 and later.
    %---------------------------------------------------------------
    xmlPath = '~/transfer/xml/';   % directory for Pulse View .xml files

    pge2.validate(ceq, sysGE, seq, xmlPath, 'row', [], 'plot', true);

    % Coming soon: Check mechanical resonances (forbidden frequency bands)
end

if reconstruct

    %% Load and display 2D GRE scan (both echoes)

    % Recall that the two echoes are interleaved

    archive = GERecon('Archive.Load', 'data.h5');

    % skip past receive gain calibration TRs (pislquant)
    for n = 1:pislquant
        currentControl = GERecon('Archive.Next', archive);
    end

    % read first phase-encode of first echo
    currentControl = GERecon('Archive.Next', archive);
    [nx1 nc] = size(currentControl.Data);
    ny1 = nx1;
    d1 = zeros(nx1, nc, ny1);
    d1(:,:,1) = currentControl.Data;

    % read first phase-encode of second echo
    currentControl = GERecon('Archive.Next', archive);
    [nx2 nc] = size(currentControl.Data);
    d2 = zeros(nx2, nc, ny1);

    % read the remaining echoes
    for iy = 2:ny1
        currentControl = GERecon('Archive.Next', archive);
        d1(:,:,iy) = currentControl.Data;
        currentControl = GERecon('Archive.Next', archive);
        d2(:,:,iy) = currentControl.Data;
    end

    % do inverse fft and display
    d1 = permute(d1, [1 3 2]);   % [nx1 nx1 nc]
    d2 = permute(d2(:, :, end/2-nx2:end/2+nx2-1), [1 3 2]);   % [nx2 nx2 nc]

    [~, im1] = ift3(d1, 'type', '2d');
    [~, im2] = ift3(d2, 'type', '2d');

    subplot(121); im(im1); title('echo 1 (192x192, dwell = 20us)');
    subplot(122); im(im2); title('echo 2 (48x192, dwell = 40us)');

end

