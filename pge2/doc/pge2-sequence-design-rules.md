# Rules for creating pge2-compatible .seq files

The key points to keep in mind when creating a `.seq` file for the pge2 interpreter are summarized 
in ../README.md.
Here we define both **strict and soft rules**, to further clarify these concepts and promote best coding practices.

Strict rules MUST be followed, otherwise the sequence may either fail on download, 
or may still play out but the result will not be as intended.

Soft rules are intended to promote robust and memory-efficient sequence execution. 


## Defining Segments

Segment boundaries are defined exclusively by TRID labels, that you assign as follows:

```matlab
seq.addTRID(<text_label>);
```

where `<text_label>` is any unique (and preferably descriptive) text string.

We suggest using separate TRIDs for logically distinct sequence states, such as:
- `dummy_shots`
- `calibration_scans`
- `imaging_shots`
- `navigator_segments`

A segment consists of all blocks following a given TRID label, up to (but not including) the next TRID label.

The first time a TRID is encountered, pge2 stores that segment as the **abstract definition**.
Later uses of the same TRID do not redefine the segment — they only replay the stored definition with updated waveform/RF/ADC parameters.


### Strict rule: The presence/absence of events must be the same for all segment instances

The event *structure* must remain identical across all instances:

* same number of blocks,
* same event types present in each block (RF / trap / arbitrary gradient / ADC / trigger),

However, waveform amplitudes, phases, and frequencies may vary as long as the block/event structure is unchanged.

Note: the duration of delay-only blocks may vary between segment instances, 
as long as the delay block itself is present in the same block position in every instance.
This is the recommended way to implement variable timing (e.g., TE / TR adjustments) without changing segment structure.


#### Example

The following will download on the scanner and may even run, but will not produce the intended result:

```matlab
% Bad example!
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

Because the first segment instance defines block B as containing only gx, 
later attempts to add the `adc` event in that block position are ignored by the interpreter. 
As a result, no data will be acquired during those segment instances.

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
Abstract segment 1: ABD
Abstract segment 2: ACD
```

Now the interpreter will correctly execute Segment 1 `n_dummy` times, and Segment 2 `n_y` times.

Note that in this example, we have for simplicity and clarity left out the y phase-encoding gradient that would be necessary to acquire an actual image.

#### Example

A common Pulseq pattern is inserting delays conditionally.
However, conditional insertion/removal of delay-only blocks also changes segment structure and is not allowed within a segment.


MATLAB
```matlab
if delay_vec(iy) > 0
    seq.addBlock(mr.makeDelay(delay_vec(iy))); % NOT OK: conditional block presence
end
```

Instead, do:
```matlab
for iy = 1:n_y
    seq.addTRID('acquire');
    seq.addBlock(rf, gz);
    seq.addBlock(mr.makeDelay(delay_vec(iy))); % OK: same block, variable duration
    seq.addBlock(gx, adc);
end
```

### Soft rule: minimize the number of blocks in a segment

Each abstract segment is placed in waveform sequence memory on scanner hardware, which has limited memory.
It is therefore generally best to make the abstract segments consist of as few blocks as possible.

However, while shorter segments are preferred, avoid creating an excessive number of unique segment types, 
since each abstract segment also consumes sequencer resources.

#### Example

The following may run, but is inefficient since the 'acquire' segment contains a large number 
of blocks:
```matlab
% Bad example!
n_y = 16;
seq.addTRID('acquire');
for iy = 1:n_y;
   seq.addBlock(rf, gz);       % block A
   seq.addBlock(gx, adc);      % block B
   seq.addBlock(gz_spoil);     % block C
end
```
The resulting abstract segment contains the following block sequence:
```
Abstract segment 1: ABCABCABCABCABCABCABCABCABCABCABCABCABCABCABCABC
```
The pge2 interpreter will attempt to load this entire sequence into waveform memory,
and then execute it once.
Depending on the available hardware memory, the sequence may or may not play out on the scanner.

The better implementation is:
```matlab
n_y = 16;
for iy = 1:n_y;
   seq.addTRID('acquire');
   seq.addBlock(rf, gz);       % block A
   seq.addBlock(gx, adc);      % block B
   seq.addBlock(gz_spoil);     % block C
end
```
The resulting abstract segment is simply:
```
Abstract segment 1: ABC
```
The pge2 interpreter will load this segment into sequencer memory and execute it `n_y` times.


---
---

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



Segment Identification: Deep dive on using seq.addTRID() effectively to avoid "virtual segment" bloat.

Hardware Synchronization: Specific examples of aligning RF to 2us and Gradients to 4us boundaries (and why floor or round is your friend here).

Dead Time Strategy: How to set rfDeadTime to 0 in mr.opts while manually managing the 72us/54us gaps for maximum efficiency.

Waveform Reusability: The "Do's and Don'ts" of mr.scaleGrad vs. creating new trapezoids in a loop.

Rotation Logic: A warning section that only the last rotation in a segment is applied.



