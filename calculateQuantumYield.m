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
    % Locate files
    SampleAbsFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(SampleFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'TXT');
    SampleEmFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(SampleFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'ifx');
    ReferenceAbsFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(ReferenceFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'TXT');
    ReferenceEmFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(ReferenceFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'ifx');
    % sample abs-em pairs
    % isolate unique experiment date-replicate
    % locate reference files from same experiment date-replicate
    % 
    
    
    % Remove sample files that do not come in abs-em pairs
    [~, SampleAbsFileNames, ~] = cellfun(@fileparts, SampleAbsFiles, 'UniformOutput', false);
    [~, SampleEmFileNames, ~] = cellfun(@fileparts, SampleEmFiles, 'UniformOutput', false);
    PairFileNames = intersect(SampleAbsFileNames, SampleEmFileNames');
    KeepIdx = cellfun(@(x) any(strcmp(SampleAbsFileNames, x)), PairFileNames);
    SampleAbsFiles = SampleAbsFiles(KeepIdx);
    KeepIdx = cellfun(@(x) any(strcmp(SampleEmFileNames, x)), PairFileNames);
    SampleEmFiles = SampleEmFiles(KeepIdx);
    % Remove reference files that do not come in abs-em pairs
    [~, ReferenceAbsFileNames, ~] = cellfun(@fileparts, ReferenceAbsFiles, 'UniformOutput', false);
    [~, ReferenceEmFileNames, ~] = cellfun(@fileparts, ReferenceEmFiles, 'UniformOutput', false);
    PairFileNames = intersect(ReferenceAbsFileNames, ReferenceEmFileNames');
    KeepIdx = cellfun(@(x) any(strcmp(ReferenceAbsFileNames, x)), PairFileNames);
    ReferenceAbsFiles = ReferenceAbsFiles(KeepIdx);
    KeepIdx = cellfun(@(x) any(strcmp(ReferenceEmFileNames, x)), PairFileNames);
    ReferenceEmFiles = ReferenceEmFiles(KeepIdx);
    % Fetch unique combinations of sample experiment dates and solvents
    [~, SampleFileNames, ~] = cellfun(@fileparts, SampleAbsFiles, 'UniformOutput', false);
    SampleFileNames = regexp(SampleFileNames, '_', 'split');
    SampleFileNames = vertcat(SampleFileNames{:});
    SampleDates = SampleFileNames(:, 1);
    SampleSolvents = SampleFileNames(:, 3);
    [~, UniqueSampleCombinationsIdx, ~] = unique(cellfun(@(d, s) strcat(d, s), SampleDates, SampleSolvents, 'UniformOutput', false));
    % Remove sample files from dates with less than two measurements
    UniqueSampleDates = SampleDates(UniqueSampleCombinationsIdx);
    HasLessThanTwoMeasurements = cellfun(@(x) 2 > sum(length(strcmp(SampleAbsFiles, x))), UniqueSampleDates);
    DatesWithLessThanTwoMeasurements = UniqueSampleDates(HasLessThanTwoMeasurements);
    if ~isempty(DatesWithLessThanTwoMeasurements)
        KeepIdx = cellfun(@(x) ~any(strcmp(x, DatesWithLessThanTwoMeasurements)), SampleDates);
        SampleAbsFiles = SampleAbsFiles(KeepIdx);
        SampleEmFiles = SampleEmFiles(KeepIdx);
    end
    % Fetch unique combinations of reference experiment dates and solvents
    [~, ReferenceFileNames, ~] = cellfun(@fileparts, ReferenceAbsFiles, 'UniformOutput', false);
    ReferenceFileNames = regexp(ReferenceFileNames, '_', 'split');
    ReferenceFileNames = vertcat(ReferenceFileNames{:});
    ReferenceDates = ReferenceFileNames(:, 1);
    ReferenceSolvents = ReferenceFileNames(:, 3);
    [~, UniqueReferenceCombinationsIdx, ~] = unique(cellfun(@(d, s) strcat(d, s), ReferenceDates, ReferenceSolvents, 'UniformOutput', false));
    % Remove reference files from dates with less than two measurements
    UniqueReferenceDates = ReferenceDates(UniqueReferenceCombinationsIdx);
    HasLessThanTwoMeasurements = cellfun(@(x) 2 > sum(length(strcmp(ReferenceAbsFiles, x))), UniqueReferenceDates);
    DatesWithLessThanTwoMeasurements = UniqueReferenceDates(HasLessThanTwoMeasurements);
    if ~isempty(DatesWithLessThanTwoMeasurements)
        KeepIdx = cellfun(@(x) ~any(strcmp(x, DatesWithLessThanTwoMeasurements)), ReferenceDates);
        ReferenceAbsFiles = ReferenceAbsFiles(KeepIdx);
        ReferenceEmFiles = ReferenceEmFiles(KeepIdx);
    end
    % Update sample and reference experiment dates
    [~, SampleFileNames, ~] = cellfun(@fileparts, SampleAbsFiles, 'UniformOutput', false);
    SampleFileNames = regexp(SampleFileNames, '_', 'split');
    SampleFileNames = vertcat(SampleFileNames{:});
    SampleDates = SampleFileNames(:, 1);
    [~, ReferenceFileNames, ~] = cellfun(@fileparts, ReferenceAbsFiles, 'UniformOutput', false);
    ReferenceFileNames = regexp(ReferenceFileNames, '_', 'split');
    ReferenceFileNames = vertcat(ReferenceFileNames{:});
    ReferenceDates = ReferenceFileNames(:, 1);
    % Identify which dates are present in both sample and reference
    UniqueSampleDates = unique(SampleDates);
    UniqueReferenceDates = unique(ReferenceDates);
    KeepDates = intersect(UniqueSampleDates, UniqueReferenceDates);
    assert(~isempty(KeepDates), 'No Overlap Between Sample and Reference Data')
    % Keep only samples that do have a reference
    KeepIdx = cellfun(@(x) any(strcmp(x, KeepDates)), SampleDates);
    SampleAbsFiles = SampleAbsFiles(KeepIdx);
    SampleEmFiles = SampleEmFiles(KeepIdx);
    % Keep only reference that do have a sample
    KeepIdx = cellfun(@(x) any(strcmp(x, KeepDates)), ReferenceDates);
    ReferenceAbsFiles = ReferenceAbsFiles(KeepIdx);
    ReferenceEmFiles = ReferenceEmFiles(KeepIdx);
    % Import samples
    SampleAbsorption = cell(length(SampleAbsFiles), 1);
    SampleEmission = cell(length(SampleEmFiles), 1);
    for i = 1:length(SampleAbsFiles)
        SampleAbsorption{i} = readAbs(SampleAbsFiles{i});
        SampleEmission{i} = readEm(SampleEmFiles{i});
    end
    % Import references
    ReferenceAbsorption = cell(length(ReferenceAbsFiles), 1);
    ReferenceEmission = cell(length(ReferenceEmFiles), 1);
    for i = 1:length(ReferenceAbsFiles)
        ReferenceAbsorption{i} = readAbs(ReferenceAbsFiles{i});
        ReferenceEmission{i} = readEm(ReferenceEmFiles{i});
    end
    % Create results table
    Dates = cellfun(@(x) x.Date, SampleAbsorption, 'UniformOutput', false);
    Solvents = cellfun(@(x) x.Solvent, SampleAbsorption, 'UniformOutput', false);
    [~, UniqueIdx, ~] = unique(cellfun(@(d, s) strcat(d, s), Dates, Solvents, 'UniformOutput', false));
    Results = cell2table(cell(length(UniqueIdx), 5), 'VariableNames', {'Solvent', 'QuantumYield', 'RefCompound', 'RefSolvent', 'RefQuantumYield'});
    % Load physical property tables
    TableValuePath = fullfile(getenv('userprofile'), 'Documents', 'Matlab', 'SpecTools');
    QuantumYieldTable = readtable(fullfile(TableValuePath, 'ref_quantum_yield.csv'));
    RefractiveIndexTable = readtable(fullfile(TableValuePath, 'ref_refractive_index.csv'));
    % Calculate quantum yield for each experiment date
    for i = 1:length(UniqueIdx)
        Date = Dates{i};
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
        Solvent = SampleAbsorption{i}.Solvent;
        assert(~isempty(Solvent), 'Sample Solvent Not Detected For Date %s', Date)
        Results.Solvent(i) = {Solvent};
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