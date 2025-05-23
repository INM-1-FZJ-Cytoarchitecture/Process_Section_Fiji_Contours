function results = process_roi(roiPaths, speciesIDs, debug_mode)
%PROCESS_ROI Load ROI files, extract ImageIDs, create masks, calculate areas,
%            and return a fixed‐schema table with file paths and metadata
%
%   results = process_roi(roiPaths, speciesIDs, debug_mode) takes:
%     • roiPaths    : cell array of full paths to ROI ZIP files
%     • speciesIDs  : cell array of three‐digit ID strings (e.g. {'001','011', …})
%     • debug_mode  : logical (default = false)
%                    If true, prints warnings and detailed processing info.
%                    If false, only returns the summary table.
%
%   Returns a table with columns:
%     rootName    – string: specimen folder name
%     rootPath    – string: path to specimen folder
%     filePath    – string: full path to ROI ZIP file
%     speciesPath – string: full path to Species TIFF image
%     maskPath    – string: full path to written mask TIFF
%     ImageID     – string: three‐digit ImageID
%     numROIs     – double: number of ROIs in that file
%     Gray        – double: pixel count for code 1
%     White       – double: pixel count for code 2
%     Cerebellum  – double: pixel count for code 3
%     Archicortex – double: pixel count for code 0 (only‐outer regions)

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

    %% Prepare empty fixed‐schema table with metadata
    varNames = {'rootName','rootPath','filePath','speciesPath','maskPath', ...
                'ImageID','numROIs','NeocorticalGM','White','Cerebellum','ArchicorticalGM'};
    varTypes = {'string','string','string','string','string', ...
                'string','double','double','double','double','double'};
    results = table('Size',[0,numel(varNames)], ...
                    'VariableTypes',varTypes, ...
                    'VariableNames',varNames);

    %% Loop over ROI archives
    for k = 1:numel(roiPaths)
        thisPath = roiPaths{k};  % ROI file path

        % 1) Extract three‐digit ImageID
        [~, fname] = fileparts(thisPath);
        tok = regexp(fname, '^.+_(\d{3})_roi$', 'tokens','once');
        if isempty(tok)
            if debug_mode
                warning('process_roi:BadFilename', 'Cannot parse ImageID from "%s". Skipping.', fname);
            end
            continue;
        end
        sid = tok{1};

        % 2) Validate ImageID
        if ~any(strcmp(speciesIDs, sid))
            if debug_mode
                warning('process_roi:IDNotFound','ImageID "%s" not in speciesIDs. Skipping.', sid);
            end
            continue;
        end

        % 3) Read ROI file
        try
            raw = ReadImageJROI(thisPath);
        catch ME
            if debug_mode
                warning('process_roi:ReadFailed','Failed to read "%s": %s', thisPath, ME.message);
            end
            continue;
        end
        if iscell(raw)
            rois = [raw{:}];
        else
            rois = raw;
        end

        % 4) Annotate ROIs and derive metadata paths
        zipFolder  = fileparts(thisPath);
        parentDir  = fileparts(zipFolder);
        rootFolder = fileparts(parentDir);
        [~, rootName] = fileparts(rootFolder);
        % Species image path
        speciesFile = sprintf('%s_%s.tif', rootName, sid);
        speciesPath = fullfile(rootFolder, 'Species', rootName, speciesFile);
        % Mask output path
        maskFolder = fullfile(rootFolder, 'masks');
        maskName   = sprintf('%s_%s_mask.tif', rootName, sid);
        maskPath   = fullfile(maskFolder, maskName);

        for i = 1:numel(rois)
            rois(i).rootPath  = rootFolder;
            rois(i).roiPath   = thisPath;
            rois(i).rootName  = rootName;
            rois(i).speciesID = sid;
        end

        % 5) Debug: list contour names
        if debug_mode
            names = {rois.strName};
            fprintf('In "%s" (ID=%s) found contours:\n', thisPath, sid);
            fprintf('  - %s\n', names{:});
        end

        % 6) Create mask (writes to disk)
        try
            mask = create_mask(rois);
        catch ME
            if debug_mode
                warning('process_roi:MaskFailed','Mask creation failed for "%s": %s', fname, ME.message);
            end
            continue;
        end

        % 7) Calculate areas (fixed schema)
        try
            tbl = calculate_areas(mask);  % expects Gray,White,Cerebellum,Archicortex
            for f = {'NeocorticalGM','White','Cerebellum','ArchicorticalGM'}
                if ~ismember(f{1}, tbl.Properties.VariableNames)
                    tbl.(f{1}) = 0;
                end
            end
        catch ME
            if debug_mode
                warning('process_roi:AreaFailed','Area calculation failed for "%s": %s', fname, ME.message);
            end
            tbl = table(0,0,0,0,'VariableNames',{'NeocorticalGM','White','Cerebellum','ArchicorticalGM'});
        end

        % 8) Count ROIs
        nROIs = numel(rois);

        % Assemble one‐row result
        newRow = table(string(rootName), string(rootFolder), string(thisPath), ...
                       string(speciesPath), string(maskPath), ...
                       string(sid), nROIs, tbl.NeocorticalGM, tbl.White, tbl.Cerebellum, tbl.ArchicorticalGM, ...
                       'VariableNames',varNames);

        % Ensure masks folder exists
        if ~isfolder(maskFolder)
            mkdir(maskFolder);
        end

        % Append
        results = [results; newRow];

        % Debug: per‐file printout
        if debug_mode
            fprintf('Processed "%s": %d ROIs → NeocorticalGM=%d, White=%d, Cerebellum=%d, ArchicorticalGM=%d\n', ...
                    fname, nROIs, newRow.NeocorticalGM, newRow.White, newRow.Cerebellum, newRow.ArchicorticalGM);
        end
    end

        %% (Optional) display final table when not in debug mode
    if ~debug_mode
        % Final summary using table indexing
        for i = 1:height(results)
            fp   = results.filePath(i);
            sid  = results.ImageID(i);
            n    = results.numROIs(i);
            [~, fname] = fileparts(fp);
            if n == 0
                fprintf('%s	%s	Warning: no or wrong labeled ROIs found', fname, sid);
            else
                fprintf('%s	%s	N RoIs: [%d] \n', fname, sid, n);
            end
        end
    end
end
