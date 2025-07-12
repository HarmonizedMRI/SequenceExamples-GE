# Pulseq on GE v2 (pge2) examples 

**Table of Contents**  
[Overview and getting started](#overview-and-getting-started)  
[Software releases](#software-releases)  
[Creating the .seq file](#creating-the-pulseq-file)  
[Executing the pge file on the scanner](#executing-the-pge-file-on-the-scanner)  
[Safety management](#safety-management)  



## Overview and getting started

This repository contains examples of how to prepare and run 
[Pulseq](https://pulseq.github.io/)
sequences on GE scanners using the 'Pulseq on GE v2' (pge2) interpreter.

The pge2 interpreter is quite powerful in the sense that it directly translates
the various events specified in the Pulseq file to the hardware,
which allows great flexibility in sequence design.
This also means that care has to be taken when designing the Pulseq file, such as choosing
gradient and RF raster times that are in fact supported by GE hardware.
The information on this page is designed to guide you in creating robust Pulseq sequences for GE scanners.

It is recommended to first simulate the sequence in the GE simulator (WTools),
which helps to identify most potential issues before going to the scanner.
Instructions are available here: https://github.com/jfnielsen/TOPPEpsdSourceCode/tree/UserGuide/v7.


### Workflow 

To execute a Pulseq (.seq) file using the pge2 GE interpreter:

1. Create the .seq file more or less as one usually does, but see the information below about adding TRID labels and other considerations.

2. Convert the .seq file to a PulCeq sequence object. In MATLAB, do:
    ```matlab
    system('git clone --branch v2.4.1 git@github.com:HarmonizedMRI/PulCeq.git');
    addpath PulCeq/matlab
    ceq = seq2ceq('gre2d.seq');
    ```
    NB! Make sure the versions of the PulCeq MATLAB toolbox and the pge2 interpreter are compatible -- see below.

3. Check sequence timing with `pge2.validate()` (optional)
    ```matlab
    % Define hardware parameters
    psd_rf_wait = 150e-6;  % RF-gradient delay, scanner specific (s)
    psd_grd_wait = 120e-6; % ADC-gradient delay, scanner specific (s)
    b1_max = 0.25;         % Gauss
    g_max = 5;             % Gauss/cm
    slew_max = 20;         % Gauss/cm/ms
    gamma = 4.2576e3;      % Hz/Gauss
    sys = pge2.getsys(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, gamma);

    % Check if 'ceq' is compatible with the parameters in 'sys'
    pge2.validate(ceq, sys);
    ```
    See https://github.com/HarmonizedMRI/PulCeq/tree/tv7/matlab/%2Bpge2 for details.

4. If step 3 runs without errors, write the Ceq object to file:
    ```matlab
    pislquant = 10;  % number of ADC events at start of scan for receive gain calibration
    writeceq(ceq, 'gre2d.pge', 'pislquant', pislquant);   % write Ceq struct to file
    ```

5. Execute the .pge file with the pge2 interpreter.

An alternative workflow is to prescribe the sequence interactively using [Pulserver](https://github.com/INFN-MRI/pulserver/) -- 
this is work in progress to be presented at ISMRM 2025.


### Quick start

We recommend starting with the example in [2DGRE](2DGRE).

For information about accessing and using the pge2 interpreter, see information below.


### Discussion forum

We encourage you to post questions/suggestions about Pulseq on GE on the
[discussion forum](https://github.com/jfnielsen/TOPPEpsdSourceCode/discussions/)
on the EPIC source code repository Github site.

Bug reports can be submitted to the
[Issues forum](https://github.com/jfnielsen/TOPPEpsdSourceCode/issues/),
also on the EPIC source code site.


### Differences from the tv6 interpreter

Compared to tv6, the main features of the pge2 interpreter are:
* Loads a single binary file. We suggest using the file extension '.pge' but this is not a requirement. 
This file can be created with 
[Pulserver](https://github.com/INFN-MRI/pulserver/),
or with seq2ceq.m and writeceq.m as described below.
* Places the trapezoid, extended trapezoid, and arbitrary waveform events directly onto the hardware,
  without first interpolating to 4us raster time as in the tv6 interpreter. 
  This saves hardware memory and enables things like very long constant (CW) RF pulses.
* Updated gradient heating and SAR/RF checks, based on sliding-window calculations.



## Software releases

It is important to use the appropriate versions (release) of the PulCeq toolbox and pge2 interpreter.
In each example included here, the versions are specified. See [2DGRE/main.m](2DGRE/main.m) for an example.

For pge2 the version (release) numbering scheme is
```
v2.major.minor
```
where `major` indicates incompabitibility with previous versions, typically due to changes in 
the .pge file format.

The following is a list of mutually compatible versions of the pge2 interpreter and the PulCeq MATLAB toolbox,
starting with the latest (and recommended) version:

| pge2 (tv7) | Compatible with:   | Comments |
| ---------- | ------------------ | -------- |
| [v2.5.0-beta3](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.5.0-beta3) | [PulCeq v2.4.1](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.4.1) | Added MP26 support. |
| [v2.5.0-beta2](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.5.0-beta2) | [PulCeq v2.4.0-alpha](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.4.0-alpha) | DV26 support. Bug fixes. |
| [v2.5.0-beta](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.5.0-beta) | [PulCeq v2.4.0-alpha](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.4.0-alpha) | Allow segments without gradients to pass heating check. |
| [v2.4.0-alpha](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.4.0-alpha) | [PulCeq v2.3.0-alpha](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.3.0-alpha) | Remove limit on total number of Pulseq blocks. |
| [v2.3.0](https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/tag/v2.3.0) | [PulCeq v2.2.3-beta](https://github.com/HarmonizedMRI/PulCeq/releases/tag/v2.2.3-beta) | Supports 3D rotations |

A complete list of the release histories are available here:  
https://github.com/HarmonizedMRI/PulCeq/releases/  
https://github.com/jfnielsen/TOPPEpsdSourceCode/releases/ 



## Creating the Pulseq file

The key points to keep in mind when creating a .seq file for the pge2 interpreter are summarized here.


### Define segments (block groups) by adding TRID labels

As in tv6, we define a 'segment' as a consecutive sub-sequence of Pulseq blocks that are always executed together,
such as a TR or a magnetization preparation section.
The GE interpreter needs this information to construct the sequence.

To clarify this concept, we define the following:
* **base block:** A Pulseq block with normalized waveform amplitudes. The base blocks are the fundamental building blocks, or 'atoms', of the sequence.
* **virtual segment:** A sequence of base blocks in a particular order (with normalized amplitudes). 
You can think of this as an abstract segment.
* **segment instance:** a segment realization/occurrence within the pulse sequence, with specified waveform amplitudes and phase/frequency offsets.
A pulse sequence typically contains multiple instances of any given virtual segment:

![Segment illustration](images/segments.png)

In pratice, this means that you must **mark the beginning of each segment in the sequence with the TRID label** in the Pulseq toolbox.
Example:
```
inversionVirtualSegmentID = 4;  % any unique integer, in no particular order
imagingVirtualSegmentID = 2;

% Play an instance of the inversion virtual segment
seq.addBlock(rf_inv, mr.makeDelay(1), mr.makeLabel('SET', 'TRID', inversionVirtualSegmentID));

for i = 1:Ny
    % Play an instance of the imaging virtual segment
    seq.addBlock(rf, gz, mr.makeLabel('SET', 'TRID', virtualSegmentID));
    ...
    seq.addblock(gxPre, mr.scaleGrad(gy, (i-Ny/2-1)/(Ny/2)));
    seq.addBlock(gx, adc);
    seq.addblock(gxSpoil, mr.scaleGrad(gy, -(i-Ny/2-1)/(Ny/2)));
    ...
end
```
See also the examples included in this repository.
The TRID can be any unique integer, in no particular order. 
The TRID labels the **virtual** segment, NOT the segment instance.

When assigning TRID labels, **follow these rules**:
1. Add a TRID label to the first block in a segment. 
2. Each segment must contain at least one rf or gradient event.
   Otherwise, the safety checks done by the pge2 interpreter may fail.
3. Gradient waveforms must ramp to zero at the beginning and end of a segment.

Dynamic sequence changes that **do not** require the creation of an additional (unique) TRID label:
* gradient/RF amplitude scaling
* RF/receive phase 
* duration of a pure delay block (block containing only a delay event)
* gradient rotation

Dynamic sequence changes that **do** require a separate segment (TRID) to be assigned:
* waveform shape or duration
* block execution order within a segment
* duration of any of the blocks within a segment, unless it is a pure delay block

Other things to note:
* The interpreter inserts a 116us dead time (gap) at the end of each segment instance.
Please account for this when creating your .seq file.
(Actually, this gap is adjustable on the scanner -- it is equal to 16us plus the ssi time.)
* Each **virtual** segment takes up waveform memory in hardware, so it is generally good practice 
to divide your sequence into as few virtual segments as possible, each being as short as possible.
  

### Set system hardware parameters

**Raster times:**  
Unlike tv6, the waveforms in the .seq file are NOT interpolated to 4us, but are instead
placed directly onto the hardware. 
This is far more memory efficient and generally more accurate.
Therefore, the following raster time requirements must be met in the .seq file:
* gradient raster time must be on a 4us boundary
* RF raster time must be on a 2us boundary
* ADC raster time must be an integer multiple of 2us
* block duration must be a on a 4us boundary

**Event delays:**  
* gradient event delays must be an integer multiple of 4us
* RF event delays must be an integer multiple of 2us
* ADC event delays must be an integer multiple of 1us

**Minimum gaps before and after RF/ADC events:**   
Like on other vendors, there is some time required to turn on/off the RF amplifier and ADC card.
To our knowledge, on GE these are:
```
Time to turn RF amplifier ON = 72us             # RF dead time
Time to turn RF amplifier OFF = 54us            # RF ringdown time
Time to turn ADC ON = 40us                      # ADC dead time
Time to turn ADC OFF = 0us
```

The key thing to note is that the dead/ringdown intervals from one RF/ADC event must not overlap with those from another RF/ADC event.
For more information, see https://github.com/HarmonizedMRI/PulCeq/tree/tv7/matlab/%2Bpge2.

Also note that these times do NOT necessarily correspond to the values of `rfDeadTime`, `rfRingdownTime`, and `adcDeadTime`
you should use when creating the .seq file.
While the Pulseq MATLAB toolbox encourages the insertion of RF/ADC dead/ringdown times at the beginning
and end of each block, this is generally not necessary on GE,
and it is perfectly ok to override that behavior to make the sequence more time-efficient.
See the `sys` struct example next.

**Examples:**
```
sys = mr.opts('maxGrad', 40, 'gradUnit','mT/m', ...
              'maxSlew', 180, 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 100e-6, ...
              'rfRingdownTime', 60e-6, ...
              'adcDeadTime', 40e-6, ...
              'adcRasterTime', 2e-6, ...
              'rfRasterTime', 2e-6, ...
              'gradRasterTime', 4e-6, ...
              'blockDurationRaster', 4e-6, ...
              'B0', 3.0);
```
Note, however, that it may be possible to set some or all of the various dead- and ringdown times to 0
as long as there is a gap in the previous/subsequent block to allow time 
to turn on/off RF and ADC events.
This is because the block boundaries 'disappear' inside a segment.
If you know this to be the case, you may want to try the following, more time-efficient, alternative:

```
sys = mr.opts('maxGrad', 40, 'gradUnit','mT/m', ...
              'maxSlew', 180, 'slewUnit', 'T/m/s', ...
              'rfDeadTime', 0, ...
              'rfRingdownTime', 0, ...
              'adcDeadTime', 0, ...
              'adcRasterTime', 2e-6, ...
              'rfRasterTime', 2e-6, ...
              'gradRasterTime', 4e-6, ...
              'blockDurationRaster', 4e-6, ...
              'B0', 3.0);
```
If this results in overlapping RF/ADC dead/ringdown times, you would then adjust the timing as needed
by modifying the event delays and block durations when creating the .seq file.


### Adding gradient rotation

* Gradient rotations can be implemented 'by hand' by explicitly creating the gradient shapes and writing them into the .seq file,
  or with the `mr.rotate()` or `mr.rotate3D()` functions  in the Pulseq toolbox. 
  Note that `mr.rotate3D()` is in the 'dev' branch at the time of writing. 
  These functions return a cell array of events that can be passed directly to `seq.addBlock()`.
  When calling these functions, include all non-gradient events as well -- these will simply be passed on without change. 
  For example:
  ```
  seq.addBlock(mr.rotate(gx, gy, adc, mr.makeDelay(0.1)));
  ```
  See also the following discussion: https://github.com/pulseq/pulseq/discussions/91
* At present, each rotated waveform is stored as a separate shape in the .seq file, i.e., rotation information is not formally preserved in the .seq file.
* During the seq2ceq.m step (part of the PulCeq toolbox), rotations are detected and written into the "Ceq" sequence structure.
  This is necessary since the pge2 interpreter implements rotations more efficiently than explicit waveform shapes.
* The rotation is applied to the **entire segment** as a whole.
  In other words, the interpreter cannot rotate each block within a segment independently.
  If a segment contains multiple blocks with different rotation matrices, **only the last** of the non-identity rotations are applied. 
  If you find this to be the case, redesign the segment definitions to achieve the desired rotations.


### Sequence timing: Summary and further comments

* When loading a segment, the interpreter inserts a 116us dead time at the end of each segment.
* The parameters `rfDeadTime`, `rfRingdownTime`, and `adcDeadTime` were included in the Pulseq MATLAB toolbox
with Siemens scanners in mind, and as just discussed, setting them to 0 can in fact be a preferred option in many cases for GE users.
This is because the default behavior in the Pulseq toolbox is to quietly insert corresponding gaps at the 
start end end of each block, however this is not necessary on GE since the block boundaries 'vanish' within a segment.
* In the internal sequence representation used by the interpreter, RF and ADC events are delayed by about 100us to account for gradient delays.
Depending on the sequence details, you may need to extend the segment duration to account for this.

The Pulseq on GE v1 (tv6) user guide pdf discusses some of these points in more detail.


## Executing the pge file on the scanner

For scan instructions and troubleshooting tips, see https://github.com/jfnielsen/TOPPEpsdSourceCode/tree/UserGuide/v7


## Safety management

### PNS

PNS can be estimated in MATLAB using various tools, e.g., the [toppe.pns()](https://github.com/toppeMRI/toppe/blob/main/%2Btoppe/pns.m) function for GE, 
or the [SAFE model](https://github.com/filip-szczepankiewicz/safe_pns_prediction) for Siemens.
 [TODO: include an example of this]

### Gradient and RF subsystem protection, and patient SAR

This is handled for you by the interpreter, using a sliding-average estimation that parses through
**the first 64,000 blocks** in the sequence (or until the end of the scan is reached, whichever comes first).
It is your responsibility to ensure that the gradient/RF power in the remainder of the sequence
does not exceed that in the first 64,000 blocks.
This limit (64,000) is due to apparent memory limitations and has been determined empirically.



