function results = process_roi(roiPaths, speciesIDs, debug_mode)
%PROCESS_ROI Load ROI files, extract ImageIDs, list contours, create masks, and calculate areas
%
%   results = process_roi(roiPaths, speciesIDs, debug_mode) takes:
%     • roiPaths    : cell array of full paths to ROI ZIP files
%     • speciesIDs  : cell array of three-digit ID strings (e.g. {'001','011', …})
%     • debug_mode  : logical (default = false)
%                    If true, prints warnings and detailed processing info.
%                    If false, suppresses warnings and per-file output,
%                    showing only the summary at the end.
%
%   For each ROI archive, it:
%     1. Extracts the three-digit ImageID from the ZIP filename.
%     2. Validates that ImageID is in speciesIDs.
%     3. Reads the ROIs via ReadImageJROI.
%     4. Annotates ROI structs with paths, rootName, and ImageID.
%     5. (Debug only) Lists contour names and prints processing info.
%     6. Calls create_mask on the ROI set.
%     7. Calculates areas via calculate_areas.
%
%   Returns a struct array results(k) with fields:
%     • filePath   – ROI ZIP path
%     • speciesID  – three-digit ImageID
%     • numROIs    – number of ROIs in file
%     • areas      – vector of computed areas

    %% Handle default debug_mode
    if nargin < 3 || isempty(debug_mode)
        debug_mode = false;
    end

    %% Input validation
    if ~iscell(roiPaths) && ~isstring(roiPaths)
        error('process_roi:InvalidInput', 'roiPaths must be a cell or string array.');
    end
    if ~iscell(speciesIDs) && ~isstring(speciesIDs)
        error('process_roi:InvalidInput', 'speciesIDs must be a cell or string array.');
    end
    roiPaths   = cellstr(roiPaths);
    speciesIDs = cellstr(speciesIDs);

    nFiles = numel(roiPaths);
    results = struct('filePath',  cell(nFiles,1), ...
                     'speciesID', cell(nFiles,1), ...
                     'numROIs',   cell(nFiles,1), ...
                     'areas',     cell(nFiles,1));

    %% Loop over ROI archives
    for k = 1:nFiles
        thisPath = roiPaths{k};
        results(k).filePath = thisPath;

        % 1) Extract three-digit ImageID
        [~, fname] = fileparts(thisPath);
        tok = regexp(fname, '^.+_(\d{3})_roi$', 'tokens', 'once');
        if isempty(tok)
            if debug_mode
                warning('process_roi:BadFilename', 'Cannot parse ImageID from "%s". Skipping.', fname);
            end
            continue;
        end
        sid = tok{1};
        results(k).speciesID = sid;

        % 2) Check ImageID
        if ~any(strcmp(speciesIDs, sid))
            if debug_mode
                warning('process_roi:IDNotFound', 'ImageID "%s" not in speciesIDs. Skipping.', sid);
            end
            continue;
        end

        % 3) Read ROIs
        try
            raw = ReadImageJROI(thisPath);
        catch ME
            if debug_mode
                warning('process_roi:ReadFailed', 'Failed to read "%s": %s', thisPath, ME.message);
            end
            continue;
        end
        if iscell(raw), rois = [raw{:}]; else rois = raw; end

        % 4) Annotate ROIs
        zipFolder   = fileparts(thisPath);
        parentDir   = fileparts(zipFolder);
        rootFolder  = fileparts(parentDir);
        [~, rootName] = fileparts(rootFolder);
        for i = 1:numel(rois)
            rois(i).rootPath  = rootFolder;
            rois(i).roiPath   = thisPath;
            rois(i).rootName  = rootName;
            rois(i).speciesID = sid;
        end

        % 5) Debug: list contours
        if debug_mode
            names = {rois.strName};
            fprintf('In "%s" (ID=%s) found contours:\n', thisPath, sid);
            fprintf('  - %s\n', names{:});
        end

        % 6) Create mask
        try
            mask = create_mask(rois);
        catch ME
            if debug_mode
                warning('process_roi:MaskFailed', 'Mask creation failed for "%s": %s', fname, ME.message);
            end
            continue;
        end

                % 7) Compute areas from mask (counts of each tissue code)
        try
            areas = calculate_areas(mask);
        catch ME
            if debug_mode
                warning('process_roi:AreaFailed', ...
                    'Area calculation failed for "%s": %s', fname, ME.message);
            end
            areas = struct();
        end
        nROIs=size(rois,2);
        results(k).numROIs = nROIs;
        results(k).areas   = areas;

        % Debug: print per-file summary
        if debug_mode
            fprintf('Processed "%s": %d ROIs → areas = [%s]\n\n', fname, nROIs, num2str(areas));
        end
    end

    %% Final summary
    disp(['Summary for specimen: ' rootName]);
    for k = 1:numel(results)
        [~, fname] = fileparts(results(k).filePath);
        sid = results(k).speciesID;
        n   = results(k).numROIs;
        if isempty(n) || n == 0
            fprintf('%s\t%s\tWarning: no or wrong labeled ROIs found\n', fname, sid);
        else
            fprintf('%s\t%s\tN RoIs: [%d]\n', fname, sid, n);
        end
    end
end
