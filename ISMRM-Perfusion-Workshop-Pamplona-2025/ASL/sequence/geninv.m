function rf = geninv(A0, beta, mu, dur)
% function geninv(A0, beta, mu, dur)
% hyperbolic secant adiabatic inversion pulse
%
% Example from https://labs.dgsom.ucla.edu/mrrl/files/view/m229-2021/M229_Lecture5_Adiabatic_Pulses.pdf
%
% rf = geninv(0.15, 672, 5, 10e-3);

dt = 4e-6;  % raster time (s)
t = -dur/2:dt:dur/2-dt/2;
w1 = -mu*beta*tanh(beta*t);
A = A0 * sech(beta*t);
rf = A .* exp(1i*dt*cumsum(w1));

return

subplot(121);
plot(abs(rf));
subplot(121);
plot(angle(rf));
