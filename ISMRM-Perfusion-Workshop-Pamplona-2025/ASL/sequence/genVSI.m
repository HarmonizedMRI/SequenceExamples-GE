function [B1, Gz] = genVSI(phi, fov, dt)
% function [B1, Gz] = genVSI(phi, fov, dt)
%
% Create Pulseq sequence object containing velocity-selective inversion pulse.
% Simulate with simVSI.m
%
% An unbalanced gradient is inserted to simulation velocity-induced phase.
%
% Output raster time is 4us
%
% Inputs
%    phi      [1]     phase at fov/2 produced by unbalanced gradient during each VSI segment [rad]
%    fov      [1]     cm
%    dt       [1]     raster time for both rf and gradient [sec]
%
% Outputs
%    B1       [n]     RF waveform, complex [Gauss]
%    Gz       [n]     gradient waveform [Gauss/cm]
%
% Based on vel_sim_10.m, but insert unbalanced gradients to simulate velocity.

%% Build waveform elements

% raster time (for both rf and gradients)
% dt = 10e-3;     % ms
dt = dt*1e3;      % ms

refocus_scheme = 'MLEV'; % 'MLEV' % 'DR180'
base_pulse =  'sinc_mod'; %'han' %'sinc_mod'   % 'sinc'  % 'hard'; % sech, hard, BIR 

Nsegs = 9;

Gvs =   1.250*1e-4;  % T/cm
Gvs =   0.2*1.4*1e-4;  % T/cm   % 16900 and 17268
%Gvs =   3*1e-4;  % T/cm     % 12360

% experimental new pulse
%Gvs = 1.2 * 1e-4;
%Nsegs = 17;

gap = round(0.5/dt);% 16900 and 17268
pregap = round(0.2/dt);  % 17268 
ramp_len = 0.3/dt ;  % 16900
flat_len = 0.3/dt;  % 17268

% velocity-mimicking trapezoid
gap_fakevel = [linspace(0,1,20) ones(1,10) linspace(1,0,20)]';
gap_fakevel = [gap_fakevel; zeros(length(gap)-length(gap_fakevel), 1)];
gam = 4.2576e3;   % Hz/Gauss
%phi = 2*pi*gam*sum(gap_fakevel)*fov/2*dt*1e-3;
a = phi/(2*pi*gam*sum(gap_fakevel)*fov/2*4e-6)*1e-4 / 4; % divide by 4 since gap_fakevel is playedout 4 times
gap_fakevel = a*gap_fakevel ;  % T/cm

B1_area180 = 0.117e-4; % Tesla*ms

switch base_pulse
    case 'sinc'
        mySinc_dur = 3.6; % ms - 17268 pulse (9 x 0.4) 
        %mySinc_dur = 4; % ms
        
        mySinc_dur = round(mySinc_dur/dt/Nsegs) * Nsegs*dt; % ms
        mySinc = sinc(linspace(-1, 1,  mySinc_dur/dt))' ;
        mySinc = mySinc .* hanning(length(mySinc));  % 17268 pulse
        mySinc_area = (sum(mySinc) * dt);
        mySinc =  B1_area180 * mySinc / mySinc_area;
        B1pulse = mySinc;
        B1seg_len = round(mySinc_dur /dt/Nsegs);
        
    case 'sinc_mod'
        mySinc_dur = 1.44; % ms
        mySinc_dur = 3.6; % ms - 17268 pulse (9 x 0.4) 

        mySinc_dur = round(mySinc_dur/dt/Nsegs) * Nsegs*dt; % ms
        mySinc = sinc(linspace(-1, 1,  mySinc_dur/dt))' ;
        mySinc = mySinc .* hanning(length(mySinc));  % 17268 pulse
        mySinc_area = (sum(mySinc) * dt);
        mySinc =  B1_area180 * mySinc / mySinc_area;
        B1pulse = mySinc;
        B1seg_len = round(mySinc_dur /dt/Nsegs);
       
    case 'han'
        myHan_dur = 0.5; %ms  

        myHan_dur = round(myHan_dur/dt/Nsegs) * Nsegs*dt; % ms
        myHan = hanning(myHan_dur/dt)' ;
        myHan_area = (sum(myHan) * dt);
        myHan =  B1_area180 * myHan / myHan_area;
        B1pulse = myHan;
        B1seg_len = round(myHan_dur /dt/Nsegs);
             
    case 'BIR'
        myBIR_dur = 3; % ms
        myBIRpulse = genBIRpulse(0.2 , myBIR_dur)';
        myBIRpulse_area = (sum(myBIRpulse) * dt);
        myBIRpulse = 200e-7 *  myBIRpulse/max(abs(myBIRpulse)) ;
        B1pulse = myBIRpulse;
        B1seg_len = round(myBIR_dur/dt/Nsegs);
        
    case 'sech'
        mysech_dur = 3 ;
        mysech = genSech180(0.1, mysech_dur)';
        mysech_area = sum(mysech * dt);
        mysech =  B1_area180 * mysech / mysech_area;
        mysech = 130e-7 *  mysech/max(abs(mysech)) ;

        B1pulse = mysech;
        B1seg_len = round( mysech_dur /dt/Nsegs);
        
    case 'hard'
        hard180_dur = 1.44; % (ms) this makes it an even multiple of 4 us and 9 segments
        hard180_dur = 0.16 * 9 ; % (ms) in the paper
        
        hard180_dur = round(hard180_dur/Nsegs/dt) * Nsegs*dt;
        hard180 = ones(hard180_dur/dt);
        
        hard180_area = sum(hard180)*dt;
        hard180 = B1_area180* hard180 /hard180_area;
        B1pulse = hard180;        
        B1seg_len = round(hard180_dur /dt/Nsegs);
end

% refocuser pulse is 180 hard pulse for 0.8 ms
B1ref_dur = 0.8;   % ms
B1ref_dur = 1.0;   % ms   - 12360
B1ref_dur = 0.5;   % ms  - sinc_mod and han 
 
B1ref_len = B1ref_dur/dt;  % points
B1ref_max = (1/B1ref_dur)* 0.1175e-4; % Tesla ... amplitude of 1 ms hard 180
B1ref = B1ref_max * ones(B1ref_len,1) ; % * exp(i*pi/2);
B1ref_area = sum(abs(B1ref));

% make Refocuser 180 be a composite pulse (90x-180y-90x)
tmp90 = B1ref(1:round(end/2));  % Jia's version of the 17268 uses 
                         %  B1ref(1:(end/2-1))
% the whole composite pulse:                         
B1ref = [tmp90; B1ref*exp(i*pi/2); tmp90]; %  16900 and 17268

% Now shorten the pulses and make them taller
% B1ref = 2*B1ref(1:2:end);

B1ref_len = length(B1ref); 
B1ref_dur = B1ref_len * dt;

trap = [
    zeros(pregap,1);
    [0:ramp_len-1]'/(ramp_len-1);
    ones(flat_len,1);
    [ramp_len-1:-1:0]'/(ramp_len-1);
    %zeros(gap,1);  % to be replaced with gap_fakevel below JFN
    ]*Gvs;

trap_len = length(trap);

str = sprintf('Durations: B1seg= %0.2f  ms, B1ref=  %0.2f ms , Gtrap=%0.2f ms\n', ...
    B1seg_len*dt , B1ref_len*dt, trap_len*dt);

% another trapezoid for the crusher
trap2 = [
    zeros(pregap,1);
    [0:ramp_len-1]'/(ramp_len-1);
    ones(1/dt,1);
    [ramp_len-1:-1:0]'/(ramp_len-1);
    zeros(gap,1);
    ];

switch refocus_scheme
    case 'MLEV'
        % The MLEV-16 sequence
        mlev_phases =  repmat( [1 1 -1 -1  -1  1 1 -1 -1 -1  1 1  1  -1 -1  1], [1,4]);
        %mlev_phases =  repmat( [1 1 -1 -1  -1  1 1 -1 -1 -1  1 1  1  -1 -1  -1], [1,4]);  % trying something different?
        
    case 'DR180'
        % My scheme for refocusing the off-res.
        mlev_phases = repmat( exp(-i*pi/2)*[1 -1 -1 1], [1,16]);
end


%% Build full-length RF and gradient waveform

% create the B1 and Gz segments
Gz = [];
B1 = [];
%rf = zeros(B1seg_len, Nsegs);
%gz = zeros(B1seg_len, Nsegs);
for n=1:Nsegs-1
    B1seg = B1pulse(1 + B1seg_len*(n-1) : n*B1seg_len);
    
    if strcmp(base_pulse,'sinc_mod')
        B1seg(:) = mean(B1seg);
    end

    if strcmp(base_pulse,'han')
        B1seg(:) = mean(B1seg);
        B1seg = B1seg(:);
    end
        
    B1 = [B1 ;
        B1seg;
        zeros(length(trap) + length(gap_fakevel), 1);
        B1ref * mlev_phases(2*n-1);
        zeros(length(trap) + length(gap_fakevel), 1);
        zeros(length(trap) + length(gap_fakevel), 1);
        B1ref * mlev_phases(2*n) ;
        zeros(length(trap) + length(gap_fakevel), 1);
        ];

    Gz = [Gz;
        zeros(size(B1seg)) ;
        [trap; gap_fakevel];
        zeros(size(B1ref))
        [-trap; -gap_fakevel];
        [trap; -gap_fakevel];
        zeros(size(B1ref))
        [-trap; gap_fakevel];
        ];
    
end

Gz = [
    Gz;
    zeros(size(B1seg))
    ];

B1seg = B1pulse(1 + B1seg_len*(Nsegs-1) : Nsegs*B1seg_len);
B1seg = B1seg(:);
B1 = [
    B1;
    B1seg;
    ];
%
%put a crusher at the end
%{
Gz = [
        Gz;
        Gvs*trap2;
    ];

% allow for the crusher:
B1 = [B1; 
    zeros(size(trap2))
    ];
%}

B1 = B1*1e4;   % Gauss
Gz = Gz*1e4;   % Gauss/cm

