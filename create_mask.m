function success = create_mask(rois)
%CREATE_MASK Save individual binary masks for each ROI tag.
%
%   Logic:
%   - Iterates through all ROIs.
%   - Creates a binary TIFF (1=inside, 0=outside) for each.
%   - Handles naming conflicts:
%       - Single occurance: "Name_#tag_mask.tif"
%       - Multiple occurance: "Name_#tag_1_mask.tif", "Name_#tag_2_mask.tif"
%   - Robustly handles Rectangles, Ovals, and coordinate boundaries.
%
%   Returns:
%     success : logical true if no fatal errors occurred.

    success = false;

    %% 1. Validate input
    if ~isstruct(rois) || isempty(rois)
        error('create_mask:InvalidInput', 'Expect non-empty struct array of ROIs.');
    end

    %% 2. Load the base image to get dimensions
    meta = rois(1);
    if ~isfield(meta, 'rootPath') || ~isfield(meta, 'rootName')
        error('create_mask:MissingMetadata', 'ROIs struct missing rootPath or rootName.');
    end
    
    imageName = sprintf('%s_%s.tif', meta.rootName, meta.speciesID);
    imagePath = fullfile(meta.rootPath, 'Species', meta.rootName, imageName);
    
    try
        img = imread(imagePath);
    catch ME
        error('create_mask:ImageReadFailed', 'Could not read image "%s": %s', imagePath, ME.message);
    end
    
    [h, w, ~] = size(img);
    
    %% 3. Prepare Output Folder
    maskFolder = fullfile(meta.rootPath, 'masks');
    if ~isfolder(maskFolder)
        mkdir(maskFolder);
    end

    %% 4. Pre-Scan: Count occurrences of each tag
    % We need this to decide if we append a running number (_1, _2) or not.
    tagCounts = containers.Map();
    roiTags   = cell(numel(rois), 1); % Store tags to save time later

    for i = 1:numel(rois)
        tag = getSuffixRobust(rois(i).strName);
        roiTags{i} = tag; % Remember for loop below
        
        if ~isempty(tag)
            if isKey(tagCounts, tag)
                tagCounts(tag) = tagCounts(tag) + 1;
            else
                tagCounts(tag) = 1;
            end
        end
    end
    
    %% 5. Processing Loop: Generate and Write Masks
    % Running counters for the current index
    currentCounts = containers.Map(); 
    
    for i = 1:numel(rois)
        thisRoi = rois(i);
        tag = roiTags{i};
        
        if isempty(tag)
            fprintf('  WARN: ROI "%s" has no valid hashtag. Skipping.\n', thisRoi.strName);
            continue;
        end
        
        % Update running counter
        if isKey(currentCounts, tag)
            currentCounts(tag) = currentCounts(tag) + 1;
        else
            currentCounts(tag) = 1;
        end
        currIdx = currentCounts(tag);
        totalForTag = tagCounts(tag);
        
        % --- A. Extract Coordinates (Robust) ---
        [coords, errMsg] = getRoiCoordinates(thisRoi);
        if ~isempty(errMsg)
            fprintf('  WARN: Skipping ROI "%s": %s\n', thisRoi.strName, errMsg);
            continue;
        end
        
        if isempty(coords)
            continue; 
        end
        
        % --- B. Clamp Coordinates (Safety) ---
        X = coords(:, 1);
        Y = coords(:, 2);
        X(X < 1) = 1; X(X > w) = w;
        Y(Y < 1) = 1; Y(Y > h) = h;
        
        % --- C. Create Binary Mask ---
        mask = poly2mask(X, Y, h, w);
        % Convert to logical/uint8 (0 and 1)
        mask = uint8(mask); 
        
        % --- D. Construct Filename ---
        % Logic: If total > 1, use numbering. If total == 1, just the tag.
        % Example: "Specimen_001_#vc_1_mask.tif" vs "Specimen_001_#t_mask.tif"
        
        [~, baseName, ~] = fileparts(imageName); % e.g. Alouatta_1172_001
        
        if totalForTag > 1
            fileName = sprintf('%s_%s_%d_mask.tif', baseName, tag, currIdx);
        else
            fileName = sprintf('%s_%s_mask.tif', baseName, tag);
        end
        
        outPath = fullfile(maskFolder, fileName);
        
        % --- E. Write to Disk ---
        try
            imwrite(mask, outPath, 'tif', 'Compression', 'lzw');
            % fprintf('    Saved: %s\n', fileName); % Optional: verbose output
        catch ME
            fprintf('  ERROR: Could not write "%s": %s\n', fileName, ME.message);
        end
    end
    
    success = true;
end

%% ---------------- Helper Functions ---------------- %%

function s = getSuffixRobust(name)
    % Extracts suffix like #t, #vc, #gi from string end.
    % Case insensitive, handles 1 or 2 letters.
    if isempty(name)
        s = ''; return;
    end
    % Regex: Matches # followed by 1 or 2 letters at the end of string
    tok = regexp(name, '#([a-zA-Z0-9]{1,2})$', 'match', 'once');
    s = lower(tok); 
end

function [coords, errMsg] = getRoiCoordinates(roi)
    % Extracts XY coordinates regardless of ROI type (Rect, Oval, Polygon)
    coords = [];
    errMsg = '';
    
    try
        switch roi.strType
            case {'Polygon', 'Freehand', 'Traced', 'PolyLine', 'FreeLine'}
                if isfield(roi, 'mnCoordinates')
                    coords = roi.mnCoordinates;
                else
                    errMsg = 'Field mnCoordinates missing.';
                end
                
            case {'Rectangle', 'Oval'}
                % Convert Bounding Box to Polygon
                if isfield(roi, 'vnRectBounds')
                    b = roi.vnRectBounds; 
                    top=b(1); left=b(2); bottom=b(3); right=b(4);
                    coords = [left, top; right, top; right, bottom; left, bottom];
                else
                    errMsg = 'Field vnRectBounds missing.';
                end
                
            case 'Point'
                % Points don't make masks usually, but handled to avoid crash
                if isfield(roi, 'mfCoordinates')
                    coords = roi.mfCoordinates;
                elseif isfield(roi, 'mnCoordinates')
                    coords = roi.mnCoordinates;
                else
                    errMsg = 'No coordinates found for Point.';
                end
                
            otherwise
                % Fallback
                if isfield(roi, 'mnCoordinates')
                    coords = roi.mnCoordinates;
                else
                    errMsg = sprintf('Unsupported ROI type "%s".', roi.strType);
                end
        end
        
        if ~isempty(coords) && size(coords, 2) ~= 2
            errMsg = 'Invalid coordinate dimensions. Expecting Nx2.';
            coords = [];
        end
        
    catch ME
        errMsg = sprintf('Error extraction: %s', ME.message);
    end
end