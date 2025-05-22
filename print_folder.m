% Basisverzeichnis
rootDir = pwd;

% Rekursives Auflisten aller Dateien und Ordner
allEntries = dir(fullfile(rootDir, '**', '*'));

% Nur gültige Einträge (ohne '.' und '..')
allEntries = allEntries(~ismember({allEntries.name}, {'.', '..'}));

% Strukturierte Ausgabe
for k = 1:length(allEntries)
    entry = allEntries(k);
    relativePath = strrep(entry.folder, rootDir, '');
    fullPath = fullfile(relativePath, entry.name);
    if entry.isdir
        fprintf('[DIR]  %s\n', fullPath);
    else
        fprintf('       %s\n', fullPath);
    end
end
