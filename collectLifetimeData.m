function Results = collectLifetimeData(varargin)
    % Prepare arguments
    %SampleFolder = '';
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'SampleFolder'
                SampleFolder = varargin{i + 1};
            otherwise
                error('Unknown Argument Passed: %s', varargin{i})
        end
    end
    % If any arguments are not defined by now, prompt user
    if isempty(SampleFolder)
        SampleFolder = uigetdir(pwd(), 'Please Choose QY Sample Folder');
    end
    assert(isa(SampleFolder, 'char'), 'No Sample Selected!')
    % Locate sample files
    DataFolder = fullfile(SampleFolder, 'data');
    SampleFiles = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', 'FLIM');
    % Fetch unique experiment dates and solvents
    [~, FileNames, ~] = cellfun(@(x) fileparts(x), SampleFiles, 'UniformOutput', false);
    FileNames = regexp(FileNames, '_', 'split');
    SampleDates = cellfun(@(x) x{1}, FileNames, 'UniformOutput', false);
    SampleSolvents = cellfun(@(x) x{3}, FileNames, 'UniformOutput', false);
    [~, UniqueIdx, ~] = unique(cellfun(@(d, s) strcat(d, s), SampleDates, SampleSolvents, 'UniformOutput', false));
    UniqueDates = SampleDates(UniqueIdx);
    UniqueSolvents = SampleSolvents(UniqueIdx);
    % Import Sdt-files
    %Solvents = regexp(Files, '(?<=_FLIM_).+?(?=_)', 'match');
    SdtFiles = SampleFiles(contains(SampleFiles, '.sdt')); 
    UniqueSdtExperiments = regexprep(SdtFiles, '\.\w+$', '');
    %Files = Files(contains(SampleFiles, '.asc'));
    Idx = cellfun(@(x) contains(SampleFiles, x) & contains(SampleFiles, '.asc'), UniqueSdtExperiments, 'UniformOutput', false);
    SampleData = cellfun(@(x) readFLIM(SampleFiles(x)), Idx, 'UniformOutput', false);
    % Possibility to append more files with different extensions...
    % Build results table
    Results = cell2table(cell(length(UniqueDates), 14), 'VariableNames', {'Date', 'Solvent', 'MeanA1', 'SDA1', 'MeanT1', 'SDT1', 'MeanA2', 'SDA2', 'MeanT2', 'SDT2', 'MeanA3', 'SDA3', 'MeanT3', 'SDT3'});
    Results.Date = UniqueDates;
    Results.Solvent = UniqueSolvents;
    SampleTitles = cellfun(@(x) x.Title, SampleData, 'UniformOutput', false);
    SampleSolvents = cellfun(@(x) x.Solvent, SampleData, 'UniformOutput', false);
    Idx = cellfun(@(d, s) contains(SampleTitles, d) & contains(SampleSolvents, s), Results.Date, Results.Solvent, 'UniformOutput', false);
    Results.MeanA1 = cellfun(@(x) SampleData{x}.Results.MeanA1, Idx, 'UniformOutput', false);
    Results.SDA1 = cellfun(@(x) SampleData{x}.Results.SDA1, Idx, 'UniformOutput', false);
    Results.MeanT1 = cellfun(@(x) SampleData{x}.Results.MeanT1, Idx, 'UniformOutput', false);
    Results.SDT1 = cellfun(@(x) SampleData{x}.Results.SDT1, Idx, 'UniformOutput', false);
    Results.MeanA2 = cellfun(@(x) SampleData{x}.Results.MeanA2, Idx, 'UniformOutput', false);
    Results.SDA2 = cellfun(@(x) SampleData{x}.Results.SDA2, Idx, 'UniformOutput', false);
    Results.MeanT2 = cellfun(@(x) SampleData{x}.Results.MeanT2, Idx, 'UniformOutput', false);
    Results.SDT2 = cellfun(@(x) SampleData{x}.Results.SDT2, Idx, 'UniformOutput', false);
    Results.MeanA3 = cellfun(@(x) SampleData{x}.Results.MeanA3, Idx, 'UniformOutput', false);
    Results.SDA3 = cellfun(@(x) SampleData{x}.Results.SDA3, Idx, 'UniformOutput', false);
    Results.MeanT3 = cellfun(@(x) SampleData{x}.Results.MeanT3, Idx, 'UniformOutput', false);
    Results.SDT3 = cellfun(@(x) SampleData{x}.Results.SDT3, Idx, 'UniformOutput', false);
end