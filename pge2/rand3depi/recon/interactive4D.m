function interactive4D(data)
% INTERACTIVE4DGALLERYSCROLLBAR Interactive 4D viewer with scrollbar
%   Displays each 3D volume as a gallery of slices
%   Use scrollbar or mouse scroll to move through time

    % Create figure
    fig = figure('Name', '4D Volume Gallery', 'NumberTitle', 'off', ...
                 'WindowScrollWheelFcn', @scrollCallback);

    % Create axes
    ax = axes('Parent', fig, 'Position', [0.05 0.15 0.9 0.8]);

    % Create frame number text
    frameText = uicontrol('Style', 'text', ...
                          'Parent', fig, ...
                          'Units', 'normalized', ...
                          'Position', [0.4 0.95 0.2 0.04], ...
                          'String', '', ...
                          'FontSize', 12, ...
                          'BackgroundColor', fig.Color, ...
                          'HorizontalAlignment', 'center');

    % Create scrollbar
    scrollBar = uicontrol('Style', 'slider', ...
                          'Parent', fig, ...
                          'Units', 'normalized', ...
                          'Position', [0.05 0.05 0.9 0.05], ...
                          'Min', 1, 'Max', size(data, 4), ...
                          'Value', 1, ...
                          'SliderStep', [1/(size(data,4)-1) , 10/(size(data,4)-1)], ...
                          'Callback', @sliderCallback);

    % Store data
    handles.data = data;
    handles.ax = ax;
    handles.currentTime = 1;
    handles.maxTime = size(data, 4);
    handles.frameText = frameText;
    handles.scrollBar = scrollBar;
    guidata(fig, handles);

    % Initial plot
    plotGallery(fig);
end

function scrollCallback(src, event)
% SCROLLCALLBACK Handle mouse scroll
    handles = guidata(src);
    if event.VerticalScrollCount > 0
        handles.currentTime = min(handles.currentTime + 1, handles.maxTime);
    else
        handles.currentTime = max(handles.currentTime - 1, 1);
    end
    set(handles.scrollBar, 'Value', handles.currentTime);
    guidata(src, handles);
    plotGallery(src);
end

function sliderCallback(src, ~)
% SLIDERCALLBACK Handle scrollbar movement
    fig = ancestor(src, 'figure');
    handles = guidata(fig);
    handles.currentTime = round(get(src, 'Value'));
    guidata(fig, handles);
    plotGallery(fig);
end

function plotGallery(fig)
% PLOTGALLERY Update the plot based on current time frame
    handles = guidata(fig);

    if ~isvalid(handles.ax)
        return;
    end

    volumeData = handles.data(:, :, :, handles.currentTime);
    numSlices = size(volumeData, 3);

    nCols = ceil(sqrt(numSlices));
    nRows = ceil(numSlices / nCols);

    volumeData = mat2gray(volumeData);

    [sx, sy, ~] = size(volumeData);
    canvas = ones(nRows * sx, nCols * sy);

    for idx = 1:numSlices
        row = floor((idx-1) / nCols);
        col = mod((idx-1), nCols);
        xIdx = (row*sx + 1):(row*sx + sx);
        yIdx = (col*sy + 1):(col*sy + sy);
        canvas(xIdx, yIdx) = volumeData(:, :, idx);
    end

    imagesc(handles.ax, canvas);
    axis(handles.ax, 'image', 'off');
    colormap(handles.ax, gray);

    % Update frame number text
    if isfield(handles, 'frameText') && isvalid(handles.frameText)
        set(handles.frameText, 'String', sprintf('Frame %d / %d', handles.currentTime, handles.maxTime));
    end

    drawnow;
end
