
function mysech = genSech180(sweepWidth, duration)
% function mysech = genSech180(sweepWidth, duration)
% duration in ms
% sweepWidth is in kHz
% 
% dt = 4e-3; % time units in ms.
% sechlen = 4.0 / dt;
% beta = 1;
% k = 1;
%

dt = 4e-3;
sech_dur = duration;
sechlen = sech_dur / dt;

beta = 1.5;
k = 0.4;

% amplitude of the sech pulse is normalized to 1
sech_amp = sech(beta * linspace(-pi , pi, sechlen));
%sech_amp = sech(beta * linspace(-1.5*pi , 1.5*pi, sechlen));

%sech_amp = cos(linspace(-pi/2 , pi/2, B1seglen*Npulses));
%sech_amp = sech_amp / norm(sech_amp*dt);
sech_amp = sech_amp / max(sech_amp);


% frequency sweep of the sech pulse
% sech_freq = -tanh(k*beta * linspace(-pi , pi, sechlen+1)); % works well
sech_freq = -tan(k*linspace(-pi , pi, sechlen+1));

%sech_freq = round(sech_freq*1e4)/1e4;
sech_freq = sweepWidth * sech_freq / max(sech_freq);

RF_dw = sech_freq;

% time vector for the sech pulses
% sech_tvec = RF_duration * Npulses * linspace(-0.5, 0.5, sechlen);
% mysech = sech_amp .* exp(i * 2 * pi * sech_freq .* sech_tvec);
% sech_tvec = linspace(-0.5, 0.5, sechlen);
% mysech =  exp(i * 2 * pi * sech_freq .* sech_tvec);

% or  ...
sech_phase = cumsum(sech_freq)*dt*2*pi;
sech_phase = sech_phase(1:end-1);
sech_phase = round(sech_phase*1e4)/1e4;

mysech = sech_amp .* exp(i .* sech_phase);

%fprintf('\nDuration of the Original sech pulse: %f ms', Npulses*RF_duration);
%fprintf('\rMaximum B1 amp in my_sech %f Tesla', max(abs(sech_amp)));


%{
    subplot(311)
    plot(abs(mysech)), title('Amplitude')
    axis tight
    hold on
    subplot(312)
    plot(sech_freq), title('Frequency')
        axis tight
    hold on
    subplot(313)
    plot(angle(mysech)), title('Phase')
    hold on
        axis tight
%}
%genScannerPulses(mysech, zeros(size(mysech)), dt);

return
