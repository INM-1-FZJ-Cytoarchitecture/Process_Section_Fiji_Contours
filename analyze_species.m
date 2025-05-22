function analyze_species(rootFolder)
%ANALYZE_SPECIES Verify correspondence between Species images, ROI archives, and Outlines
%
%   analyze_species(ROOTFOLDER) inspects the folder structure under ROOTFOLDER
%   to ensure that for every TIFF image in the Species subfolder there exists
%   a matching ROI ZIP archive in the ROI-files subfolder and a matching
%   outlined TIFF in the Outlines subfolder. It prints a summary report to the
%   Command Window, issues warnings if files are missing, and if all checks
%   pass, calls PROCESS_ROI on the list of ROI files.
%
%   Syntax
%     analyze_species(rootFolder)
%
%   Input Arguments
%     rootFolder : char or string
%                  Absolute path to the top-level folder for one specimen.
%                  Example: 'C:\Data\Alouatta_seniculus_1170'
%
%   Output Arguments
%     None. This function does not return outputs. It displays counts and
%     warnings to the Command Window and invokes PROCESS_ROI when ready.
%
%   Side Effects
%     - Prints the number of Species images, ROI files, and Outlines found.
%     - Raises warnings if any matching ROI or Outline files are missing.
%     - Calls PROCESS_ROI with a cell array of full paths to each ROI ZIP
%       if all matches are present.
%
%   Example
%     % Suppose your folder tree is:
%     %   C:\Data\Alouatta_seniculus_1170\
%     %     Species\Alouatta_seniculus_1170\*.tif
%     %     ROI-files\Alouatta_seniculus_1170_roi\*.zip
%     %     Outlines\Alouatta_seniculus_1170_outlined\*.tif
%     analyze_species('C:\Data\Alouatta_seniculus_1170');
%
%   See also PROCESS_ROI, DIR, ISFOLDER, WARNING, ERROR.

    %% Validate input folder exists
    if ~isfolder(rootFolder)
        error('analyze_species:InvalidFolder', ...
              'The specified folder does not exist: %s', rootFolder);
    end

    %% Derive expected subfolder paths based on specimen name
    [~, specimenName] = fileparts(rootFolder);  % e.g. 'Alouatta_seniculus_1170'
    speciesDir = fullfile(rootFolder, 'Species', specimenName);
    roiDir     = fullfile(rootFolder, 'ROI-files', [specimenName '_roi']);
    outlineDir = fullfile(rootFolder, 'Outlines', [specimenName '_outlined']);

    %% Check for required subfolders
    if ~isfolder(speciesDir)
        error('analyze_species:MissingSpecies', ...
              'Missing Species folder: %s', speciesDir);
    end
    if ~isfolder(roiDir)
        error('analyze_species:MissingROI', ...
              'Missing ROI-files folder: %s', roiDir);
    end
    if ~isfolder(outlineDir)
        error('analyze_species:MissingOutlines', ...
              'Missing Outlines folder: %s', outlineDir);
    end

    %% List files in each folder
    speciesFiles = dir(fullfile(speciesDir, '*.tif'));   % .tif images
    roiFiles     = dir(fullfile(roiDir,     '*.zip'));   % .zip ROI archives
    outlineFiles = dir(fullfile(outlineDir, '*.tif'));   % outlined .tif images

    %% Count files
    nSpecies  = numel(speciesFiles);
    nROI      = numel(roiFiles);
    nOutline  = numel(outlineFiles);

    %% Print summary report
    fprintf('--- Report for specimen: %s ---\n', specimenName);
    fprintf('Number of Species images : %d\n', nSpecies);
    fprintf('Number of ROI archives   : %d\n', nROI);
    fprintf('Number of Outlines       : %d\n', nOutline);

    %% Extract ID tokens from filenames (e.g. '011', '012', ...)
    speciesIDs  = extract_ids(speciesFiles,  specimenName, '_');
    roiIDs      = extract_ids(roiFiles,      specimenName, '_roi');
    outlineIDs  = extract_ids(outlineFiles, specimenName, '_outlined');

    %% Identify missing matches
    missingROI     = setdiff(speciesIDs, roiIDs);
    missingOutline = setdiff(speciesIDs, outlineIDs);

    if ~isempty(missingROI)
        warning('analyze_species:MissingROI', ...
            'Missing ROI for %d Species image(s): %s', ...
            numel(missingROI), strjoin(missingROI, ', '));
    end
    if ~isempty(missingOutline)
        warning('analyze_species:MissingOutlines', ...
            'Missing Outline for %d Species image(s): %s', ...
            numel(missingOutline), strjoin(missingOutline, ', '));
    end

    %% If all checks pass, invoke PROCESS_ROI
    if isempty(missingROI) && isempty(missingOutline)
        fprintf('All files matched. Invoking process_roi on %d ROI files...\n', nROI);
        % Build full paths to each ROI file
        roiPaths = fullfile({roiFiles.folder}, {roiFiles.name});
        process_roi(roiPaths);
    else
        fprintf('Checks failed. process_roi will not be called.\n');
    end
end

%% Helper function to extract identifier tokens from file list
function ids = extract_ids(fileList, rootName, suffix)
%extract_ids Return IDs from filenames by removing rootName and suffix.
%
%   ids = extract_ids(fileList, rootName, suffix) processes each entry in
%   fileList (struct array from DIR), strips the prefix [rootName '_'] and
%   the trailing suffix (e.g. '_roi', '_outlined'), returning a cell array
%   of ID strings (e.g. {'011','012',...}).

    n = numel(fileList);
    ids = cell(1, n);
    prefix = [rootName '_'];
    for k = 1:n
        [~, nameOnly, ~] = fileparts(fileList(k).name);
        % Remove prefix
        token = strrep(nameOnly, prefix, '');
        % Remove suffix if present
        token = strrep(token, suffix, '');
        ids{k} = token;
    end
end
