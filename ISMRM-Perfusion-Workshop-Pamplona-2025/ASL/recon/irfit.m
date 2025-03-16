function [t1, inveff] = irfit(imsos, TI, roi, doplot)
% function [t1, inveff] = irfit(imsos, TI, roi, doplot)
%
% Fit inversion recovery curve to magnitude image.
% The ROI is applied to the center slice
%
% Inputs
%  imsos   [nx ny nt]     magnitude image series
%  TI      [nt]           inversion times
%  roi     [nx ny]        mask
%  doplot  true/false     plot?

if nargin < 4
    doplot = false;
end

% check inputs
assert(ndims(imsos) == 3, 'image must be 2d time-series');
assert(isvector(TI), 'TI must be a vector');
assert(ndims(roi) == 2, 'roi must be 2d');

[nx ny nt] = size(imsos);

assert(length(TI) == nt, 'length(TI) must equal size(imsos,3)');
assert(all(size(roi) == [nx ny]), 'roi size must equal image size');

% get mean signal from roi in center slice
s = zeros(nt,1);
for t = 1:nt
    tmp = imsos(:,:,t);
    s(t) = mean(tmp(roi));
end

% fit
fun = @(x)loss(x, s, TI);
x = fminsearch(fun, [1, -0.8, s(end)]);

t1 = x(1);
inveff = x(2);

% plot
if doplot
    subplot(211); im(squeeze(imsos));
    subplot(212); plot(TI, s, 'o');
    hold on;
    TIplot = 0:0.05:TI(end);
    s_fit = abs(ir(x(1), x(2), x(3), TIplot));
    plot(TIplot, s_fit);
    xlabel('TI (s)');
    ylabel('signal (a.u.)');
    title(sprintf('T1: %.2fs, inv. efficiency: %.2f', x(1), x(2)));
end
    
