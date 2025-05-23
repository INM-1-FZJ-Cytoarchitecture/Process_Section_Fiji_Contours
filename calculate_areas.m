function tbl = calculate_areas(mask)
    % Count pixels for each code 1,2,3
    nNeocorticalGM  = sum(mask(:) == 1);
    nWhite     = sum(mask(:) == 2);
    nCerebellum= sum(mask(:) == 3);
    nArchicorticalGM= sum(mask(:) == 4);
    % Build a one‐row table with fixed columns
    tbl = table(nNeocorticalGM, nWhite, nCerebellum, nArchicorticalGM,...
        'VariableNames', {'NeocorticalGM','White','Cerebellum','ArchicorticalGM'});
end
