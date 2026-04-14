# Pulseq on GE v2 (pge2) 

**Table of Contents**  
[Overview](#overview)  
[Workflow](#workflow)  
[Obtaining the software](#obtaining-the-software)  
[Sequence design guidelines](#sequence-design-guidelines)  
[Safety management](#safety-management)  

**(Updated Apr 2026)**


## Overview

This repository contains examples of how to prepare and run
Pulseq sequences on GE scanners using the **Pulseq on GE v2 (pge2)** interpreter.

The workflow is based on a vendor-neutral intermediate representation called **PulSeg**, which converts the Pulseq .seq file into reusable hardware-efficient sequence segments.

The pge2 interpreter directly translates the events specified in the PulSeg representation to the hardware, enabling flexible and efficient sequence execution.  
Because of this low-level control, care must be taken to ensure that timing, rasterization, and hardware constraints are respected.

**Note:** This workflow replaces the earlier PulCeq-based approach.
Functionality has been split into:
 - PulSeg (representation and conversion)
 - pge2 (GE-specific tooling)

---

## Workflow

To execute a Pulseq (`.seq`) file on a GE scanner using the pge2 interpreter, the sequence is first converted into a **PulSeg object**, validated, and then serialized to a `.pge` file.

```mermaid
flowchart LR
A[Create .seq file]
B[Convert to PulSeg object]
C[Check, validate]
D[.pge file]
E[GE scanner]

A --> B
B --> C
C --> D
D --> E
```

The typical workflow is summarized below.
See also [main.m](./2DGRE/main.m) in the [2D GRE demo](./2DGRE/) folder.


### Minimal end-to-end example

```matlab
% Create .seq
write2DGRE;

seq_name = 'gre2d';

% Convert to PulSeg
psq = pulseg.fromSeq([seq_name '.seq']);

% Define system
sys_ge = pge2.opts(...);

% Check
params = pge2.check(psq, sys_ge);

% Validate (strongly recommended before simulation or scanning)
seq = mr.Sequence(); 
seq.read([seq_name '.seq']);
pge2.validate(psq, sys_ge, seq, ...);

% Serialize
pge2.serialize(psq, [seq_name '.pge'], ...);
```

### 1. Create the Pulseq file (`.seq`)

Generate the `.seq` file using standard Pulseq tools.

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
pislquant = 64;  % number of ADC events used to set receive gain in Auto Prescan
save(seq_name, 'psq', 'params', 'pislquant');
```

This `.mat` file can be used in the scanner-side FOV prescription workflow
described [here](https://github.com/HarmonizedMRI/pge2/tree/main/scanner/fov_prescription).

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

Available at: [HarmonizedMRI/PulSeg](https://github.com/HarmonizedMRI/PulSeg)

This repository provides:

* `pulseg.fromSeq` (Pulseq → PulSeg conversion)
* Definition of the PulSeg representation

### 2. pge2 MATLAB toolbox

Available at: [HarmonizedMRI/pge2](https://github.com/HarmonizedMRI/pge2)

This toolbox provides:

* Visualization: `pge2.plot`

* Validation: `pge2.check`, `pge2.validate`

* Serialization: `pge2.serialize`


### 3. GE interpreter (EPIC)

Available at: [GEHC-External/pulseq-ge-interpreter](https://github.com/GEHC-External/pulseq-ge-interpreter)


(Contact GE for access)

That site also contains instructions for simulating the `.pge` sequence and executing it on the scanner.


## Sequence design guidelines

Because pge2 directly maps Pulseq events to GE hardware, Pulseq files must satisfy several structural and timing constraints.
For full sequence design rules, examples, and hardware caveats, see: [docs/pge2-sequence-design-rules.md](docs/pge2-sequence-design-rules.md)

Key sequence design constraints:

### Segment structure

- Segment boundaries are defined by TRID labels.
- The first instance of a TRID defines the segment structure.
- All later instances must have the same block / event structure.
- Use separate TRIDs for logically distinct sequence sections/elements.

### Reusable events

- Define RF / gradient events outside loops when possible.
- Reuse / scale base events instead of regenerating them each TR.

### Timing

- Respect GE raster constraints:
   - grad: 4 us
   - RF: 2 us
   - ADC: 2 us (1 us on MAGNUS)
- Avoid overlapping RF / ADC dead/ringdown intervals.
- Variable delay blocks are allowed, but must avoid SSP timing conflicts.

### Segmentation best practice

- Keep segments reasonably short.
- Avoid too many unique segment types.


## Safety management

### Peripheral nerve stimulation (PNS)

PNS checks are integrated into:

```matlab
pge2.check()
```

You can also evaluate PNS directly using:

```
pge2.pns()
```


### Mechanical resonances (forbidden EPI spacings)

GE scanners specify forbidden EPI echo spacings corresponding to mechanical resonances that must be avoided.

These are listed on the scanner in:

```
/srv/nfs/psd/etc/epiesp*.dat
```

Consult your GE representative to determine the appropriate file for your system.

The forbidden frequencies can be incorporated into sequence design using the Pulseq function:

```matlab
seq.gradSpectrum(...)
```

See [2DGRE/main.m](2DGRE/main.m) for an example.

> [!NOTE]
> pge2.check does not automatically read these .dat files from the scanner; the user must manually input those frequencies into their Pulseq script using seq.gradSpectrum. 




### Gradient and RF subsystem protection, and patient SAR

Safety limits for gradient heating and RF power (including SAR) are enforced by the interpreter using a sliding-average estimation.

Specifically:

* The interpreter evaluates the **first 40,000 blocks** of the sequence (or the full sequence, if shorter)

* Gradient and RF power in the remainder of the sequence must **not exceed** this level

This limit arises from internal memory constraints and has been determined empirically.

It is the user's responsibility to ensure compliance beyond the evaluated window.


## Troubleshooting

For common pitfalls (segment mismatches, timing issues, missing signal), see the detailed sequence design rules.


