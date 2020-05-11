function [Data, MetaData] = CsvFile(AbsoluteFileName)
    % Read file
    File = importdata(AbsoluteFileName);
    % Parse header
    ColumnNames = File.textdata(end, :);
    ColumnNames = regexp(ColumnNames, '\(([^)]+)\)', 'split');
    ColumnNames = cellfun(@(x) x(1), ColumnNames);
    ColumnNames = cellfun(@(x) horzcat(upper(x(1)), x(2:end)), ColumnNames, 'UniformOutput', false);
    MetaData = regexp(File.textdata(1:end-2, 1), '=', 'split');
    MetaData = vertcat(MetaData{:});
    MetaData = compileStructFromKeyValuePairs(MetaData(:, 1), MetaData(:, 2));
    % Parse data
    Data = cell2table(num2cell(File.data), 'VariableNames', ColumnNames);
    Data = sortrows(Data);
end