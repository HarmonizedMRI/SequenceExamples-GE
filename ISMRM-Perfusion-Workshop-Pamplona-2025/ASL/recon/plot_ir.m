
sl = nz/2+1;
imsos2d = imsos(:,:,sl,:);
load roi  % roi = roipoly
load ../sequence/TI.mat
irfit(imsos2d, TI, roi, true);
