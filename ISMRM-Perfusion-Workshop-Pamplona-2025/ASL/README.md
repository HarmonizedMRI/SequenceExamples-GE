# Pulseq ASL sequence, demonstrated on a GE 3T scanner

## Create sequence files

```matlab
>> run sequence/main;
```

## Execute the sequence on a GE scanner

See https://github.com/HarmonizedMRI/SequenceExamples-GE/tree/main/pge2/


## Reconstruct images

1. Put the ScanArchive file in the `./data/` folder and rename it to `data.h5`

2. Edit the file `recon/recon_asl.m`:
   1. Set path to GE's Orcehstra toolbox (download from the GE research user forum)
   2. Set number of runs (opnex). This value is set by the scanner operator.

3. Run nufft reconstruction script:
   ```matlab
   >> run recon/recon_asl;
   ```
4. Save the workspace variable `imsos` to a file named `ims.mat` and place it in the `./data/` folder.


## Perform ASL processing (control-label subtraction)

```matlab
>> run process/main;   % load and display ims.mat
```
