
clear tag ctrl

load ../sequence/TI.mat
load roi

[nx ny nz nt] = size(imsos);

tag.imsos2d = squeeze(imsos(:,:,nz/2+1,1:3:end));  
ctrl.imsos2d = squeeze(imsos(:,:,nz/2+1,2:3:end));  
velmimick.imsos2d = squeeze(imsos(:,:,nz/2+1,3:3:end));  

textprogressbar('Fitting IR curves: ');
clear t1 inveff
for x = 1:nx
    textprogressbar(x/nx*100);
    for y = 1:ny
        roi = false(nx,ny);
        roi(x,y) = true;
        [tag.t1(x,y), tag.inveff(x,y)] = irfit(tag.imsos2d, TI, roi, false);
        [ctrl.t1(x,y), ctrl.inveff(x,y)] = irfit(ctrl.imsos2d, TI, roi, false);
        [velmimick.t1(x,y), velmimick.inveff(x,y)] = irfit(velmimick.imsos2d, TI, roi, false);
    end
end
textprogressbar('');

im(cat(1, tag.inveff, ctrl.inveff, velmimick.inveff), [-1 1]); colormap turbo;

return

%% Plot phase
[nx ny nz nt nc] = size(ims);

% for each coil image, subtract phase from last TI image
for c = 1:nc
    for t = 1:nt
        ims(:,:,:,t,c) = ims(:,:,:,t,c) .* exp(-1i*angle(ims(:,:,:,nt,c)));
    end
end

% coil-combined image
imcc = sum(ims, 5);

% display magnitude and phase for first TI time
t = 1;   % frame (TI time)
z = 10;
figure; im(abs(imcc(:,:,z,t))); title('complex coil combined');
figure; im(abs(imsos(:,:,z,t))); title('root sum of squares coil combined');
figure; im(angle(imcc(:,:,z,t))); colormap hsv; title('phase');
%im(cat(1, imsos(:,:,:,(t-1)*2+1), imsos(:,:,:,(t-1)*2+2)));
