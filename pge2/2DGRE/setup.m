% get Pulseq toolbox
system('git clone --branch master git@github.com:pulseq/pulseq.git');
addpath pulseq/matlab

% get toolbox to convert .seq file to a PulSeg sequence (psq) object
system('git clone git@github.com:HarmonizedMRI/pulseg.git');
addpath pulseg/matlab
addpath(genpath('pulseg/matlab/third_party'));

% get toolbox for plotting psq object and exporting to binary file for GE 
system('git clone git@github.com:HarmonizedMRI/pge2.git');
addpath pge2/matlab

return


% To load the ScanArchive raw data files you will need the Orchestra toolbox
% which is available for download at http://weconnect.gehealthcare.com/ 
addpath ~/Programs/orchestra-sdk-2.1-1.matlab/

% get 'im' display function (optional)
system('git clone --depth 1 git@github.com:JeffFessler/mirt.git');
cd mirt; setup; cd ..;
