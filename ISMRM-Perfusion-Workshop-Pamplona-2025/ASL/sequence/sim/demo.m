phi = pi;    % rad. Determines area of unbalanced gradient, for imaging 'velocity' profile in a stationary phantom
fov = 20;   % cm
[b1, g] = genVSI(phi, fov);

dt = 4e-3;             % raster time [ms]
vel_target = 0;        % cm/s
off_resonance = 0;     % Hz
B1scale = 1.0;         % b1 scaling (inhomogeneity) factor
batch_mode = 0;
pos0 = 6;              % spin starting position [cm]
simVSI(b1, g, dt, vel_target, off_resonance, B1scale, batch_mode, pos0);
