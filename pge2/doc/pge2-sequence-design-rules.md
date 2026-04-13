# Rules for creating pge2-compatible .seq files

The key points to keep in mind when creating a `.seq` file for the pge2 interpreter are summarized 
in ../README.md.
Here we provide both good and bad examples, to make this explicit.

We define both strict and soft rules.
Strict rules must be followed, otherwise the sequence may either fail on download, 
or may still play out but the result will not be as intended.
Soft rules are intended to promot robust and memory-efficient sequence execution. 

## Defining Segments

A segment is defined based on its first occurrence in the .seq file.
The segment definition is based on the TRID label -- no attempt is made to automatically detect segment boundaries.
The TRID label is assigned using a special command, `seq.addTRID`.

### Strict rule: The presence/absence of events must be the same for all segment instances

Once a segment is defined, the interpreter assumes that all subsequent segment instances
contain the identical sequence of blocks, and that each block contains the same set of non-empty RF, gradient, adc, and trigger events.
The *type* of each gradient waveform (`grad`, `trap`) must also be consistent across segment instances.

#### Example

The following will download on the scanner and may even run, but will not produce the intended result:

```matlab
% Bad example
n_dummy = 10;
for iy = 1:n_dummy+n_y;
   seq.addTRID('acquire');
   seq.addBlock(rf, gz);       % block A
   if iy <= n_dummy
       seq.addBlock(gx);       % block B
   else
       seq.addBlock(gx, adc);  % block C
   end
   seq.addBlock(gz_spoil);     % block D
end
```
The resulting segment definition is:
```
ABD
```
Here, the adc event (block C) will never be executed, since it's not present in the segment definition.

The solution is to create two segments:
```matlab
n_dummy = 10;
for iy = 1:n_dummy+n_y;
   if iy <= n_dummy
       seq.addTRID('dummy_shot');
   else
       seq.addTRID('acquire');
   end
   seq.addBlock(rf, gz);       % block A
   if iy <= n_dummy
       seq.addBlock(gx);       % block B
   else
       seq.addBlock(gx, adc);  % block C
   end
   seq.addBlock(gz_spoil);     % block D
end
```
The resulting segment definitions are:
```
Segment 1: ABD
Segment 2: ACD
```
Now the interpreter will execute Segment 1 `n_dummy` times, and the Segment 2 `n_y` times.


### Soft rule 1: minimize the number of blocks in a segment

Each abstract segment is placed in waveform sequence memory on scanner hardware, which has limited memory.
It is therefore generally best to make the abstract segments consist of as few blocks as possible,
while keeping the total number of segments small.

#### Example

The following may run, but is inefficient since the 'acquire' segment contains a large number 
of blocks:
```matlab
% Bad example
n_y = 32;
seq.addTRID('acquire');
for iy = 1:n_y;
   seq.addBlock(rf, gz);       % block A
   seq.addBlock(gx, adc);      % block B
   seq.addBlock(gz_spoil);     % block C
end
```
The resulting segment contains the following block sequence:
```
ABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABC
```
The pge2 interpreter will attempt to load this entire sequence into waveform memory,
and then execute it once.

The better implementation is:
```matlab
% Bad example
n_y = 32;
for iy = 1:n_y;
   seq.addTRID('acquire');
   seq.addBlock(rf, gz);       % block A
   seq.addBlock(gx, adc);      % block B
   seq.addBlock(gz_spoil);     % block C
end
```
The resulting segment is simply:
```
ABC
```
The pge2 interpreter will load this segment into sequencer memory and execute it 32 times.

Note that in this example, we have for simplicity and clarity left out the y phase-encoding gradient that would be necessary to acquire an actual image.


The pge2 interpreter directly translates the events specified in the PulSeg representation to the hardware, enabling flexible and efficient sequence execution.  

Segment Identification: Deep dive on using seq.addTRID() effectively to avoid "virtual segment" bloat.

Hardware Synchronization: Specific examples of aligning RF to 2us and Gradients to 4us boundaries (and why floor or round is your friend here).

Dead Time Strategy: How to set rfDeadTime to 0 in mr.opts while manually managing the 72us/54us gaps for maximum efficiency.

Waveform Reusability: The "Do's and Don'ts" of mr.scaleGrad vs. creating new trapezoids in a loop.

Rotation Logic: A warning section that only the last rotation in a segment is applied.


## Segment Identification

Here we do a deep dive on using `seq.addTRID()` effectively to avoid "virtual segment" bloat.

**Definition:**
We define a 'segment' as a consecutive sub-sequence of Pulseq blocks that are always executed together,
such as a TR or a magnetization preparation section.
A segment corresponds roughly to a reusable unit such as a TR or preparation module.
The GE interpreter needs this information to construct the sequence.

To clarify this concept, we define the following:
* **base block:** A Pulseq block with normalized waveform amplitudes. The base blocks are the fundamental building blocks, or 'atoms', of the sequence.
* **virtual segment:** A sequence of base blocks in a particular order (with normalized amplitudes). 
You can think of this as an abstract segment.
* **segment instance:** a segment realization/occurrence within the pulse sequence, with specified waveform amplitudes and phase/frequency offsets.
A pulse sequence typically contains multiple instances of any given virtual segment:

![Segment illustration](images/segments.png)

In practice, this means that you must **mark the beginning of each segment instance in the sequence using the `seq.addTRID()` function** in the Pulseq toolbox.
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
  

## Hardware Synchronization 

Specific examples of aligning RF to 2us and Gradients to 4us boundaries.

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


## Dead- and ringdown-time strategy 

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


## Sequence timing 

How to set rfDeadTime to 0 in mr.opts while manually managing the 72us/54us gaps for maximum efficiency.

* When loading a segment, the interpreter inserts a 117 us dead time at the end of each segment.

* The default values for `rfDeadTime`, `rfRingdownTime`, and `adcDeadTime` in the Pulseq MATLAB toolbox
were set with Siemens scanners in mind, and as just discussed, setting them to 0 can in fact be a preferred option in many cases for GE users.
This is because the default behavior in the Pulseq toolbox is to quietly insert corresponding gaps at the 
start end end of each block, however this is not necessary on GE since the block boundaries 'disappear' within a segment.

* In the internal sequence representation used by the interpreter, RF and ADC events are delayed by about 100 us to account for gradient delays.
Depending on the sequence details, you may need to extend the segment duration to account for this.

The `pge2.check()` and `pge2.validate()` functions help to catch many issues before attempting to simulate or run on the scanner.





