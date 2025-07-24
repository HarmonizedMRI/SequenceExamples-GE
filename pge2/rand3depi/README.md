# A collection of matlab/pulseq code for generated randomized 3D EPI sequences for efficient acquisition of fMRI data

## Brief overview of what's going on
1. Set experimental parameters (FOV, resolution, TR, TE etc.)
2. For each time frame, independently generate a 2D sampling mask in the two phase-encoding (PE) directions that satisfies the following specifications:  
   a. Accleration (R) in each PE direction by undersampling.  
   b. TE by crossing the center of k-space at the same time.  
   c. CAIPI-like shifting in the slow PE direction during one traversal in the fast PE direction (i.e. one echo train) by blips.  
   d. Slew rate constraints by limiting the k-space distance between consecutive samples in the PE plane.  
   e. Sampling probabilties (e.g. Gaussian, uniform) of each location in the PE plane.  
4. Inferring from the generated sampling mask, string together a pulseq sequence. The order of sampling is saved to samp_log.mat to be used during reconstruction.  
5. Interprets the pulseq sequence for GE scanners using TOPPE.  

## Why I think this works
Greater randomness/variance in sampling patterns --> More spatially and temporally incoherent aliasing artefacts --> More noise-like in the singular value domain --> Removable via low-rank regularization and/or other denoising methods.
