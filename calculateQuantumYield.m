function Results = calculateQuantumYield(varargin)
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
        SampleFolder = uigetdir(pwd(), 'Please Choose QY Sample Folder');
    end
    assert(~isempty(SampleFolder), 'No Sample Selected!')
    if isempty(ReferenceFolder)
        %ReferenceFolder = 'C:\Users\schni\OneDrive - Syddansk Universitet\Samples\NR';
        ReferenceFolder = uigetdir(pwd(), 'Please Choose QY Reference Folder');
    end
    assert(~isempty(ReferenceFolder), 'No Reference Selected!')
    % Locate sample files
    SampleFiles =  dir(fullfile(SampleFolder, 'data', '*_qy_*'));
    % Fetch unique experiment dates and solvents
    [~, FileNames, ~] = cellfun(@(x) fileparts(x), {SampleFiles.name}, 'UniformOutput', false);
    FileNames = regexp(FileNames, '_', 'split');
    SampleDates = cellfun(@(x) x{1}, FileNames, 'UniformOutput', false);
    SampleSolvents = cellfun(@(x) x{3}, FileNames, 'UniformOutput', false);
    [~, UniqueIdx, ~] = unique(cellfun(@(d, s) strcat(d, s), SampleDates, SampleSolvents, 'UniformOutput', false));
    % Keep only dates with more than one measurement
    Idx = cellfun(@(x) 1 < sum(strcmp(SampleDates, x)), SampleDates(UniqueIdx));
    UniqueIdx = UniqueIdx(Idx);
    UniqueDates = SampleDates(UniqueIdx);
    % Locate reference files
    ReferenceFiles =  dir(fullfile(ReferenceFolder, 'data', '*_qy_*'));
    % Fetch reference dates
    [~, FileNames, ~] = cellfun(@(x) fileparts(x), {ReferenceFiles.name}, 'UniformOutput', false);
    FileNames = regexp(FileNames, '_', 'split');
    ReferenceDates = cellfun(@(x) x{1}, FileNames, 'UniformOutput', false);
    % Keep only dates with more than one reference measurement
    Idx = cellfun(@(x) 1 < sum(strcmp(ReferenceDates, x)), UniqueDates);
    UniqueDates = UniqueDates(Idx);
    Idx = cellfun(@(x) strcmp(SampleDates, x), UniqueDates, 'UniformOutput', false);
    Idx = any(vertcat(Idx{:}));
    SampleFiles = arrayfun(@(x) fullfile(x.folder, x.name), SampleFiles(Idx), 'UniformOutput', false);
    % Ensure that data come in abs/em-pairs
    AbsIdx = cellfun(@(x) strcmp('.TXT', x(end-3:end)), SampleFiles);
    AbsFiles = SampleFiles(AbsIdx);
    EmFiles = SampleFiles(~AbsIdx)';
    PairIdx = cellfun(@(x) strcmp(cellfun(@(x) x(1:end-4), EmFiles, 'UniformOutput', false), x(1:end-4)), AbsFiles, 'UniformOutput', false);
    PairIdx = vertcat(PairIdx{:});
    AbsFiles = AbsFiles(any(PairIdx, 2));
    EmFiles = EmFiles(any(PairIdx, 1));
    % Import samples
    SampleAbsorption = cellfun(@(x) readAbs(x), AbsFiles, 'UniformOutput', false);
    SampleEmission = cellfun(@(x) readEm(x), EmFiles', 'UniformOutput', false);
    % Keep only referencefiles with the unique experiment dates
    Idx = cellfun(@(x) strcmp(ReferenceDates, x), UniqueDates, 'UniformOutput', false);
    Idx = any(vertcat(Idx{:}));
    ReferenceFiles = arrayfun(@(x) fullfile(x.folder, x.name), ReferenceFiles(Idx), 'UniformOutput', false);
    % Ensure that data come in abs/em-pairs
    AbsIdx = cellfun(@(x) strcmp('.TXT', x(end-3:end)), ReferenceFiles);
    AbsFiles = ReferenceFiles(AbsIdx);
    EmFiles = ReferenceFiles(~AbsIdx)';
    PairIdx = cellfun(@(x) strcmp(cellfun(@(x) x(1:end-4), EmFiles, 'UniformOutput', false), x(1:end-4)), AbsFiles, 'UniformOutput', false);
    PairIdx = vertcat(PairIdx{:});
    AbsFiles = AbsFiles(any(PairIdx, 2));
    EmFiles = EmFiles(any(PairIdx, 1));
    % Import references
    ReferenceAbsorption = cellfun(@(x) readAbs(x), AbsFiles, 'UniformOutput', false);
    ReferenceEmission = cellfun(@(x) readEm(x), EmFiles', 'UniformOutput', false);
    % Create results table
    Results = cell2table(cell(length(UniqueIdx), 5), 'VariableNames', {'Solvent', 'QuantumYield', 'RefCompound', 'RefSolvent', 'RefQuantumYield'});
    % Load physical property tables
    TableValuePath = fullfile(getenv('userprofile'), 'Documents', 'Matlab', 'SpecTools');
    QuantumYieldTable = readtable(fullfile(TableValuePath, 'ref_quantum_yield.csv'));
    RefractiveIndexTable = readtable(fullfile(TableValuePath, 'ref_refractive_index.csv'));
    % Calculate quantum yield for each experiment date
    for i = 1:length(UniqueIdx)
        Date = SampleDates{UniqueIdx(i)};
        % Fetch reference information
        Idx = cellfun(@(x) contains(x.Title, Date), ReferenceAbsorption);
        Compound = unique(cellfun(@(x) x.Compound, ReferenceAbsorption(Idx), 'UniformOutput', false));
        assert(length(Compound) == 1, 'Multiple Reference Compounds Detected For Date %s', Date)
        Results.RefCompound(i) = Compound;
        Solvent = unique(cellfun(@(x) x.Solvent, ReferenceAbsorption(Idx), 'UniformOutput', false));
        assert(length(Solvent) == 1, 'Multiple Reference Solvents Detected For Date %s', Date)
        Results.RefSolvent(i) = Solvent;
        % Calculate reference gradient
        ReferenceGradient = calculateGradient(ReferenceAbsorption(Idx), ReferenceEmission(Idx));
        % Fetch reference physical properties
        Idx = strcmp(QuantumYieldTable.Solvent, Solvent) & strcmp(QuantumYieldTable.Abbreviation, Compound);
        assert(sum(Idx) == 1, 'No Unique Reference Quantum Yield Known For Experiment %s', Date)
        Results.RefQuantumYield(i) = {QuantumYieldTable.QuantumYield(Idx)};
        Idx = strcmp(strrep(Solvent, ',', '.'), RefractiveIndexTable.Abbreviation);
        assert(sum(Idx) == 1, 'No Unique Reference Refractive Index Known For Experiment %s', Date)
        ReferenceRefractiveIndex = RefractiveIndexTable.RefractiveIndex(Idx);
        % Fetch sample information
        Solvent = SampleSolvents(UniqueIdx(i));
        Results.Solvent(i) = Solvent;
        Idx = strcmp(strrep(Solvent, ',', '.'), RefractiveIndexTable.Abbreviation);
        assert(sum(Idx) == 1, 'No Unique Reference Refractive Index Known For Experiment %s', Date)
        SampleRefractiveIndex = RefractiveIndexTable.RefractiveIndex(Idx);
        % Calculate sample gradient
        Idx = cellfun(@(x) contains(x.Title, Date) & strcmp(x.Solvent, Solvent), SampleAbsorption);
        SampleGradient = calculateGradient(SampleAbsorption(Idx), SampleEmission(Idx));
        % Calculate sample quantum yield
        QuantumYield = Results.RefQuantumYield{i} * ( SampleGradient / ReferenceGradient ) * ( SampleRefractiveIndex^2 / ReferenceRefractiveIndex^2 );
        Results.QuantumYield(i) = {round(QuantumYield, 4, 'significant')};
    end
    % Save results
    writetable(Results, fullfile(SampleFolder, ['QY_results_ref_', ReferenceAbsorption{1}.Compound, '.csv']));
end