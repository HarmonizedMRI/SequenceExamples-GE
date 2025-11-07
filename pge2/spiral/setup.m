% get Pulseq toolbox
system('git clone --branch v1.5.1 git@github.com:pulseq/pulseq.git');
addpath pulseq/matlab

% Get toolbox to convert .seq file to a PulCeq (Ceq) object
%system('git clone --branch tv7 git@github.com:HarmonizedMRI/PulCeq.git');
%addpath PulCeq/matlab
addpath ~/github/HarmonizedMRI/PulCeq/matlab

system('git clone --branch main git@github.com:toppeMRI/toppe.git');
addpath toppe/

% curdir = pwd; cd ~/github/mirt; setup; cd(curdir);
