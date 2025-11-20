% get Pulseq toolbox
system('git clone --branch v1.5.1 git@github.com:pulseq/pulseq.git');
addpath pulseq/matlab

% get toolbox to convert .seq file to a PulCeq (Ceq) object
system('git clone --branch tv7 git@github.com:HarmonizedMRI/PulCeq.git');
addpath PulCeq/matlab
addpath PulCeq/matlab/DataHash

% To load the ScanArchive raw data files you will need the Orchestra toolbox
% which is available for download at http://weconnect.gehealthcare.com/ 
addpath ~/Programs/orchestra-sdk-2.1-1.matlab/

% get 'im' display function (optional)
system('git clone --depth 1 git@github.com:JeffFessler/mirt.git');
cd mirt; setup; cd ..;
