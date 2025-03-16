# 3D stack of spirals recon using nufft in MIRT (fully sampled)

First run ../sequence/main.m to create readout.mat with kspace trajectory
Then: recon\_asl

main\_ir.m: recon multiple-TI IR data, to test adiabatic inversion

## MATLAB R2022a test

reconstructed fine


## MATLAB R2024b test

toppe.utils.spiral.reconSoS failed at parallel pool setup stage in R2024a
