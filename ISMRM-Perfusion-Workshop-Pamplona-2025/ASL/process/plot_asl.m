lbl = imsos(:,:,:,3:2:end);
ctrl = imsos(:,:,:,4:2:end);
s = max(abs(ctrl(:)));
figure;
im(mean(lbl,4)); colorbar;
title('label, mean magnitude image across frames');
figure;
im(mean(abs(lbl-ctrl),4), 2e-2*s*[0 1]); colorbar;
title('mean(abs(label-control))');
