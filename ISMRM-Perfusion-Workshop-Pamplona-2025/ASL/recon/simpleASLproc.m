{\rtf1\ansi\ansicpg1252\cocoartf2761
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww13440\viewh10200\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs28 \cf0 load images.mat\
ims = vims;\
\
dimx = size(ims,1);\
    dimz = size(ims,3);\
    dimt = size(ims,4);\
\
    % detrend the data to remove drift in timeseries\
    ims = reshape(ims, [],dimt);\
    parfor p =1:size(ims,1)\
        s0 = mean(ims(p,:));\
        ims(p,:) = detrend(ims(p,:), 3) + s0;\
    end\
    ims = reshape(ims,[dimx, dimx, dimz, dimt]);\
\
\
    \
    % smooth the data\
    % for n=1:size(ims,4)\
    %     ims(:,:,:,n) = smooth3(ims(:,:,:,n));\
    % end\
    sub = abs(ims(:,:,:, 3:2:end)) - abs(ims(:,:,:, 4:2:end)); % ./ ims(:,:,:,2)/2;\
    %sub = sub(:,:,:,1:2:end) + sub(:,:,:,2:2:end);  % used four frames per phase\
\
    ctl = ims(:,:,:, 3:2:end);\
    lbl = ims(:,:,:, 4:2:end);\
\
\
  % clean up the noise by removing outliers\
    ctl = reshape(ctl, [],dimt/2-1);\
    lbl = reshape(lbl, [],dimt/2-1);\
    for p =1:size(ctl,1)\
        tmp = ctl(p,:);\
        s0 = mean(tmp);\
        sd = std(tmp);\
        inds = find(tmp >  s0 + 1.5*sd);\
\
        ctl(p,inds) = s0;\
\
\
        tmp = lbl(p,:);\
        s0 = mean(tmp);\
        sd = std(tmp);\
        inds = find(tmp >  s0 + 1.5*sd);\
\
        lbl(p,inds) = s0;\
    \
    end\
    ctl = reshape(ctl,[dimx, dimx, dimz, dimt/2-1]);\
    lbl = reshape(lbl,[dimx, dimx, dimz, dimt/2-1]);\
    sub = abs(ctl) - abs(lbl);\
\
\
    mc = mean(ctl,4);\
    ml = mean(lbl,4);\
\
    ms = mean(sub,4);\
    sd = std(sub,[], 4);\
    snrmap = ms ./sd;\
\
\
    subplot(311)\
    orthoview(mc)\
    colorbar\
    title('mean control image')\
\
    subplot(312)\
    orthoview(ms)\
    colorbar\
    caxis([0 1]* 800)\
    title('mean subtraction')\
\
    subplot(313)\
    orthoview(snrmap)\
    colorbar\
    colorbar\
    title('CNR')\
    colormap parula\
\
    figure\
\
    lbview(ms)\
    colorbar\
    caxis([0 1]* 800)\
    title('mean subtraction')\
    colormap parula\
    \
}