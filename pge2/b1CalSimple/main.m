% actions
createSequenceFile = true;
reconstruct = false;

fn = 'flip';

if createSequenceFile
    % create .seq file
    system('git clone --branch v1.5.0 git@github.com:pulseq/pulseq.git');
    addpath pulseq/matlab
    %write2DGRE;   % writes .seq file, and sets pislquant
    writeflip;

    % Convert .seq file to a PulCeq (Ceq) object
    %system('git clone --branch v2.4.1 git@github.com:HarmonizedMRI/PulCeq.git');
    %system('git clone --branch tv7_dev git@github.com:HarmonizedMRI/PulCeq.git');
    %system('git checkout 6bbc858502711dd46a4e5f7f84fb3a21faa9c8b8');
    %addpath PulCeq/matlab
    addpath ~/github/HarmonizedMRI/PulCeq/matlab
    ceq = seq2ceq([fn '.seq']);

    % Check the ceq object:
    % Define hardware parameters, and
    % check if 'ceq' is compatible with the parameters in 'sys'
    psd_rf_wait = 58e-6;  % RF-gradient delay, scanner specific (s)
    psd_grd_wait = 60e-6; % ADC-gradient delay, scanner specific (s)
    b1_max = 0.25;         % Gauss
    g_max = 5;             % Gauss/cm
    slew_max = 20;         % Gauss/cm/ms
    gamma = 4.2576e3;      % Hz/Gauss
    sys = pge2.getsys(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, gamma);
    %pge2.validate(ceq, sys);

    pge2.plot(ceq, sys); %, 'timeRange', [1 1.2]);

    % Write ceq object to file.
    % pislquant is the number of ADC events used to set Rx gains in Auto Prescan
    writeceq(ceq, [ fn '.pge'], 'pislquant', 2);
end

if reconstruct
    system('git clone --depth 1 --branch v1.9.0 git@github.com:toppeMRI/toppe.git');
    addpath toppe

    addpath ~/Programs/orchestra-sdk-2.1-1.matlab/

    archive = GERecon('Archive.Load', 'data.h5');

    %% Load and display 2D GRE scan (both echoes)

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

    for iy = 2:ny1
        currentControl = GERecon('Archive.Next', archive);
        d1(:,:,iy) = currentControl.Data;
        currentControl = GERecon('Archive.Next', archive);
        d2(:,:,iy) = currentControl.Data;
    end

    d1 = permute(d1, [1 3 2]);   % [nx1 nx1 nc]
    d2 = permute(d2(:, :, end/2-nx2:end/2+nx2-1), [1 3 2]);   % [nx2 nx2 nc]

    [~, im1] = toppe.utils.ift3(d1, 'type', '2d');
    [~, im2] = toppe.utils.ift3(d2, 'type', '2d');

    system('git clone --depth 1 git@github.com:JeffFessler/mirt.git');
    cd mirt; setup; cd ..;

    subplot(121); im(im1); title('echo 1 (192x192, dwell = 20us)');
    subplot(122); im(im2); title('echo 2 (48x192, dwell = 40us)');

    %% Load and display flip angle calibration scan
    FLIP = 10:10:180;  % see write2DGRE.m
    d = zeros(nx1, nc, length(FLIP));
    for ii = 1:length(FLIP)
        currentControl = GERecon('Archive.Next', archive);
        d(:,:,ii) = currentControl.Data;
    end
    s = mean(abs(d),1);   % [1 nc 18]
    s = sqrt(sum(s.^2, 2));  % [1 1 18]
    s = squeeze(s);
end

