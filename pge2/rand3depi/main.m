%% Main script for generating randomzied 3D EPI sequences for fMRI

%% EPI calibration scan, for tuning receiver gains and odd/even correction
run('EPIcal.m');

%% Randomzied 3D-EPI scan
run('randEPI.m');

%% Low-res GRE scan for sensitivity map estimation
run('GRE.m');