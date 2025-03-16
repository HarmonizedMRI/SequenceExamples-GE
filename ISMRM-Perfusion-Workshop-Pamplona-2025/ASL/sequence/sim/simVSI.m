function [Mzfinal, Mzfinal_ns] = simVSI(B1, Gz, dt, vel_target, off_resonance, B1fudge, batch_mode, pos0)
% function [Mzfinal, Mzfinal_ns] = simVSI(B1, Gz, dt, vel_target, off_resonance, B1fudge, [batch_mode = 0], [pos0 = 0 cm])
%
% Inputs
%    B1             [n]   RF waveform, complex [Gauss]
%    Gz             [n]   gradient waveform [Gauss/cm]
%    dt             [1]   simulation step size in milliseconds.
%    vel_target     [1]   cm/s
%    off_resonance  [1]   Hz
%    B1fudge        [1]   b1 scaling, [0 1]

B1 = B1*1e-4;   % Tesla
Gz = Gz*1e-4;   % Tesla/cm

if nargin < 7; batch_mode = 0; end;
if nargin < 8; pos0 = 0; end;

showEvolution = 0;
    
T1 = 1700;  %ms
T2 = 165;   %ms  from Qin paper
    
gambar = 42.576*2*pi; % rad/s/T

refocus_scheme = 'MLEV'; % 'MLEV' % 'DR180'
base_pulse =  'sinc_mod'; %'han' %'sinc_mod'   % 'sinc'  % 'hard'; % sech, hard, BIR 

% default movement parameters
accel = 0 ; % in cm/ms^2

Mzfinal = [];
Mzfinal_ns = [];

Nsegs = 9;

Gvs =   1.250*1e-4;  % T/cm
Gvs =   1.4*1e-4;  % T/cm   % 16900 and 17268
%Gvs =   3*1e-4;  % T/cm     % 12360

% experimental new pulse
%Gvs = 1.2 * 1e-4;
%Nsegs = 17;

gap = round(0.4/dt);
gap = round(0.2/dt); % (12360)
% gap = round(0.5/dt); %  17268
gap = round(0.5/dt);% 16900 and 17268

pregap = 0; % 16900
%pregap = round(0.05/dt); % 16900
pregap = round(0.2/dt); % 12360
pregap = round(0.2/dt);  % 17268 


ramp_len = 0.3/dt ;  % 16900

flat_len = 0.4/dt;   % 16900 
flat_len = 0.3/dt;  % 17268
%flat_len = 0;        % 12360 

B1_area180 = 0.117e-4; % Tesla*ms


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% linear phase to shift the target velocity

%vel_target = 0;
phs0 = angle(B1);
t = [0:length(B1)-1]*dt;
phsvel = gambar*vel_target*cumsum(Gz(:).*t(:))*dt;
B1sel = B1 .* exp(-1i*phsvel);

% alternative code
%{
delta_phs = 0;
for n=1:length(t)
   	delta_phs = delta_phs + gambar * Gz(n) * vel_target * t(n) * dt; 
    B1sel(n) = B1(n)*exp(-i*delta_phs);
end
%}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

NSTEPS = length(B1);

% total duration of the simulation interval (in ms)
duration = NSTEPS*dt;  % ms.
vel_range =[-100:100]*1e-3;
vel_range = linspace(-60, 60, 200) * 1e-3;

for vel = vel_range  % cm / msec
    
    t = linspace(0,duration, NSTEPS)'; % mseconds.
    zpos = pos0 + vel*t + 0.5*accel*(t.^2);
    Bz = zpos.*Gz ;
    
    Bz = Bz + off_resonance;
    
    Bx = real(B1sel);
    By = imag(B1sel);

    beff = [Bx By  Bz];
    Mi = [0 0 1]';
    M = blochsim(Mi, beff, T1, T2, dt, NSTEPS);
    if showEvolution
        plot(M(:,3))
        drawnow
    end
    
    Mzfinal=[Mzfinal; M(end,3)];
end


% now do the control case

for vel = vel_range  % cm / msec
    
    Bz = zpos.*abs(Gz) ;

    Bz = Bz + off_resonance;
    Bx = real(B1);
    By = imag(B1);
    
    beff = [Bx By  Bz];
    Mi = [0 0 1]';
    M = blochsim(Mi, beff, T1, T2, dt, NSTEPS);
    if showEvolution
        plot(M(:,3))
        drawnow
    end
    
    Mzfinal_ns=[Mzfinal_ns; M(end,3)];
end


if batch_mode==0
    figure(3)
    t=[0:length(Gz)-1]*dt;
    
    subplot(311)
    area(t, Gz *1e4);
    grid on
    xlabel('time (ms)')
    ylabel('G_z (G/cm)')
    title('VSI Pulse')
    
    subplot(312)
    area(t, abs(B1)*1e7);
    grid on
    xlabel('time (ms)')
    ylabel('B_1 amplitude (mG)')
    
    subplot(313)
    plot(t, angle(B1sel));
    hold on
    plot(t, angle(B1));
    hold off
    grid on
    xlabel('time (ms)')
    ylabel('B_1 phase (rad)')
    
    figure(4)
    hold on
    plot(vel_range*1e3, Mzfinal)
    plot(vel_range*1e3, Mzfinal_ns)
    axis([min(vel_range)*1e3 max(vel_range)*1e3, -1 1])
%    fatlines
    grid on
    xlabel('Velocity (cm/s)')
    ylabel('M_z')
    title('Velocity Profile of VSI pulse')
    legend('Selective Case', 'Non-selective Case', 'Location', 'SouthEast')
    print -dpng perfect_profile

    %text(-90 , -0.6, {refocus_scheme ;base_pulse });
    hold off
%%
end

%%  Calculating labeling efficency over a range of values
%{
figure(8)
efficiency = (Mzfinal - Mzfinal_ns)/2;
plot(vel_range, efficiency)
inds = find((vel_range < 0.08)  & (vel_range > 0.005));
hold on
plot(vel_range(inds), efficiency(inds))
mean(efficiency(inds))
xlabel('Velocity (cm/s)')
ylabel('Efficiency')
title('Velocity Profile of VSI pulse')
legend('Selective Case', 'Non-selective Case', 'Location', 'SouthEast')
hold off

%}


