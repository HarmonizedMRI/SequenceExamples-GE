function [gsp, dur] = getspiral(nleaf, gts, fov, n)

% make balanced spiral readout
%fov = 24;   % cm
%n = 64;
Router = 1;
fovvd = fov/nleaf;
xresvd = n/nleaf;

mxg = 2.6;  % G/cm
mxslew = 45;  % T/m/s
mxg = 3.0;  % G/cm
mxslew = 130;  % T/m/s

nDensSamp = 200;
g = genspiralvd(fovvd, xresvd, Router, mxg, mxslew, nDensSamp, gts);
dur = gts*length(g);  % sec
%plot(cumsum(g));
gx = makebalanced(real(g(:)), 'maxSlew', 0.5*mxslew/10);
gy = makebalanced(imag(g(:)), 'maxSlew', 0.5*mxslew/10);
n = max(length(gx), length(gy));
gx = [gx; zeros(n-length(gx), 1)];
gy = [gy; zeros(n-length(gy), 1)];
gsp = gx + 1i*gy;
