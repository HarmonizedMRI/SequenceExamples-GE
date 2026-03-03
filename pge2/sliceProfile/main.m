% Create and inspect/validate the sequence files,
% and reconstruct the data

% actions
createSequenceFile = 1;
reconstruct =        0;

fn = 'sliceprofile';       % Pulseq file name (without the .seq extension)

if createSequenceFile

    %---------------------------------------------------------------
    % Write the .seq file
    %---------------------------------------------------------------
    writeSliceProfile;

    %---------------------------------------------------------------
    % Convert .seq file to a PulSeg sequence (psq) object
    %---------------------------------------------------------------
    psq = pulseg.fromSeq([fn '.seq']);   % ,'usesRotationEvents', false);

    %---------------------------------------------------------------
    % Define hardware parameters for your scanner
    %---------------------------------------------------------------
    psd_rf_wait  = 100e-6;   % RF–gradient delay (s), scanner-specific
    psd_grd_wait = 100e-6;   % ADC–gradient delay (s), scanner-specific
    b1_max   = 0.25;         % Gauss
    g_max    = 5;            % Gauss/cm
    slew_max = 20;           % Gauss/cm/ms
    coil     = 'xrm';        % See pge2.opts(). 'xrm' (MR750), 'hrmw' (Premier), 'magnus', ...

    sysGE = pge2.opts(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, coil);

    %---------------------------------------------------------------
    % Check PNS, timing, and b1/gradient limits
    % (gradient heating, SAR, and other RF checks are evaluated by the
    % interpreter at scan time.)
    %---------------------------------------------------------------
    PNSwt = 0*[1 1 1];   % directional PNS weights, see pge2.pns()
    params = pge2.check(psq, sysGE, 'PNSwt', PNSwt);

    %---------------------------------------------------------------
    % Plot the psq sequence (optional)
    %---------------------------------------------------------------
    %S = pge2.plot(psq, sysGE, 'blockRange', [1 2], 'rotate', false, 'interpolate', false);
    %S = pge2.plot(psq, sysGE, 'timeRange',  [0 0.02], 'rotate', true);

    %-----------------------------------------------------------------------
    % Validate psq representation against the original .seq file (optional)
    %-----------------------------------------------------------------------
    seq = mr.Sequence();
    seq.read([fn '.seq']);

    % Cycle through all segment instances and stop on first mismatch
    %pge2.validate(psq, sysGE, seq, [], 'row', [], 'plot', false);

    % Plot each segment instance before proceeding
    %pge2.validate(psq, sysGE, seq, [], 'row', [], 'plot', true);

    % Check only segments beginning at/after block 1000
    %pge2.validate(psq, sysGE, seq, [], 'row', 1000, 'plot', true);

    %---------------------------------------------------------------
    % Apply slice offset and write PulSeg object to .pge file.
    % x/y/zloc are obtained from the User CVs menu on the console.
    % pislquant = # of ADC events used to set Rx gains in Auto Prescan
    %---------------------------------------------------------------
    %xloc = 0;
    %yloc = 0;
    %zloc = 0;   % m
    %psq = pge2.translateFOVrf(psq, [0 0 0]);
    pge2.serialize(psq, [fn '.pge'], 'pislquant', 10, 'params', params, 'checkHash', false);

    %---------------------------------------------------------------
    % Validate the GE simulator XML output (created by WTools/Pulse View)
    % against the original .seq file.  For MR30.2 and later.
    %---------------------------------------------------------------
    %xmlPath = '~/transfer/xml/';   % directory for Pulse View .xml files
    %pge2.validate(psq, sysGE, seq, xmlPath, 'row', [], 'plot', true);
end

if reconstruct

    %% Load and display 2D GRE scan (both echoes)

    % Recall that the two echoes are interleaved

    archive = GERecon('Archive.Load', 'data.h5');

    % read first phase-encode of first echo
    currentControl = GERecon('Archive.Next', archive);
    [nx1 nc] = size(currentControl.Data);
    ny1 = 32;
    d1 = zeros(nx1, nc, ny1);
    d1(:,:,1) = currentControl.Data;

    % read the remaining echoes
    for iy = 2:ny1
        currentControl = GERecon('Archive.Next', archive);
        d1(:,:,iy) = currentControl.Data;
    end

    %d1 = d1(:,:,end-31:end);

    % do inverse fft and display
    d1 = permute(d1, [1 3 2]);   % [nx1 nx1 nc]

    [~, im1] = ift3(d1, 'type', '2d');

    % flip dimensions to match image displayed on console for matching 2D SPGR sequence
    im1 = flipdim(im1, 2);

    im(im1); title('echo 1 (192x192, dwell = 20us)');

end

