# 3D EPI sequence for Pulseq on GE

Code for sequence generation and basic recon provided by Rex Fung (rexfung@umich.edu)

This example is 3D Echo Planar Imaging (3D EPI).

It generates the following 3 `.seq` and `.pge` files:
1. `randEPI`: 3D EPI sequence with optional random undersampling. There is no acceleration in this example.
2. `EPIcal`: A short EPI sequence without phase encoding. Used to calibrate receiver gains and estimate phase difference between odd/even echoes.
3. `GRE`: GRE sequence for sensitivity map estimation.

It also generates the following `.mat` files:
1. `kxoe$Nx`: contains the k-space sampling locations along the readout or kx direction. Used later to grid ramp-sampled data.
2. `samp_log`: contains the order of k-space sampling indices. Used later to allocate sampled data onto a zero-filled grid.

This example demonstrates a 3D EPI acquisition with the following parameters, described in `params.m`:
| Acceleration | Acquisition array | Field of view | Resolution | TR | Duration (frames)|
| --- | --- | --- | --- | --- | --- |
| 1x | 90 x 90 x 60 | 216 x 216 x 144 mm | 2.4 mm isotropic | 4.2 s | 58.8 s (14) |

Tested on the following system(s):
| Scanner | Scanner SW version | pge2 version | PulCeq version |  
| --- | --- | --- | --- |  
| GE MR750 | MR30.1\_R01 | [v2.5.0-beta](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.5.0-beta) | [v2.4.0-alpha](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.4.0-alpha) |

Example reconstruction results:  
**TODO: insert images here**

For more advanced locally low-rank (LLR) reconstruction, check out [this repo](https://github.com/rextlfung/fmri-recon), which is under active development using the Julia language.

The existing codebase also supports randomized undersampling in the two phase-encoding directions in 3D EPI.

# Historical notes
A collection of matlab/pulseq code for generated randomized 3D EPI sequences for efficient acquisition of fMRI data

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
