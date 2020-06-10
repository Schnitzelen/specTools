function [Results, ReferenceName] = collectTwoPhotonExcitationData(varargin)
    % Prepare arguments
    SampleFolder = '';
    ReferenceFolder = '';
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'SampleFolder'
                SampleFolder = varargin{i + 1};
            case 'ReferenceFolder'
                ReferenceFolder = varargin{i + 1};
            otherwise
                error('Unknown Argument Passed: %s', varargin{i})
        end
    end
    % If any arguments are not defined by now, prompt user
    if isempty(SampleFolder)
        SampleFolder = uigetdir(pwd(), 'Please Choose 2PEx Sample Folder');
    end
    assert(isa(SampleFolder, 'char'), 'No Sample Selected!')
    if isempty(ReferenceFolder)
        ReferenceFolder = uigetdir(pwd(), 'Please Choose 2PEx Reference Folder');
    end
    assert(isa(ReferenceFolder, 'char'), 'No Sample Selected!')
    % Locate sample files
    DataFolder = fullfile(SampleFolder, 'data');
    SampleFiles = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', '2pa');
    % Fetch unique experiment dates and solvents
    [~, FileNames, ~] = cellfun(@(x) fileparts(x), SampleFiles, 'UniformOutput', false);
    FileNames = regexp(FileNames, '_', 'split');
    SampleDates = cellfun(@(x) x{1}, FileNames, 'UniformOutput', false);
    SampleSolvents = cellfun(@(x) x{3}, FileNames, 'UniformOutput', false);
    [~, UniqueIdx, ~] = unique(cellfun(@(d, s) strcat(d, s), SampleDates, SampleSolvents, 'UniformOutput', false));
    UniqueDates = SampleDates(UniqueIdx);
    UniqueSolvents = SampleSolvents(UniqueIdx);
    % Import data files
    Idx = cellfun(@(d, s) strcmp(SampleDates, d) & strcmp(SampleSolvents, s), UniqueDates, UniqueSolvents, 'UniformOutput', false);
    SampleData = cellfun(@(x) TPExExperiment('SampleFiles', SampleFiles(x), 'ReferenceFolder', ReferenceFolder), Idx, 'UniformOutput', false);
    % Keep only data that do have a TPA table value
    Idx = cellfun(@(x) x.TableValueFound, SampleData);
    SampleData = SampleData(Idx);
    % Confirm only one reference solvent
    assert(length(unique(cellfun(@(x) x.Reference.Solvent, SampleData, 'UniformOutput', false))) == 1, 'Multiple Reference Solvents Located!')
    ReferenceName = [SampleData{1}.Reference.Compound, ' in ', SampleData{1}.Reference.Solvent];
%     % Plot raw data - just to see...
%     figure;
%     hold on
%     xlabel('wavelength (nm)', 'Interpreter', 'latex')
%     ylabel('$\phi_{f} \cdot \sigma_{2P}$ (GM)', 'Interpreter', 'latex')
%     plot(SampleData{1}.TableValue.Wavelength, SampleData{1}.TableValue.TPA, 'bo-', 'DisplayName', sprintf('%s in %s', SampleData{1}.Reference.Compound, SampleData{1}.Reference.Solvent));
%     cellfun(@(x) errorbar(x.Data.Wavelength, x.Data.MeanActionPotential, x.Data.SDActionPotential, 'DisplayName', x.Date), SampleData)
%     legend({}, 'Interpreter', 'latex')
    % Build results table
    ExcitationWavelengths = cellfun(@(x) x.Data.Wavelength, SampleData, 'UniformOutput', false);
    UniqueExcitationWavelengths = unique(vertcat(ExcitationWavelengths{:}));
    UniqueSolvents = unique(cellfun(@(x) x.Solvent, SampleData, 'UniformOutput', false));
    PolarityTable = readtable(fullfile(getenv('userprofile'), 'Documents', 'MATLAB', 'SpecTools', 'ref_polarity.csv'));
    [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), UniqueSolvents), 'descend');
    UniqueSolvents = UniqueSolvents(PolaritySorting);
    ColumnNames = cellfun(@(x) [{['Mean', x]}, {['SD', x]}], UniqueSolvents', 'UniformOutput', false);
    ColumnNames = horzcat(ColumnNames{:});
    Results = array2table(NaN(length(UniqueExcitationWavelengths), 2+length(ColumnNames)), 'VariableNames', {'Wavelength', 'ReferenceTPA', ColumnNames{:}});
    Results.Wavelength = UniqueExcitationWavelengths;
    Results.ReferenceTPA = SampleData{1}.TableValue.TPA(any(SampleData{1}.TableValue.Wavelength == Results.Wavelength', 2));
    for c = 3:2:width(Results)
        Solvent = UniqueSolvents{(c-1)/2};
        for r = 1:height(Results)
            Wavelength = Results.Wavelength(r);
            Idx = cellfun(@(x) x.Data.Wavelength == Wavelength & strcmp(x.Solvent, Solvent), SampleData, 'UniformOutput', false);
            MeanActionPotential = cellfun(@(x, i) x.Data.MeanActionPotential(i), SampleData, Idx, 'UniformOutput', false);
            Results{r, c} = round(mean(vertcat(MeanActionPotential{:})), 4, 'significant');
            Results{r, c+1} = round(std(vertcat(MeanActionPotential{:})), 4, 'significant');
        end
    end
    % Save results
    FileName = fullfile(SampleFolder, ['2PEx_ref_', SampleData{1}.Reference.Compound, '.csv']);
    writetable(Results, FileName)
end