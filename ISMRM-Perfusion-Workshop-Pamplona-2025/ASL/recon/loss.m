function l = loss(x, s, TI)
%
% x    [t1 ie m0]   fit parameters, see ir.m
% s    [nt]         observed signal
% TI   [nt]         inversion times (same unit as t1)

t1 = x(1);
ie = x(2);
m0 = x(3);
s_fit = abs(ir(t1, ie, m0, TI));
l = norm(s(:)-s_fit(:));

