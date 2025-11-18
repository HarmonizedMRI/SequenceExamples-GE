# Demos equence for Pulseq on GE v2 (pge2)

This is the 'official' demo sequence and it is a good idea to try it first so you understand the workflow,
and to carefully inspect writedemo.m including all comments.

This is a 2D spoiled gradient echo sequence but with a few additional (and often silly)
additions to demonstrate various features such as  
* ability to use different ADC events 
* 

Tested on the following system(s):  
| Scanner | Scanner SW version | pge2 version | PulCeq version |  
| --- | --- | --- | --- |
| GE UHP | MR30.1\_R01 | [v2.5.2.1](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.5.2.1) | [v2.5.2.0](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.5.2.0) |  

<!--
| GE MR750 | MR30.1\_R01 | [v2.5.0-beta](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.5.0-beta) | [v2.4.0-alpha](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.4.0-alpha) |  
| GE MR750 | MR30.1\_R01 | [v2.3.0](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.3.0) | [v2.2.2](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.2.2) |
-->

To download the required MATLAB packages,
create the pge sequence file, and reconstruct the data, see `setup.m` and `main.m` in this folder.

For GE scan instructions, see https://github.com/jfnielsen/TOPPEpsdSourceCode/tree/UserGuide/v7

The output of `main.m` is shown below.
The images on the left and right are from the 1st and 2nd echo, respectively.

![Ball phantom](1.jpg)

