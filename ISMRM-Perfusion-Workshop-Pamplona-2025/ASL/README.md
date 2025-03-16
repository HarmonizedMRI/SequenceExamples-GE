# Pulseq ASL sequence, demonstrated on a GE 3T scanner

## Create sequence files

```matlab
>> run sequence/main;
```

## Execute the sequence on a GE scanner

See https://github.com/HarmonizedMRI/SequenceExamples-GE/tree/main/pge2/


## Reconstruct images

1. Put the ScanArchive file in the `./data/` folder and rename to `data.h5`
2. Set number of runs (opnex) in the file `recon/recon_asl.m`
3. Run nufft reconstruction:
   ```matlab
   >> run recon/recon_asl;
   ```

## Perform ASL processing (control-label subtraction)
