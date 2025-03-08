function write_seq(varargin)
% Create the .seq file for a 3D TINY Golden Angle Spiral Projection Imaging
% sequence
%
% by David Frey (djfrey@umich.edu)
%
% Inputs:
% te_delay - extra delay for TE (s)
% tr_delay - extra delay for TR (s)
% fov - field of view (cm)
% dt - raster time (s)
% N - 3D matrix size
% nscl - number of scales (scaling of gradient to "zoom" out of image)
% nint - number of interleaves (2D in-plane rotations)
% nprj - number of projections (3D thru-plane rotations)
% gmax - max gradient amplitude (G/cm)
% smax - max slew rate (G/cm/s)
% plotseq - option to plot the sequence
%
% Outputs:
% spi3d.seq file - seq file for pulseq
% seq_args.mat - .mat file containing copy of input arguments
%

    % set default arguments
    arg.te_delay = 1e-3; % extra delay for TE (s)
    arg.tr_delay = 200e-3; % extra delay for TR (s)
    arg.fov = 20; % fov (cm)
    arg.dt = 4e-6; % raster time (s)
    arg.N = 128; % 3D matrix size
    arg.nscl = 1; % number of scales (scaling of gradient to "zoom" out of image)
    arg.nint = 1; % number of interleaves (2D in-plane rotations)
    arg.nprj = 16; % number of projections (3D thru-plane rotations)
    arg.gmax = 4; % max gradient amplitude (G/cm)
    arg.smax = 12000; % max slew rate (G/cm/s)
    arg.plotseq = true; % option to plot the sequence
    
    % parse arguments
    arg = vararg_pair(arg,varargin);
    
    % set system limits
    sys = mr.opts('MaxGrad', arg.gmax*10, 'GradUnit', 'mT/m', ...
        'MaxSlew', arg.smax*1e-2, 'SlewUnit', 'mT/m/ms', ...
        'rfDeadTime', 100e-6, ...
        'rfRingdownTime', 60e-6, ...
        'adcRasterTime', arg.dt, ...
        'gradRasterTime', arg.dt, ...
        'rfRasterTime', arg.dt, ...
        'blockDurationRaster', 4e-6, ...
        'B0', 3, ...
        'adcDeadTime', 0e-6);
    
    % initialize sequence object
    seq = mr.Sequence(sys);
    warning('OFF', 'mr:restoreShape');
    
    % Create 90 degree non-selective excitation pulse
    rf = mr.makeSincPulse(pi/2, ...
        'system', sys, ...
        'Duration', 3e-3,...
        'use', 'excitation', ...
        'SliceThickness', Inf, ...
        'apodization', 0.5, ...
        'timeBwProduct', 4, ...
        'system',sys);
    
    % form initial 2D spiral gradients
    [~, g] = vds(arg.smax, ...
        arg.gmax, ...
        arg.dt, ...
        arg.nint, ...
        [arg.fov,0], ...
        arg.N/arg.fov/2);
    g_wav = sys.gamma * 1e-2 * g; % kHz/m
    acq_len = sys.adcSamplesDivisor*ceil(length(g_wav)/sys.adcSamplesDivisor);
    
    % append ramp and form 3D arrays
    nramp = ceil(arg.gmax / arg.smax / arg.dt);
    ramp_down = (1 - linspace(0,1,nramp));
    g_wav = [g_wav, g_wav(end)*ramp_down];
    G0 = [real(g_wav); imag(g_wav); zeros(1,length(g_wav))];
    
    % create ADC
    adc = mr.makeAdc(acq_len, ...
        'Duration', sys.adcRasterTime*acq_len, ...
        'Delay', arg.te_delay, ...
        'system', sys);
    
    % create spoiler
    gz_spoil = mr.makeTrapezoid('z', sys, ...
        'Area', arg.N/(arg.fov*1e-2)*4, ...
        'system', sys);
    
    % define sequence blocks
    for iscl = 1:arg.nscl
        for iprj = 1:arg.nprj
            for iint = 1:arg.nint
        
                % write the excitation to sequence
                seq.addBlock(rf, mr.makeLabel('SET', 'TRID', 1));
        
                % rotate the gradients based on a 3DTGA rotation sequence
                R = rot_3dtga(iprj, iint);
                scl = 1 - (iscl - 1)/arg.nscl;
                iG = scl * R * G0;
        
                % write gradients to sequence
                gx_sp = mr.makeArbitraryGrad('x', 0.99*iG(1,:), ...
                    'Delay', arg.te_delay, 'system', sys, 'first', 0, 'last', 0);
                gy_sp=mr.makeArbitraryGrad('y', 0.99*iG(2,:), ...
                    'Delay', arg.te_delay, 'system', sys, 'first', 0, 'last', 0);
                gz_sp=mr.makeArbitraryGrad('z', 0.99*iG(3,:), ...
                    'Delay', arg.te_delay, 'system', sys, 'first', 0, 'last', 0);
                seq.addBlock(gx_sp, gy_sp, gz_sp, adc);
        
                % add spoiler and delay
                seq.addBlock(gz_spoil, mr.makeDelay(arg.tr_delay));
        
            end
        end
    end
    
    % check whether the timing of the sequence is correct
    [ok, error_report] = seq.checkTiming;
    if (ok)
        fprintf('Timing check passed successfully\n');
    else
        fprintf('Timing check failed! Error listing follows:\n');
        fprintf([error_report{:}]);
        fprintf('\n');
    end
    
    % write out sequence and save args
    seq.setDefinition('FOV', arg.fov*1e-2*ones(1,3));
    seq.setDefinition('Name', 'spi3d');
    seq.write('spi3d.seq');
    save seq_args.mat -struct arg
    
    % the sequence is ready, so let's see what we got
    if arg.plotseq
        figure
        seq.plot();
    end

end