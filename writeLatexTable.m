function writeLatexTable(Table, FileName)
    NumCols = width(Table);
    NumRows = height(Table);
    LatexTable = '';
    % Build LatexTable text
    for r = 1:NumRows
        LatexTable = [LatexTable, sprintf('%s\t', string(Table{r, 1}))];
        for c = 2:(NumCols - 1)
            LatexTable = [LatexTable, sprintf('& %s\t', string(Table{r, c}))];
        end
        LatexTable = [LatexTable, sprintf('& %s', string(Table{r, NumCols}))];
        if r < NumRows
            LatexTable = [LatexTable, ' \\\\'];
        end
    end
    % Save
    [Folder, FileName, ~] = fileparts(FileName);
    Ext = '.txt';
    FileName = fullfile(Folder, [FileName, Ext]);
    FID = fopen(FileName, 'w');
    fprintf(FID, LatexTable);
    fclose(FID);
end