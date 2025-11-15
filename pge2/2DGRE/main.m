% actions
createSequenceFile = true;
reconstruct = false;

fn = 'gre2d';       % Pulseq file name (without the .seq extension)

pislquant = 10;     % number of shots/ADC events used for receive gain calibration

if createSequenceFile

    % Write the .seq file
    write2DGRE;

    % Convert .seq file to a Ceq object
    ceq = seq2ceq([fn '.seq']);   %, 'usesRotationEvents', false);

    % Check to see if the ceq object is compatible with your scanner,
    % with respect to PNS, low-level timing, and b1/gradient limits.
    % Other checks such as gradient heating and RF checks (SAR and hardware) 
    % are done by the interpreter at scan time.
    psd_rf_wait = 100e-6;   % RF-gradient delay, scanner specific (s)
    psd_grd_wait = 100e-6;  % ADC-gradient delay, scanner specific (s)
    b1_max = 0.25;          % Gauss
    g_max = 5;              % Gauss/cm
    slew_max = 20;          % Gauss/cm/ms
    coil = 'xrm';           % 'hrmbuhp' (UHP); 'xrm' (MR750); ...
    sysGE = pge2.opts(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, coil);
    pge2.check(ceq, sysGE);   % Checks PNS, low-level timing, and b1/gradient limits

    % Write ceq object to file.
    % pislquant is the number of ADC events used to set Rx gains in Auto Prescan
    writeceq(ceq, [ fn '.pge'], 'pislquant', pislquant);

    %% The .pge file just created is probably playable on your scanner,
    %% but the following examples illustrate additional checks 
    %% that are highly recommended.

    % Visually inspect the ceq sequence
    S = pge2.plot(ceq, sysGE, 'blockRange', [1 2], 'rotate', false, 'interpolate', false); 
    S = pge2.plot(ceq, sysGE, 'timeRange', [0 0.02], 'rotate', true);

    % Check accuracy of the ceq sequence representation against the original .seq file
    seq = mr.Sequence();
    seq.read([fn '.seq']);
    pge2.validate(ceq, sysGE, seq, [], 'row', [], 'plot', false);  % cycle through all segment instance and stop if a mismatch is found
    pge2.validate(ceq, sysGE, seq, [], 'row', [], 'plot', true);  % plot each segment instance before checking the next
    pge2.validate(ceq, sysGE, seq, [], 'row', 1000, 'plot', true);  % check the segment instance at/after block 1000

    % Check accuracy of the WTools/VM output against the original .seq file.
    xmlPath = '~/transfer/xml/';  % the same files used by GE's Pulse View sequence plotter
    pge2.validate(ceq, sysGE, seq, xmlPath, 'row', [], 'plot', true);

    % Coming soon: Check mechanical resonsances (forbidden frequency bands)
    % S = pge2.plot(ceq, sysGE, 'blockRange', [1 10], 'rotate', true, 'interpolate', true);
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

