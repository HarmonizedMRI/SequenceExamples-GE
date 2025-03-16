function [rf, g] = readaslprep(path)

maxpgwamp = 32766;

g = load([path '/grad.txt']);
mxg = 1.2;   % Gauss/cm
g = mxg*g/maxpgwamp;  % Gauss/cm

% control is same except abs(g)
g(:,2) = abs(g(:,1));

rho = load([path '/rho.txt']);
mxrf = 0.234;   % Gauss
rho = mxrf*rho/maxpgwamp;  % Gauss

theta = load([path '/theta.txt']);
theta = pi*theta/maxpgwamp;          % radians

rf = rho.*exp(1i*theta);

