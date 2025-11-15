% get Pulseq toolbox
system('git clone --branch v1.5.1 git@github.com:pulseq/pulseq.git');
addpath pulseq/matlab

% Get toolbox to convert .seq file to a PulCeq (Ceq) object
%system('git clone --branch tv7 git@github.com:HarmonizedMRI/PulCeq.git');
%addpath PulCeq/matlab
addpath ~/github/HarmonizedMRI/PulCeq/matlab

curdir = pwd; cd ~/github/mirt; setup; cd(curdir);

system('git clone --depth 1 --branch v1.9.0 git@github.com:toppeMRI/toppe.git');
addpath toppe

system('git clone --depth 1 git@github.com:JeffFessler/mirt.git');
cd mirt; setup; cd ..;

% You can download the Orchestra toolbox from http://weconnect.gehealthcare.com/
addpath ~/Programs/orchestra-sdk-2.1-1.matlab/
