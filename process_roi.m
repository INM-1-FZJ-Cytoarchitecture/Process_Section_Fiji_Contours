function results = process_roi(roiPaths, speciesIDs, debug_mode)
%PROCESS_ROI Load ROI files, interpret hierarchical tags, and return tissue stats.
%
%   Der Prozess basiert auf den folgenden ROI-Definitionen (Tags):
%     #t  : Total brain (Supratentorial), ohne Cerebellum.
%     #g  : Alles innerhalb von #t, was NICHT Gray Matter ist (Subtraktionsmaske).
%     #w  : Exakt White Matter.
%     #i  : Inner Brain (alles in #t außer Grau/Weiß).
%     #v  : Ventrikel innerhalb von #t.
%     #c  : Cerebellum.
%     #vc : Ventrikel innerhalb des Cerebellums.
%     #gi : Gray matter surrounded by white matter (Deep Gray Matter).
%
%   Input:
%     roiPaths    : Cell array oder String array mit Pfaden zu ROI ZIPs.
%     speciesIDs  : Cell array mit dreistelligen IDs (z.B. {'001','011'}).
%     debug_mode  : Boolean (default false).

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

    %% Prepare empty fixed‐schema table
    varNames = {'rootName','rootPath','filePath','speciesPath','maskPath', ...
                'ImageID','numROIs','NeocorticalGM','White','Cerebellum','DeepGM','Ventricles'};
    varTypes = {'string','string','string','string','string', ...
                'string','double','double','double','double','double','double'};
            
    results = table('Size',[0,numel(varNames)], ...
                    'VariableTypes',varTypes, ...
                    'VariableNames',varNames);

    %% Loop over ROI archives
    fprintf('\n--- START PROCESSING LOOP ---\n');
    for k = 1:numel(roiPaths)
        thisPath = roiPaths{k};
        [~, fname, ext] = fileparts(thisPath);
        
        % DEBUG: Dateiname prüfen
        % fprintf('Checking: %s%s ... ', fname, ext); 

        % 1) Extract three‐digit ImageID
        % Regex sucht nach: Irgendwas, dann Unterstrich, dann 3 Ziffern, dann "_roi" am Ende
        tok = regexp(fname, '^.+_(\d{3})_roi$', 'tokens','once');
        
        if isempty(tok)
            % FEHLER 1: Dateiname passt nicht zum Muster
            fprintf('SKIP: "%s" -> Regex match failed (Expected format: name_XXX_roi.zip)\n', fname);
            continue;
        end
        sid = tok{1};

        % 2) Validate ImageID
        if ~any(strcmp(speciesIDs, sid))
            % FEHLER 2: ID ist nicht in der Liste der erwarteten IDs
            fprintf('SKIP: "%s" -> ID [%s] not found in speciesIDs list.\n', fname, sid);
            continue;
        end

        % 3) Read ROI file and Harmonize Struct Fields
        try
            raw = ReadImageJROI(thisPath);
        catch ME
            % FEHLER 3: Datei kaputt oder nicht lesbar
            fprintf('SKIP: "%s" -> ReadImageJROI failed: %s\n', fname, ME.message);
            continue;
        end
        
        % --- FIX START: Harmonize fields before concatenation ---
        if iscell(raw)
            allFields = {};
            for r = 1:numel(raw)
                allFields = [allFields; fieldnames(raw{r})]; %#ok<AGROW>
            end
            uniqueFields = unique(allFields);
            
            for r = 1:numel(raw)
                s = raw{r};
                currentFields = fieldnames(s);
                missingFields = setdiff(uniqueFields, currentFields);
                for m = 1:numel(missingFields)
                    s.(missingFields{m}) = []; 
                end
                raw{r} = s;
            end
            rois = [raw{:}];
        else
            rois = raw;
        end
        % --- FIX END ---

        % 4) Annotate ROIs and derive metadata paths
        zipFolder  = fileparts(thisPath);
        parentDir  = fileparts(zipFolder);
        rootFolder = fileparts(parentDir);
        [~, rootName] = fileparts(rootFolder);

        speciesFile = sprintf('%s_%s.tif', rootName, sid);
        speciesPath = fullfile(rootFolder, 'Species', rootName, speciesFile);

        maskFolder = fullfile(rootFolder, 'masks');
        maskName   = sprintf('%s_%s_mask.tif', rootName, sid);
        maskPath   = fullfile(maskFolder, maskName);

        if ~isfield(rois, 'strName')
            [rois.strName] = deal('');
        end

        for i = 1:numel(rois)
            rois(i).rootPath  = rootFolder;
            rois(i).roiPath   = thisPath;
            rois(i).rootName  = rootName;
            rois(i).speciesID = sid;
        end
        
        % 5) Debug info (nur wenn mode an ist)
        if debug_mode
           % ... (dein alter debug code)
        end

        % 6) Create mask
        try
            mask = create_mask(rois);
        catch ME
            % FEHLER 4: Masken-Erstellung gescheitert
            fprintf('SKIP: "%s" (ID %s) -> create_mask failed: %s\n', fname, sid, ME.message);
            continue;
        end

        % % 7) Calculate areas
        % try
        %     tbl = calculate_areas(mask); 
        % 
        %     valNeocortex = 0; valWhite = 0; valCerebellum = 0; valDeepGM = 0; valVentricles = 0;
        % 
        %     if ismember('NeocorticalGM', tbl.Properties.VariableNames), valNeocortex = tbl.NeocorticalGM; end
        %     if ismember('White', tbl.Properties.VariableNames),         valWhite = tbl.White; end
        %     if ismember('Cerebellum', tbl.Properties.VariableNames),    valCerebellum = tbl.Cerebellum; end
        %     if ismember('DeepGM', tbl.Properties.VariableNames),        valDeepGM = tbl.DeepGM;
        %     elseif ismember('ArchicorticalGM', tbl.Properties.VariableNames), valDeepGM = tbl.ArchicorticalGM; end
        %     if ismember('Ventricles', tbl.Properties.VariableNames),    valVentricles = tbl.Ventricles; end
        % 
        % catch ME
        %     % Hier überspringen wir nicht, sondern schreiben Nullen, aber geben Warnung aus
        %     fprintf('WARNING: "%s" -> Area calc failed, setting to 0. Error: %s\n', fname, ME.message);
        %     valNeocortex = 0; valWhite = 0; valCerebellum = 0; valDeepGM = 0; valVentricles = 0;
        % end
        % 
        % % 8) Count ROIs & Assemble Result
        % nROIs = numel(rois);
        % newRow = table(string(rootName), string(rootFolder), string(thisPath), ...
        %                string(speciesPath), string(maskPath), ...
        %                string(sid), nROIs, ...
        %                valNeocortex, valWhite, valCerebellum, valDeepGM, valVentricles, ...
        %                'VariableNames',varNames);
        % 
        % if ~isfolder(maskFolder), mkdir(maskFolder); end
        % 
        % results = [results; newRow];
        % 
        % % Success Nachricht für Debugging
        % % fprintf('OK: "%s" added.\n', fname);
    end
    fprintf('--- END PROCESSING LOOP ---\n\n');

    %% Final Summary
    if ~debug_mode
        for i = 1:height(results)
            fp = results.filePath(i);
            sid = results.ImageID(i);
            n = results.numROIs(i);
            [~, fn] = fileparts(fp);
            if n == 0
                fprintf('%s\t%s\tWarning: no or wrong labeled ROIs found\n', fn, sid);
            else
                fprintf('%s\t%s\tN RoIs: [%d]\n', fn, sid, n);
            end
        end
    end
end