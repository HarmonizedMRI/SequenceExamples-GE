%================================================================================
% Pinv-Recon: 
% Generalized MR Image Reconstruction via Pseudoinversion of the Encoding Matrix. 
% https://arxiv.org/pdf/2410.06129
%
% (C) ... Florian.Wiesinger@gmail.com
%================================================================================

%  addpath(genpath(OxMatlab')) % requires Matlab Ox (GERecon) 
%fn='newDATA\Series5\ScanArchive_GE1100MR01_20250205_102935871.h5';
fn = 'data.h5';
arc=GERecon('Archive.Load',fn); clear DATA
for iread=1:arc.ControlCount
    ctrl=GERecon('Archive.Next',arc,'raw');
    if ctrl.opcode==1
        DATA(:,:,ctrl.FrameInfo.SequenceNumber+1)=ctrl.Data;
    end
end
[Nread,Nrcv,Nint]=size(DATA);
GERecon('Archive.Close',arc);
% ScanArchive Header parameters for offcenter correction (optional)
dfov=arc.DownloadData.rdb_hdr_image.dfov;           % prescribed FOV
dfov_Roff=arc.DownloadData.rdb_hdr_image.ctr_R;     % RL off-center
dfov_Aoff=arc.DownloadData.rdb_hdr_image.ctr_A;     % AP off-center
dfov_Soff=arc.DownloadData.rdb_hdr_image.ctr_S;     % SI off-center

% mtx, g, gradSpiral from writeIntSpiralFW.m
nDATA=length(g);
Kx0=cumsum(gradSpiral(1,1:nDATA)); 
Ky0=cumsum(gradSpiral(2,1:nDATA));
Kx=[]; Ky=[];
for iint=1:Nint
    phi=-2*pi*(iint-1)/Nint;   % changed sign to match pge2 rotation (JFN)
    Kx=[Kx,+Kx0*cos(phi)+Ky0*sin(phi)];
    Ky=[Ky,-Kx0*sin(phi)+Ky0*cos(phi)];
end
kmax=max(sqrt(Kx.^2+Ky.^2)); Kx=64*Kx/kmax; Ky=64*Ky/kmax;

TMP=linspace(0.5,-0.5,mtx+1); [Rx,Ry]=ndgrid(TMP(1:end-1)); 
Rx=Rx+1*(dfov_Aoff/dfov); % AP offcenter correction
Ry=Ry+1*(dfov_Roff/dfov); % RL offcenter correction

% MR image reconstruction via direct matrix inversion:
% data=Encode*image <-> image=Encode^(-1)*data
fprintf('encoding matrix...'); tic;
Encode=single(exp(1i*2*pi*(Kx(:)*Rx(:).'+Ky(:)*Ry(:).')));
fprintf(' %.1fs\n', toc);
fprintf('EHE...'); tic;
EHE=Encode'*Encode; normE=normest(Encode);
fprintf(' %.1fs\n', toc);
% Cholesky decomposition based matrix inversion 
% including Tikhonov regularization
fprintf('Cholesky...'); tic;
[L,flag]=chol(EHE+1e-1*normE*eye(size(EHE)),'lower'); 
fprintf(' %.1fs\n', toc);
fprintf('invert...'); tic;
invL=inv(L); clear L; iEHE=invL'*invL; clear invL;
fprintf(' %.1fs\n', toc);
% Recon=iEHE*E';

ioffDATA=1;  % Gradient-ACQ alignment 
intDATA=reshape(permute(DATA((1:nDATA)+ioffDATA,:,:),[1,3,2]), nDATA*Nint, []);
fprintf('recon...'); tic;
iIMAGE=iEHE*(Encode'*intDATA);
fprintf(' %.1fs\n', toc);
sosIMAGE=reshape(sqrt(sum(iIMAGE.*conj(iIMAGE),2)),[mtx,mtx]);
figure(99), imshow(sosIMAGE,[]); title('interleaved Spiral')
