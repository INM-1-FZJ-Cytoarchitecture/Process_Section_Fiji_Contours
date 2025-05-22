function mask = create_mask(rois)
%CREATE_MASK Generate labeled tissue mask based on ordered ROI suffix priorities
%
%   mask = CREATE_MASK(rois) reads the TIFF image corresponding to the
%   first ROI in the struct array, determines its dimensions, and returns
%   a 2D numeric mask where each pixel is coded by tissue type:
%     1 = gray matter (#g or #i)
%     2 = white matter (#w)
%     3 = cerebellum (#c)
%     0 = background / non-tissue (#o overrides any previous)
%
%   Priority (fill order):
%     1) Gray matter (#g, #i)
%     2) White matter (#w)
%     3) Cerebellum (#c)
%     4) Only_outer (#o) — override to 0
%
%   Input:
%     rois : struct array with fields:
%       • strName       – ROI name ending in one of: #g,#i,#w,#c,#o
%       • mnCoordinates – N×2 array [x y]
%       • rootPath      – top-level folder of specimen
%       • rootName      – specimen folder name
%       • speciesID     – ID token for image filename
%
%   Output:
%     mask : uint8 2D array of size matching the TIFF image
%
%   Special cases & testing suggestions:
%     • Overlaps: #o regions nested inside tissue areas should be cleared.
%     • Inner ROIs (#i) get gray-matter code even if embedded.
%     • Automate with small shapes: create synthetic rois and assert unique codes.
%     • Test mask dimensions, unique(mask), and boundary completeness.
%
%   See also imread, poly2mask, regionprops

    %% Validate input
    if ~isstruct(rois) || isempty(rois)
        error('create_mask:InvalidInput', 'Expect non-empty struct array of ROIs.');
    end

    %% Identify image for sizing
    meta = rois(1);
    imageName = sprintf('%s_%s.tif', meta.rootName, meta.speciesID);
    imagePath = fullfile(meta.rootPath, 'Species', meta.rootName, imageName);
    img = imread(imagePath);               % may error if missing
    [h, w, ~] = size(img);
    mask = zeros(h, w, 'uint8');           % init all zeros

    %% Helper to extract suffix
    function s = getSuffix(name)
        tok = regexp(name, '#.$', 'match', 'once');
        if isempty(tok), error('Invalid ROI name %s', name); end
        s = tok;
    end

    %% 1) Gray matter (#g and #i)
    for i = 1:numel(rois)
        suf = getSuffix(rois(i).strName);
        if any(strcmp(suf, {'#g', '#i'}))
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 1;
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

    %% 4) Only_outer (#o) — override all to zero
    for i = 1:numel(rois)
        if strcmp(getSuffix(rois(i).strName), '#o')
            coords = rois(i).mnCoordinates;
            pm = poly2mask(coords(:,1), coords(:,2), h, w);
            mask(pm) = 0;
        end
    end
end
