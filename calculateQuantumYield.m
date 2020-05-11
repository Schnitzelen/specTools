function calculateQuantumYield(varargin)
    % Prepare arguments
    SampleFolder = {};
    ReferenceFolder = {};
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
        SampleFolder{1} = uigetdir(pwd(), 'Please Choose Sample Folder');
    end
    assert(~isempty(SampleFolder) && isa(SampleFolder{1}, 'char'), 'No Sample Selected!')
    if isempty(ReferenceFolder)
        %ReferenceFolder{1} = 'C:\Users\schni\OneDrive - Syddansk Universitet\Samples\NR';
        ReferenceFolder{1} = uigetdir(pwd(), 'Please Choose Reference Folder');
    end
    assert(~isempty(ReferenceFolder) && isa(ReferenceFolder{1}, 'char'), 'No Reference Selected!')
    % Locate sample files
    SampleFiles =  dir(fullfile(SampleFolder{1}, 'data', '*_qy_*'));
    % Fetch unique experiment dates
    [~, FileNames, ~] = cellfun(@(x) fileparts(x), {SampleFiles.name}, 'UniformOutput', false);
    FileNames = regexp(FileNames, '_', 'split');
    SampleDates = cellfun(@(x) x{1}, FileNames, 'UniformOutput', false);
    UniqueDates = unique(SampleDates);
    % Keep only dates with more than one measurement
    Idx = cellfun(@(x) 1 < sum(strcmp(SampleDates, x)), UniqueDates);
    UniqueDates = UniqueDates(Idx);
    % Locate reference files
    ReferenceFiles =  dir(fullfile(ReferenceFolder{1}, 'data', '*_qy_*'));
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
    Results = cell2table(cell(length(UniqueDates), 5), 'VariableNames', {'Solvent', 'QuantumYield', 'RefCompound', 'RefSolvent', 'RefQuantumYield'});
    % Load physical property tables
    TableValuePath = fullfile(getenv('userprofile'), 'Documents', 'Matlab', 'SpecTools');
    QuantumYieldTable = readtable(fullfile(TableValuePath, 'ref_quantum_yield.csv'));
    RefractiveIndexTable = readtable(fullfile(TableValuePath, 'ref_refractive_index.csv'));
    % Calculate quantum yield for each experiment date
    for i = 1:length(UniqueDates)
        Date = UniqueDates{i};
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
        assert(sum(Idx) == 1, 'Multiple Reference Quantum Yields Detected For Experiment %s', Date)
        Results.RefQuantumYield(i) = {QuantumYieldTable.QuantumYield(Idx)};
        Idx = strcmp(strrep(Solvent, ',', '.'), RefractiveIndexTable.Abbreviation);
        assert(sum(Idx) == 1, 'Multiple Reference Refractive Indices Detected For Experiment %s', Date)
        ReferenceRefractiveIndex = RefractiveIndexTable.RefractiveIndex(Idx);
        % Fetch sample information
        Idx = cellfun(@(x) contains(x.Title, Date), SampleAbsorption);
        Solvent = unique(cellfun(@(x) x.Solvent, SampleAbsorption(Idx), 'UniformOutput', false));
        assert(length(Solvent) == 1, 'Multiple Sample Solvents Detected For Date %s', Date)
        Results.Solvent(i) = Solvent;
        Idx = strcmp(strrep(Solvent, ',', '.'), RefractiveIndexTable.Abbreviation);
        assert(sum(Idx) == 1, 'Multiple Reference Refractive Indices Detected For Experiment %s', Date)
        SampleRefractiveIndex = RefractiveIndexTable.RefractiveIndex(Idx);
        % Calculate sample gradient
        Idx = cellfun(@(x) contains(x.Title, Date), SampleAbsorption);
        Solvent = unique(cellfun(@(x) x.Solvent, SampleAbsorption(Idx), 'UniformOutput', false));
        assert(length(Solvent) == 1, 'Multiple Sample Solvents Detected For Date %s', Date)
        Results.Solvent(i) = Solvent;
        SampleGradient = calculateGradient(SampleAbsorption(Idx), SampleEmission(Idx));
        % Calculate sample quantum yield
        QuantumYield = Results.RefQuantumYield{i} * ( SampleGradient / ReferenceGradient ) * ( SampleRefractiveIndex^2 / ReferenceRefractiveIndex^2 );
        Results.QuantumYield(i) = {round(QuantumYield, 4, 'significant')};
    end
    % Save results
    writetable(Results, fullfile(SampleFolder{1}, ['QY_results_ref_', ReferenceAbsorption{1}.Compound, '.csv']));
end