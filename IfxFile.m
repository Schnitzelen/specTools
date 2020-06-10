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
    assert(sum(contains(MetaData.Columns, 'Wavelength')) < 2)
    ColumnNames = regexprep(MetaData.Columns, 'E(\w+)ionWavelength', 'Wavelength');
    ColumnNames = strsplit(ColumnNames, ',');
    Data = cell2table(num2cell(File.data), 'VariableNames', ColumnNames);
end