function [im1, im2] = recon_gre2d(sa_file, pislquant)

% Load and display 2D GRE scan (both echoes)

% Recall that the two echoes are interleaved

% if runninging from bash script, arguments are strings
if ~isnumeric(pislquant)
    pislquant = str2num(pislquant);
end

archive = GERecon('Archive.Load', sa_file);

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

% flip dimensions to match image displayed on console for matching 2D SPGR sequence
im1 = flipdim(im1, 2);
im2 = flipdim(im2, 2);
im2 = flipdim(im2, 1);

subplot(121); im(im1); title('echo 1 (192x192, dwell = 20us)');
subplot(122); im(im2); title('echo 2 (48x192, dwell = 40us)');


