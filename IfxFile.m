function [Data, MetaData] = IfxFile(AbsoluteFileName)
    % Read file
    File = importdata(AbsoluteFileName);
    % Parse header
    MetaData = File.textdata(1:end-1);
    MetaData = regexp(MetaData, '=', 'split');
    MetaData = regexp(File.textdata(1:end-1, 1), '=', 'split');
    MetaData = vertcat(MetaData{:});
    MetaData = compileStructFromKeyValuePairs(MetaData(:, 1), MetaData(:, 2));
    % Parse data
    ColumnNames = strrep(MetaData.Columns, 'EmissionWavelength', 'Wavelength');
    ColumnNames = strsplit(ColumnNames, ',');
    Data = cell2table(num2cell(File.data), 'VariableNames', ColumnNames);
end