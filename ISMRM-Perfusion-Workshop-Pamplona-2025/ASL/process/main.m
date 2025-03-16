% get textprogressbar.m
system('git clone --branch v2.4.0-alpha git@github.com:HarmonizedMRI/PulCeq.git');
addpath PulCeq/matlab

% load reconstructed images
load ../data/ims
ims = imsos; clear imsos;

% smooth (in-plane)
nt = size(ims, 4);  % nt = 2*opnex = 2x number of control-tag pairs
textprogressbar('smoothing: ');
for t = 1:nt
    textprogressbar(t/nt*100);
    ims(:,:,:,t) = smooth3(ims(:,:,:,t), 'gaussian', [7 7 1], 1);
end
textprogressbar('');

% detrend the data to remove drift in timeseries
nx = size(ims,1);
nz = size(ims,3);

ims = reshape(ims, [], nt);
textprogressbar('detrending: ');
for p =1:size(ims,1)
    textprogressbar(p/size(ims,1)*100);
    s0 = mean(ims(p,:));
    ims(p,:) = detrend(ims(p,:), 3) + s0;
end
textprogressbar('');
ims = reshape(ims,[nx, nx, nz , nt]);

ctl = ims(:,:,:,3:2:end);
lbl = ims(:,:,:,4:2:end);

% clean up the noise by removing outliers
ctl = reshape(ctl, [],nt/2-1);
lbl = reshape(lbl, [],nt/2-1);
textprogressbar('removing outliers: ');
for p =1:size(ctl,1)
    textprogressbar(p/size(ctl,1)*100);
    tmp = ctl(p,:);
    s0 = mean(tmp);
    sd = std(tmp);
    inds = find(tmp >  s0 + 1.5*sd);

    ctl(p,inds) = s0;

    tmp = lbl(p,:);
    s0 = mean(tmp);
    sd = std(tmp);
    inds = find(tmp >  s0 + 1.5*sd);

    lbl(p,inds) = s0;
end
textprogressbar('');

% plot mean perfusion-weighted image
ctl = reshape(ctl,[nx, nx, nz, nt/2-1]);
lbl = reshape(lbl,[nx, nx, nz, nt/2-1]);

sub = abs(ctl) - abs(lbl);

mc = mean(ctl,4);
ml = mean(lbl,4);

ms = mean(sub,4);
sd = std(sub,[], 4);
snrmap = ms ./sd;

z1 = 7; z2 = 26;  % slices to include in plot
s = max(ctl(:));
figure;
im(mean(mc(:,:,z1:z2,:)/s, 4)); colorbar;
title('control, mean magnitude image across frames');
figure;
im(mean(sub(:,:,z1:z2,:)/s, 4), 2e-2*[0 1]); colorbar;
title('Perfusion-weighted images (fraction of M0)');

return


orthoview(mc)
colorbar
title('mean control image')

subplot(312)
orthoview(ms)
colorbar
caxis([0 1]* 800)
title('mean subtraction')

subplot(313)
orthoview(snrmap)
colorbar
colorbar
title('CNR')
colormap parula

figure

lbview(ms)
colorbar
caxis([0 1]* 800)
title('mean subtraction')
colormap parula

% plot mean label-control (perfusion weighted) image
lbl = ims(:,:,:,3:2:end);
ctrl = ims(:,:,:,4:2:end);
s = max(abs(ctrl(:)));
figure;
im(mean(lbl,4)); colorbar;
title('label, mean magnitude image across frames');
figure;
im(mean(abs(lbl-ctrl),4), 2e-2*s*[0 1]); colorbar;
title('mean(abs(label-control))');
