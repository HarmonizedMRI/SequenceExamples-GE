
system('git clone git@github.com:JeffFessler/MIRT.git');
cd MIRT; setup; cd ..;

system('git clone --branch v1.9.1 git@github.com:toppeMRI/toppe.git');
addpath toppe

addpath ~/Programs/orchestra-sdk-2.1-1.matlab/

recon_ir

plot_ir
