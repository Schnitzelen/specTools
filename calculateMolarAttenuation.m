function Results = calculateMolarAttenuation(varargin)
    % Prepare arguments
    SampleFolder = '';
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
    assert(~isempty(SampleFolder), 'No Sample Selected!')
    % Locate sample files
    DataFolder = fullfile(SampleFolder, 'data');
    SampleFiles = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', 'qy', 'FileExtension', 'TXT');
    % Fetch unique experiment dates and solvents
    [~, FileNames, ~] = cellfun(@(x) fileparts(x), SampleFiles, 'UniformOutput', false);
    FileNames = regexp(FileNames, '_', 'split');
    SampleDates = cellfun(@(x) x{1}, FileNames, 'UniformOutput', false);
    SampleSolvents = cellfun(@(x) x{3}, FileNames, 'UniformOutput', false);
    [~, UniqueIdx, ~] = unique(cellfun(@(d, s) strcat(d, s), SampleDates, SampleSolvents, 'UniformOutput', false));
    % Keep only dates with more than one measurement
    Idx = cellfun(@(x) 1 < sum(strcmp(SampleDates, x)), SampleDates(UniqueIdx));
    UniqueIdx = UniqueIdx(Idx);
    Dates = SampleDates(UniqueIdx);
    Solvents = SampleSolvents(UniqueIdx);
    % Keep only sampleFiles that are in unique date/solvent combinations
    Idx = cellfun(@(d, s) strcmp(SampleDates, d) & strcmp(SampleSolvents, s), Dates, Solvents, 'UniformOutput', false);
    Idx = any(horzcat(Idx{:}), 2);
    SampleFiles = SampleFiles(Idx);
    % Import samples
    SampleAbsorption = cellfun(@(x) readAbs(x), SampleFiles, 'UniformOutput', false);
    % Create results table
    Results = cell2table(cell(length(UniqueIdx), 4), 'VariableNames', {'Date', 'Solvent', 'Wavelength', 'MolarAttenuationCoefficient'});
    Results.Date = Dates;
    Results.Solvent = Solvents;
    % For each row in results table, fit absorption to concentration
    for i = 1:height(Results)
        Date = Results.Date{i};
        Solvent = Results.Solvent{i};
        Idx = cellfun(@(x) contains(x.Title, Date) & strcmp(x.Solvent, Solvent), SampleAbsorption);
        Wavelength = cellfun(@(x) x.Data.Wavelength, SampleAbsorption(Idx), 'UniformOutput', false);
        Wavelength = round(mean(cellfun(@(x) x(round(length(x)/2)), Wavelength)));
        Absorption = cellfun(@(x) x.Data.Absorption(x.Data.Wavelength == Wavelength), SampleAbsorption(Idx));
        Unit = {'M', 'mM', 'uM', 'nM'};
        Factor = [10^0, 10^-3, 10^-6, 10^-9];
        Concentration = cellfun(@(x) x.Concentration.Value * Factor(strcmp(Unit, x.Concentration.Unit)), SampleAbsorption(Idx));
        Fit = fit(Concentration, Absorption, fittype({'x'}));
        %figure
        %plot(Fit, Concentration, Absorption)
        Results.Wavelength{i} = Wavelength;
        Results.MolarAttenuationCoefficient{i} = round(Fit.a, 4, 'significant');
    end
    % Save results
    writetable(Results, fullfile(SampleFolder, 'MAC_results.csv'));
end