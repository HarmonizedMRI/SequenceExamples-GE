% ORC_READ read in k-space data from GE ScanArchive files using GE Orchestra
function ksp = orc_read(fn)
    archive = GERecon('Archive.Load', fn);
    shot = GERecon('Archive.Next', archive);
    [Nfid, Ncoils] = size(shot.Data);

    ksp = zeros(Nfid, Ncoils, archive.FrameCount);
    ksp(:,:,1) = shot.Data;
    for acq = 2:archive.FrameCount
        try
            shot = GERecon('Archive.Next', archive);
            ksp(:,:,acq) = shot.Data;
        catch
            fprintf('Loading failed at acquistion #%d', acq)
        end
    end
end