function results = process_roi(roiPaths, speciesIDs)
%PROCESS_ROI Load ROI files, tag with species ID and paths, list contour names,
%             create masks, and calculate areas
%
%   results = process_roi(roiPaths, speciesIDs) takes:
%     • roiPaths    : cell array of full paths to ROI ZIP files
%     • speciesIDs  : cell array of ID tokens (e.g. {'011','012', …})
%
%   For each ROI archive, it:
%     1. Determines the specimen root folder and rootName.
%     2. Matches one speciesID based on the filename.
%     3. Reads the ROIs via ReadImageJROI.
%     4. Annotates each ROI struct with:
%          - rootPath   : top-level specimen folder
%          - roiPath    : full path to this ZIP
%          - rootName   : name of the specimen folder
%          - speciesID  : matched ID token
%     5. Lists contour names.
%     6. Creates an empty mask for each ROI (using create_mask).
%     7. Calculates area (calculate_areas).
%
%   Returns a struct array results(k) with fields:
%     • filePath   – ROI ZIP path
%     • speciesID  – matched ID token
%     • numROIs    – number of ROIs in file
%     • areas      – vector of computed areas

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
    results = struct(...
        'filePath',  cell(nFiles,1), ...
        'speciesID', cell(nFiles,1), ...
        'numROIs',   cell(nFiles,1), ...
        'areas',     cell(nFiles,1) ...
    );

    %% Process each ROI archive
    for k = 1:nFiles
        thisPath = roiPaths{k};
        results(k).filePath = thisPath;

        % Derive rootFolder and rootName from thisPath
        zipFolder  = fileparts(thisPath);        % .../ROI-files/<rootName>_roi
        parentDir  = fileparts(zipFolder);       % .../ROI-files
        rootFolder = fileparts(parentDir);       % .../<rootName>
        [~, rootName] = fileparts(rootFolder);   % e.g. 'Alouatta_seniculus_1170'

        % Match speciesID to filename
        matchIdx = find(contains(thisPath, speciesIDs), 1);
        if isempty(matchIdx)
            warning('process_roi:NoSpeciesID', ...
                'No speciesID matched in "%s". Skipping.', thisPath);
            continue;
        end
        sid = speciesIDs{matchIdx};
        results(k).speciesID = sid;

        % Read ROI(s)
        try
            raw = ReadImageJROI(thisPath);
        catch ME
            warning('process_roi:ReadFailed', ...
                'Could not read "%s": %s', thisPath, ME.message);
            continue;
        end

        % Flatten cell output if necessary
        if iscell(raw)
            rois = [raw{:}];
        else
            rois = raw;
        end

        % Annotate each ROI struct
        for i = 1:numel(rois)
            rois(i).rootPath   = rootFolder;
            rois(i).roiPath    = thisPath;
            rois(i).rootName   = rootName;
            rois(i).speciesID  = sid;
        end

        % List contour names
        names = {rois.strName};
        fprintf('In file "%s" (ID=%s) found contours:\n', thisPath, sid);
        for i = 1:numel(names)
            fprintf('  - %s\n', names{i});
        end

        % Create masks & compute areas
        nROIs = numel(rois);
        areas = zeros(1, nROIs);
        for i = 1:nROIs
            mask     = create_mask(rois(i));
            areas(i) = calculate_areas(mask);
        end

        % Store results
        results(k).numROIs = nROIs;
        results(k).areas   = areas;
        fprintf('Processed "%s": %d ROIs → areas = [%s]\n\n', ...
                thisPath, nROIs, num2str(areas));
    end
end