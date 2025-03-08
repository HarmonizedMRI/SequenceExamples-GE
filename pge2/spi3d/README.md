# 3D TGA SPI sequence for Pulseq on GE 

Code for sequence generation and recon provided by David Frey (djfrey@umich.edu)

This example is for testing gradient rotation detection with seq2ceq.m 

This example is 3D TINY Golden Angle Spiral Projection Imaging.  
The main thing to note is that the same TRID is reused independently of rotation angle.

Tested by on the following system(s):
* GE MR750
* SW version MR30.1\_R01
* Pulseq interpreter pge2 version: https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.3.0

To download the required MATLAB packages,
create the pge sequence file, and reconstruct the data, see `main.m` in this folder.

Example reconstruction result:  
![image](https://github.com/user-attachments/assets/6f8a9bbb-a9e6-47d3-88c9-580bf4b66cdc)

## Motivation

Gradient waveform rotation is not saved in the .seq (Pulseq) file,
so seq2ceq.m is being updated to detect rotation and store the 3D rotation
matrix in scanloop.txt.

## Important points to note when preparing the .seq file

* Use the same TRID independently of rotation angle.
* The rotation is applied to the **entire segment** as a whole!
  In other words, the interpreter cannot rotate each block 
  within a segment independently.
* The rotation matrix to be applied is the one found in the **last block** in the segment.

