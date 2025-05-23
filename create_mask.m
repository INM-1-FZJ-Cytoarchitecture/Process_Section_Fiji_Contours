function mask = create_mask(rois)
%CREATE_MASK Generate labeled tissue mask based on ordered ROI suffix priorities
%
%   mask = CREATE_MASK(rois) reads the TIFF image corresponding to the
%   first ROI in the struct array, determines its dimensions, builds a
%   labeled mask, and writes the result to disk:
%     1 = NeocorticalGM (#g or #i)
%     2 = white matter (#w)
%     3 = cerebellum (#c)
%     4 = ArchicorticalGM (#a)
%     0 = background / non-tissue (#o overrides any previous)
%
%   Priority (fill order):
%     1) NeocorticalGM (#g, #i)
%     2) ArchicorticalGM (#a)
%     3) White matter (#w)
%     4) Cerebellum (#c)
%     5) Only_outer (#o) — override to 0
%
%   Input:
%     rois : struct array with fields:
%       • strName       – ROI name ending in one of: #g,#i,#w,#c,#o
%       • mnCoordinates – N×2 array [x y]
%       • rootPath      – top-level specimen folder
%       • rootName      – specimen folder name (Specimen ID)
%       • speciesID     – three-digit image ID for filename
%
%   Output:
%     mask : uint8 2D array of size matching the TIFF image
%
%   Side effects:
%     - Creates a folder `<rootPath>/masks` if it does not exist.
%     - Writes the mask image as `<rootName>_<speciesID>_mask.tif`.
%     - Errors if writing fails.
%
%   See also imread, poly2mask, imwrite

    %% Validate input
    if ~isstruct(rois) || isempty(rois)
        error('create_mask:InvalidInput', ...
              'Expect non-empty struct array of ROIs.');
    end

    %% Load the first image to get dimensions
    meta = rois(1);
    imageName = sprintf('%s_%s.tif', meta.rootName, meta.speciesID);
    imagePath = fullfile(meta.rootPath, 'Species', meta.rootName, imageName);
    try
        img = imread(imagePath);
    catch ME
        error('create_mask:ImageReadFailed', ...
              'Could not read image "%s": %s', imagePath, ME.message);
    end
    [h, w, ~] = size(img);

    %% Initialize mask
    mask = zeros(h, w, 'uint8');  % all zeros (background)

    %% Helper to extract suffix
    function s = getSuffix(name)
        tok = regexp(name, '#.$', 'match', 'once');
        if isempty(tok)
            error('create_mask:InvalidName', 'Invalid ROI name "%s".', name);
        end
        s = tok;
    end

    %% 1) Gray matter (#g)
    for i = 1:numel(rois)
        if strcmp(getSuffix(rois(i).strName), '#g')
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 1;
        end
    end

    %% 1) Gray matter (#g)
    for i = 1:numel(rois)
        if strcmp(getSuffix(rois(i).strName), '#a')
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 4;
        end
    end

    %% 2) White matter (#w)
    for i = 1:numel(rois)
        if strcmp(getSuffix(rois(i).strName), '#w')
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 2;
        end
    end

    %% 3) Cerebellum (#c)
    for i = 1:numel(rois)
        if strcmp(getSuffix(rois(i).strName), '#c')
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 3;
        end
    end

    %% 4) Inner gray matter (#i)
    for i = 1:numel(rois)
        if strcmp(getSuffix(rois(i).strName), '#i')
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 1;
        end
    end

    %% 5) Only_outer (#o) — override all to zero
    for i = 1:numel(rois)
        if strcmp(getSuffix(rois(i).strName), '#o')
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 0;
        end
    end

    %% Write mask to disk
    maskFolder = fullfile(meta.rootPath, 'masks');
    if ~isfolder(maskFolder)
        mkdir(maskFolder);
    end
    [~, baseName, ~] = fileparts(imageName);
    maskName = sprintf('%s_mask.tif', baseName);
    maskPath = fullfile(maskFolder, maskName);

    try
        imwrite(mask, maskPath, 'tif');
    catch ME
        error('create_mask:WriteFailed', ...
              'Could not write mask to "%s": %s', maskPath, ME.message);
    end
end
