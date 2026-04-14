# Rules for creating pge2-compatible .seq files

The key points to keep in mind when creating a `.seq` file for the pge2 interpreter are summarized 
in ../README.md.
Here we define both **strict and soft rules**, to further clarify these concepts and promote best practices.

Strict rules MUST be followed, otherwise the sequence may either fail on download, 
or may still play out but the result will not be as intended.

Soft rules are intended to promote robust and memory-efficient sequence execution. 

## The segment concept

We define a 'segment' as a consecutive sub-sequence of Pulseq blocks that are always executed together,
such as a TR or a magnetization preparation section.
A segment corresponds roughly to a reusable unit such as a TR or preparation module.
The GE interpreter needs this information to construct the sequence.

### Visual Guide: From Blocks to Scan Loop

The pge2 interpreter uses a hierarchical approach to build a sequence:

- **Base Blocks (The Atoms):** These are individual Pulseq blocks with normalized waveform amplitudes.
- **Virtual Segments (The Templates):** These are abstract sequences of base blocks ordered to form a functional unit, such as a specific TR or preparation module. As shown in the image, `seqcore_id1` combines an excitation, phase encoding, acquisition, and spoiler into one template.
- **Scan Loop (The Instances):** This is the physical execution on the scanner. Each segment instance follows the structural template of its Virtual Segment but applies specific parameters like RF phase or gradient amplitude (e.g., `gy.amp = 0.7`).

![Segment illustration](../images/segments.png)


## Defining Segments

Segment boundaries are defined exclusively by TRID labels, that are assigned as follows:

```matlab
seq.addTRID(<text_label>);
```

where `<text_label>` is any unique text string.
We suggest using separate TRIDs for logically distinct sub-sequences, such as:
- `dummy_shot`
- `calibration_scan`
- `imaging_shot`
- `navigator_segment`

A segment consists of all blocks following a given TRID label, up to (but not including) the next TRID label.

The first time a TRID is encountered, pge2 stores that segment as the **abstract definition**.
Later uses of the same TRID do not redefine the segment — they only replay the stored segment structure using the corresponding event parameters for that instance.


### Strict rule: The presence/absence of events must be the same for all segment instances

The event *structure* must remain identical across all instances:

- same number of blocks,
- same event types present in each block (RF / trap / arbitrary gradient / ADC / trigger),

However, waveform amplitudes, phases, and frequencies may vary as long as the block/event structure is unchanged.

Note: the duration of delay-only blocks may vary between segment instances, 
as long as the delay block itself is present in the same block position in every instance.
This is the recommended way to implement variable timing (e.g., TE / TR adjustments) without changing segment structure.

**Important hardware caveat:**
On GE systems, changing the duration of a delay-only block requires inserting a hardware WAIT pulse (EPIC SSP packet).
SSP packets are also used to control RF and ADC events. 
Therefore, the start of a variable-duration delay block must not overlap with RF / ADC dead-time or ringdown intervals from neighboring events.
For example, if a delay is used for TE stepping, it should be placed between the end of the RF ringdown and the start of the readout gradient to avoid hardware conflicts.

In practice, variable delay blocks should only be used in timing regions that are already free of RF / ADC activity and their associated hardware guard intervals.

#### Practical recommendation: define reusable base events outside the main loop

In practice, satisfying the segment consistency rule usually requires defining reusable RF and gradient events once, outside the main loop that creates repeated segment instances.

GE sequences are designed around a relatively small set of pre-defined waveform objects that are replayed many times, with only parameters such as:

- gradient amplitude,
- RF phase / frequency offset,
- gradient rotation

changing between repetitions.

The pge2 conversion pipeline follows the same philosophy: during `pulseg.fromSeq`, it identifies repeated waveform patterns and converts them into shared base blocks.

If new events are created independently inside the main loop using repeated calls to functions such as `mr.makeTrapezoid()`, small differences in:

- raster rounding,
- rise / fall timing,
- flat-top duration

may cause those events to be treated as distinct waveforms, even if they were intended to be identical.

This can:

- prevent proper block reuse,
- increase waveform memory usage,
- cause segment detection / playback issues.

Therefore, it is **strongly recommended** to:

- define base RF / gradient events once outside the loop,
- reuse them directly when possible,
- use `mr.scaleGrad()` (and related utilities) to vary amplitudes as needed.

Using `mr.scaleGrad` not only ensures consistency but also significantly reduces the size of the .pge file by maximizing waveform reuse.

Recommended pattern:
```matlab
gx_base = mr.makeTrapezoid('x', ...);

for iy = 1:n_y
    gx = mr.scaleGrad(gx_base, pe_scale(iy));
    seq.addTRID('acquire');
    seq.addBlock(rf, gz);
    seq.addBlock(gx, adc);
end
```

Discouraged pattern:
```matlab
for iy = 1:n_y
    gx = mr.makeTrapezoid('x', 'Area', area_vec(iy), ...); % risky
    seq.addTRID('acquire');
    seq.addBlock(rf, gz);
    seq.addBlock(gx, adc);
end
```


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
       seq.addBlock(rf, gz);   % block A
       seq.addBlock(gx);       % block B
   else
       seq.addTRID('acquire');
       seq.addBlock(rf, gz);   % block A
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

```matlab
if delay_vec(iy) > 0
    seq.addBlock(mr.makeDelay(delay_vec(iy))); % NOT OK: conditional block presence
end
```

If timing must vary, use a delay block in all instances and vary only its duration:

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
Segmenting the sequence into an excessively large number of unique abstract segments 
also risks making the code less readable.

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
The pge2 interpreter will attempt to load this large segment into waveform memory,
and then execute it only once.
Depending on the available hardware memory, the sequence may or may not play out on the scanner.

The following may also be technically possible:

```matlab
for iy = 1:n_y;
   seq.addTRID('excite');
   seq.addBlock(rf, gz);       % block A

   seq.addTRID('acquire');
   seq.addBlock(gx, adc);      % block B

   seq.addTRID('spoil');
   seq.addBlock(gz_spoil);     % block C
end
```

which produces the following abstract segments:

```
Abstract segment 1: A
Abstract segment 2: B
Abstract segment 3: C
```

However, this has several drawbacks:
 - Gradient waveforms must start on 0 and ramp down to 0 before the end of each segment. 
   This restricts the kind of waveforms that this approach can support. 
 - Breaks the link between segments and logically distinct sub-sequences
 - Causes code bloat and makes the code harder to read
 - Increases the number of segment ringdown time gaps (117 us) in the sequence

The **recommended implementation** for this example is:

```matlab
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
This has about the same hardware memory requirements as the previous approach, 
but is consistent with the notion of a 'sequence TR'.


## Setting system (scanner) parameters

### Raster times

The waveforms in the `.seq` file are placed directly onto the hardware (no interpolation is performed),
and must therefore adhere to the scanner raster time requirements.
For GE scanners, this means:

- `sys.gradRasterTime` must be an integer multiple of 4us
- `sys.rfRasterTime` must be an integer multiple of 2us
- `sys.adcRasterTime` must be an integer multiple of 2us, except MAGNUS which supports 1us.
- `sys.blockDurationRaster` must be an integer multiple of 4us

### RF/ADC dead- and ringdown-times

Like other vendors, there is some time required to turn on/off the RF amplifier and ADC card.
To our knowledge, on GE these are:

```
Time to turn RF amplifier ON = 72us         # RF dead time
Time to turn RF amplifier OFF = 54us        # RF ringdown time
Time to turn ADC ON = 40us                  # ADC dead time
Time to turn ADC OFF = 0us                  # ADC ringdown time
```

The key thing to note is that the dead/ringdown intervals from one RF/ADC event must not overlap with those from another RF/ADC event.

Also note that these times do NOT necessarily correspond to the values of `rfDeadTime`, `rfRingdownTime`, and `adcDeadTime`
you should use when creating the `.seq` file.
While the Pulseq MATLAB toolbox encourages the insertion of RF/ADC dead/ringdown times at the beginning
and end of each block, this is often not necessary on GE since the block boundaries 'disappear' inside a segment.
It is therefore perfectly ok to override that behavior to make the sequence more time-efficient.

### Examples

Conservative choice, that causes the `+mr` toolbox to insert non-zero delays as needed:

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

A more time-efficient choice:

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

If the latter results in overlapping RF/ADC dead/ringdown times, you need to adjust the timing accordingly
(by, e.g., setting the dead/ringdown times to non-zero values, or setting delays and block durations explicitly, etc).


## Sequence timing 

### Event delays

- gradient event delays must be an integer multiple of 4us
- RF event delays must be an integer multiple of 2us
- ADC event delays must be an integer multiple of 1us

### Segment 'ringdown' time

When loading a segment, the interpreter inserts a 117 us dead time at the end of each segment.

### RF and ADC delays

The interpreter internally offsets RF / ADC timing relative to block boundaries to account for gradient delays.
Depending on details of your sequence, you may need to extend the segment duration to account for this.


## Gradient rotation

**Use rotation events** rather than rotating gradients manually or using the older
`mr.rotate` or `mr.rotate3D` functions (in the core Pulseq toolbox).
Rotation events are a new feature in Pulseq, see https://github.com/pulseq/pulseq/discussions/117.

**NB! The rotation is applied to the entire segment as a whole.**
In other words, the interpreter cannot rotate each block within a segment independently.
If a segment contains multiple blocks with different rotation matrices, **only the last** of the non-identity rotations are applied. 
If you find this to be the case, redesign the segment definitions to achieve the desired rotations.


## Additional recommendations

- **Avoid setting waveform amplitudes to exactly zero -- instead, set to `eps` or a similarly small number.**
This is recommended because the Pulseq toolbox may not recognize, e.g., a zero-amplitude trapezoid
as exactly that, which is in conflict with the GE sequence model. (This may be obsolete -- need to check. TODO)




