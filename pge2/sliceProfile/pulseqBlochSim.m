function [m] = pulseqBlochSim(blocks,sys,fov,doDisplay)
% bloch simulation of pulseq blocks
% inputs:
%   - blocks: cell array of pulseq blocks, each cell element is a cell
%   composed of ONE pulseq rf and ONE Z-gradient event (one of the two could be empty)
%   - sys
%   - fov: (meter)
% example usage:
%   [m] = pulseqBlochSim({{ex.rf,ex.gz},{[],ex.gzReph}})

if nargin < 4
    doDisplay = true;
end


k = numel(blocks);
rfwav = [];
gzwav = [];

for i = 1:k
    assert(~(isempty(blocks{i}{1})&&(isempty(blocks{i}{2}))),sprintf('For the %d-th block: one of the RF/Gradient events should be non-empty!\n',i))
    rfEvent = blocks{i}{1};
    gzEvent = blocks{i}{2};
    
    if ~isempty(rfEvent)
        rf1 = rfBlock2waveform(rfEvent,sys)*1e4;%Gauss
        if ~isempty(gzEvent)
            gz1 = gBlock2waveform(gzEvent,sys)*1e2; % gauss/cm
        else
            gz1 = zeros(1,numel(rf1));
        end
    else
        gz1 = gBlock2waveform(gzEvent,sys)*1e2; % gauss/cm
        rf1 = zeros(1,numel(gz1));
    end

    rfwav = [rfwav rf1]; %Gauss
    gzwav = [gzwav gz1]; %Gauss/cm
end
if numel(rfwav) > numel(gzwav)
    gzwav = [gzwav zeros(1,numel(rfwav)-numel(gzwav))];
elseif numel(rfwav) < numel(gzwav)
    rfwav = [rfwav zeros(1,numel(gzwav)-numel(rfwav))];
end
assert(numel(rfwav) == numel(gzwav),'Number of time points in rf and gz unmatch!')

m0 = [0,0,1];
dt = sys.rfRasterTime*1e3;
T1 = 500; %ms
T2 = 50; %ms
N = 100;
Z = [-N/2+1:N/2].*(fov(3)*100/N);

[m] = toppe.utils.rf.slicesim(m0,rfwav,gzwav,dt,Z,T1,T2,doDisplay);

end


function rfwav = rfBlock2waveform(rf,sys,doDisplay)
% convert pulseq rf block to waveform (including delay)
%   rfwav: [1,nT] (T)
if nargin < 3
    doDisplay = false;
end

dt = sys.rfRasterTime;

rfwav = [zeros(1,round(rf.delay/dt)) rf.signal'];
rfwav = rfwav./sys.gamma;
if doDisplay
    figure;plot((1:size(rfwav,2)).*dt,rfwav)
end

end


function gwav = gBlock2waveform(g,sys,doDisplay)
% convert pulseq trapezoid gradient block to its waveform
%   gwav : [1,nT] (T/m)

if nargin < 3
    doDisplay = false;
end

dt = sys.gradRasterTime;
slew_up = g.amplitude./g.riseTime;
slew_down = -g.amplitude./g.fallTime;

gwav = [zeros(1,round(g.delay/dt)) (0:dt:g.riseTime).*slew_up g.amplitude.*ones(1,round(g.flatTime/dt)) (0:dt:g.fallTime).*slew_down+g.amplitude];
gwav = gwav./sys.gamma;

if doDisplay
    figure;plot((1:size(gwav,2)).*dt,gwav)
end
end
