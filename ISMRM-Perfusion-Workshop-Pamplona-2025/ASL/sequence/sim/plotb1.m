function plotb1(b1, g, dt)

t = dt/2:dt:dt*length(b1);

subplot(221);
plot(t, abs(b1)); 
subplot(222);
plot(t, angle(b1)); xlabel('time'); ylabel('rad');
subplot(223);
plot(t, g); xlabel('time'); ylabel('a.u.');
