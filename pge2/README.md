# Pulseq on GE v2 (pge2) examples 

**Table of Contents**  
[Overview and getting started](#overview-and-getting-started)  
[Creating the .seq file](#creating-the-pulseq-file)  
[Safety management](#safety-management)  

(Updated Mar 2026)


## Overview

This repository contains examples of how to prepare and run
Pulseq sequences on GE scanners using the **Pulseq on GE v2 (pge2)** interpreter.

The workflow is based on a **vendor-neutral intermediate representation**, called **PulSeg**, which is derived from the Pulseq `.seq` file and organizes the sequence into reusable segments.

The pge2 interpreter directly translates the events specified in the PulSeg representation to the hardware, enabling flexible and efficient sequence execution.  
Because of this low-level control, care must be taken to ensure that timing, rasterization, and hardware constraints are respected.

---

## Workflow

To execute a Pulseq (`.seq`) file on a GE scanner using the pge2 interpreter, the sequence is first converted into a **PulSeg object**, validated, and then serialized to a `.pge` file.

### 1. Create the Pulseq file (`.seq`)

Generate the `.seq` file as usual using Pulseq.

```matlab
write2DGRE;
```

---

### 2. Convert to PulSeg representation

```matlab
psq = pulseg.fromSeq([seq_name '.seq']);
```

---

### 3. Define scanner hardware parameters

```matlab
sys_ge = pge2.opts(psd_rf_wait, psd_grd_wait, b1_max, g_max, slew_max, coil);
```

---

### 4. Check sequence constraints

```matlab
params = pge2.check(psq, sys_ge, 'PNSwt', PNSwt);
```

---

### 5. Save PulSeg object (optional)

```matlab
save(seq_name, 'psq', 'params', 'pislquant');
```

---

### 6. Visualize the sequence

```matlab
S = pge2.plot(psq, sys_ge);
```

---

### 7. Validate against original Pulseq file

```matlab
seq = mr.Sequence();
seq.read([seq_name '.seq']);

pge2.validate(psq, sys_ge, seq, ...);
```

---

### 8. Serialize to `.pge`

```matlab
pge2.serialize(psq, [seq_name '.pge'], ...);
```


## Obtaining the software

To use the pge2 workflow, you will need:

### 1. PulSeg tools (Pulseq → PulSeg conversion)

Available at:
https://github.com/HarmonizedMRI/PulSeg

This repository provides:

* `pulseg.fromSeq` (Pulseq → PulSeg conversion)
* Definition of the PulSeg representation

### 2. pge2 MATLAB toolbox

Available at:
https://github.com/HarmonizedMRI/pge2

This toolbox provides:

* Visualization: `pge2.plot`

* Validation: `pge2.check`, `pge2.validate`

* Serialization: `pge2.serialize`


### 3. GE interpreter (EPIC)

Available at:
https://github.com/GEHC-External/pulseq-ge-interpreter

(Contact GE for access)

That site also contains instructions for simulating the `.pge` sequence and running it on the scanner.


## Creating the Pulseq file

The key points to keep in mind when creating a `.seq` file for the pge2 interpreter are summarized here.

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

In pratice, this means that you must **mark the beginning of each segment instance in the sequence using the seq.addTRID() function** in the Pulseq toolbox.
Example:
```matlab

% Play an instance of the inversion virtual segment consisting of two blocks
seq.addTRID('inversion');
seq.addBlock(rf_inv);
seq.addBlock(mr.makeDelay(1));

% Imaging loop
for i = 1:Ny
    % Play an instance of the imaging virtual segment
    seq.addTRID('acquire');
    seq.addBlock(rf, gz);
    ...
    seq.addblock(gxPre, mr.scaleGrad(gy, (i-Ny/2-1)/(Ny/2)));
    seq.addBlock(gx, adc);
    seq.addblock(gxSpoil, mr.scaleGrad(gy, -(i-Ny/2-1)/(Ny/2)));
    ...
end
```

When assigning TRID labels, **keep the following in mind**:
1. Gradient waveforms must ramp to zero at the beginning and end of a segment.

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
* The interpreter inserts a 117 us dead time (gap) at the end of each segment instance.
Please account for this when creating your `.seq` file.
(Actually, this gap is adjustable on the scanner -- it is equal to 17us plus the ssi time.)
* Each **virtual** segment takes up waveform memory in hardware, so it is generally good practice 
to divide your sequence into as few virtual segments as possible, each being as short as possible.
* Even empty blocks containing nothing but one or more labels are -- from a segment definition standpoint --
  just as important as 'real' blocks of non-zero duration.
  

### Set system hardware parameters

**Raster times:**  
Unlike tv6, the waveforms in the `.seq` file are NOT interpolated to 4us, but are instead
placed directly onto the hardware. 
This is far more memory efficient and generally more accurate.
Therefore, the following raster time requirements must be met in the `.seq` file:
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

Also note that these times do NOT necessarily correspond to the values of `rfDeadTime`, `rfRingdownTime`, and `adcDeadTime`
you should use when creating the `.seq` file.
While the Pulseq MATLAB toolbox encourages the insertion of RF/ADC dead/ringdown times at the beginning
and end of each block, this is generally not necessary on GE,
and it is perfectly ok to override that behavior to make the sequence more time-efficient.

**Examples:**
```matlab
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

```matlab
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
by modifying the event delays and block durations when creating the `.seq` file.



### Additional recommendations

* **Pre-define events outside of the main loop in your `.seq` file creation script.**
GE sequences are built on the idea that there is a small set of pre-defined RF/gradient events,
that repeat many times throughout the sequence except with (possibly) varying amplitudes,
phase offsets, or (gradient) rotation;
these pre-defined events give rise to the base blocks described above.
It is therefore highly recommended to define events once, and then use `mr.scaleGrad()` to scale
them as needed inside the main loop.
This ensures proper detection of the base blocks during the `pulseg.fromSeq` conversion stage;
if creating independent events inside the main loop using repeated calls to, e.g., `mr.makeTrapezoid()`, the
resulting trapezoids generally do not have identical shapes and are therefore not instances of a shared base block.

* **Avoid setting waveform amplitudes to exactly zero -- instead, set to `eps` or a similarly small number.**
This is recommended because the Pulseq toolbox may not recognize, e.g., a zero-amplitude trapezoid
as exactly that, which is in conflict with the GE sequence model.

* **Use rotation events,** rather than rotating gradients manually or using the older
`mr.rotate` or `mr.rotate3D` functions (in the core Pulseq toolbox).
Rotation events are a new feature in Pulseq, see https://github.com/pulseq/pulseq/discussions/117.
**NB! The rotation is applied to the entire segment as a whole.**
In other words, the interpreter cannot rotate each block within a segment independently.
If a segment contains multiple blocks with different rotation matrices, **only the last** of the non-identity rotations are applied. 
If you find this to be the case, redesign the segment definitions to achieve the desired rotations.

* Check your sequence using **pge2.validate()**, and plot the PulSeg object using
**pge2.plot()**.
This helps catch errors before simulating in WTools or scanning.


### Sequence timing: Summary and further comments

* When loading a segment, the interpreter inserts a 117 us dead time at the end of each segment.

* The default values for `rfDeadTime`, `rfRingdownTime`, and `adcDeadTime` in the Pulseq MATLAB toolbox
were set with Siemens scanners in mind, and as just discussed, setting them to 0 can in fact be a preferred option in many cases for GE users.
This is because the default behavior in the Pulseq toolbox is to quietly insert corresponding gaps at the 
start end end of each block, however this is not necessary on GE since the block boundaries 'disappear' within a segment.

* In the internal sequence representation used by the interpreter, RF and ADC events are delayed by about 100 us to account for gradient delays.
Depending on the sequence details, you may need to extend the segment duration to account for this.

The `pge2.check()` and `pge2.validate()` functions help to catch many issues before attempting to simulate or run on the scanner.


## Safety management

### PNS

This is currently built in to the MATLAB function `pge2.check()`.

### Gradient and RF subsystem protection, and patient SAR

This is handled for you by the interpreter, using a sliding-average estimation that parses through
**the first 40,000 blocks** in the sequence (or until the end of the scan is reached, whichever comes first).
It is your responsibility to ensure that the gradient/RF power in the remainder of the sequence
does not exceed that in the first 40,000 blocks.
This limit (40,000) is due to apparent memory limitations and has been determined empirically.



