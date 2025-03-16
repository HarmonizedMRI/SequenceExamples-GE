function s = ir(t1, ie, m0, ti)
% function s = ir(t1, ie, m0, ti)
%
% IR signal
%
% t1  [1]    T1
% ie  [1]    inversion efficiency, normalized units [-1 1]
% m0  [1]    spin density/overall scaling, a.u.
% ti  [n]    inversion time(s)

s = m0 * (ie + (1-ie)*(1-exp(-ti./t1)));
