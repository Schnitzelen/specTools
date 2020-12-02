function Results = calculateQuantumYield(varargin)
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
    % Make sure that data is provided
    assert(~isempty(SampleFolder), 'No Sample Selected!')
    assert(~isempty(ReferenceFolder), 'No Reference Selected!')
    % Load physical property tables
    TableValuePath = fullfile(getenv('userprofile'), 'Documents', 'Matlab', 'SpecTools');
    QuantumYieldTable = readtable(fullfile(TableValuePath, 'ref_quantum_yield.csv'));
    RefractiveIndexTable = readtable(fullfile(TableValuePath, 'ref_refractive_index.csv'));
    % Locate files
    SampleAbsFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(SampleFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'TXT');
    SampleEmFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(SampleFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'ifx');
    ReferenceAbsFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(ReferenceFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'TXT');
    ReferenceEmFiles = listExperimentFilesInDir('AbsoluteFolder', fullfile(ReferenceFolder, 'data'), 'ExperimentType', 'qy', 'FileExtension', 'ifx');
    % Keep only sample files that are abs-em pairs
    [~, SampleAbsFileNames, ~] = cellfun(@(x) fileparts(x), SampleAbsFiles, 'UniformOutput', false);
    [~, SampleEmFileNames, ~] = cellfun(@(x) fileparts(x), SampleEmFiles, 'UniformOutput', false);
    PairIdx = cellfun(@(x) strcmp(SampleAbsFileNames', x), SampleEmFileNames, 'UniformOutput', false);
    PairIdx = vertcat(PairIdx{:});
    SampleAbsFiles = SampleAbsFiles(any(PairIdx, 1));
    SampleEmFiles = SampleEmFiles(any(PairIdx, 2));
    % Keep only reference abs files that are present in the quantum yield table
    [~, ReferenceAbsFileNames, ~] = cellfun(@(x) fileparts(x), ReferenceAbsFiles, 'UniformOutput', false);
    ReferenceAbsFileNames = regexp(ReferenceAbsFileNames, '_', 'split');
    ReferenceAbsFileNames = vertcat(ReferenceAbsFileNames{:});
    ReferenceCompounds = ReferenceAbsFileNames(:, 5);
    ReferenceSolvents = ReferenceAbsFileNames(:, 3);
    KeepIdx = cellfun(@(c, s) any(and(strcmp(QuantumYieldTable.Abbreviation, c), strcmp(QuantumYieldTable.Solvent, s))), ReferenceCompounds, ReferenceSolvents);
    ReferenceAbsFiles = ReferenceAbsFiles(KeepIdx);
    % Keep only reference files that are abs-em pairs
    [~, ReferenceAbsFileNames, ~] = cellfun(@(x) fileparts(x), ReferenceAbsFiles, 'UniformOutput', false);
    [~, ReferenceEmFileNames, ~] = cellfun(@(x) fileparts(x), ReferenceEmFiles, 'UniformOutput', false);
    PairIdx = cellfun(@(x) strcmp(ReferenceAbsFileNames', x), ReferenceEmFileNames, 'UniformOutput', false);
    PairIdx = vertcat(PairIdx{:});
    ReferenceAbsFiles = ReferenceAbsFiles(any(PairIdx, 1));
    ReferenceEmFiles = ReferenceEmFiles(any(PairIdx, 2));
    % Determine unique experiments
    [~, SampleAbsFileNames, ~] = cellfun(@(x) fileparts(x), SampleAbsFiles, 'UniformOutput', false);
    SampleAbsFileNames = regexp(SampleAbsFileNames, '_', 'split');
    SampleAbsFileNames = vertcat(SampleAbsFileNames{:});
    SampleUniqueExperiments = unique(SampleAbsFileNames(:, 1));
    [~, ReferenceAbsFileNames, ~] = cellfun(@(x) fileparts(x), ReferenceAbsFiles, 'UniformOutput', false);
    ReferenceAbsFileNames = regexp(ReferenceAbsFileNames, '_', 'split');
    ReferenceAbsFileNames = vertcat(ReferenceAbsFileNames{:});
    ReferenceUniqueExperiments = unique(ReferenceAbsFileNames(:, 1));
    % Determine unique experiments that are present for both sample and
    % reference
    PairIdx = cellfun(@(x) strcmp(SampleUniqueExperiments', x), ReferenceUniqueExperiments, 'UniformOutput', false);
    PairIdx = vertcat(PairIdx{:});
    UniqueExperiments = SampleUniqueExperiments(any(PairIdx, 1));
    % Keep only samples that are in unique experiments
    [~, SampleAbsFileNames, ~] = cellfun(@(x) fileparts(x), SampleAbsFiles, 'UniformOutput', false);
    SampleAbsFileNames = regexp(SampleAbsFileNames, '_', 'split');
    SampleAbsFileNames = vertcat(SampleAbsFileNames{:});
    KeepIdx = cellfun(@(x) strcmp(SampleAbsFileNames(:, 1), x), UniqueExperiments', 'UniformOutput', false);
    KeepIdx = any(horzcat(KeepIdx{:}), 2);
    SampleAbsFiles = sort(SampleAbsFiles(KeepIdx));
    [~, SampleEmFileNames, ~] = cellfun(@(x) fileparts(x), SampleEmFiles, 'UniformOutput', false);
    SampleEmFileNames = regexp(SampleEmFileNames, '_', 'split');
    SampleEmFileNames = vertcat(SampleEmFileNames{:});
    KeepIdx = cellfun(@(x) strcmp(SampleEmFileNames(:, 1), x), UniqueExperiments', 'UniformOutput', false);
    KeepIdx = any(horzcat(KeepIdx{:}), 2);
    SampleEmFiles = sort(SampleEmFiles(KeepIdx));
    % Keep only references that are in unique experiments
    [~, ReferenceAbsFileNames, ~] = cellfun(@(x) fileparts(x), ReferenceAbsFiles, 'UniformOutput', false);
    ReferenceAbsFileNames = regexp(ReferenceAbsFileNames, '_', 'split');
    ReferenceAbsFileNames = vertcat(ReferenceAbsFileNames{:});
    KeepIdx = cellfun(@(x) strcmp(ReferenceAbsFileNames(:, 1), x), UniqueExperiments', 'UniformOutput', false);
    KeepIdx = any(horzcat(KeepIdx{:}), 2);
    ReferenceAbsFiles = sort(ReferenceAbsFiles(KeepIdx));
    [~, ReferenceEmFileNames, ~] = cellfun(@(x) fileparts(x), ReferenceEmFiles, 'UniformOutput', false);
    ReferenceEmFileNames = regexp(ReferenceEmFileNames, '_', 'split');
    ReferenceEmFileNames = vertcat(ReferenceEmFileNames{:});
    KeepIdx = cellfun(@(x) strcmp(ReferenceEmFileNames(:, 1), x), UniqueExperiments', 'UniformOutput', false);
    KeepIdx = any(horzcat(KeepIdx{:}), 2);
    ReferenceEmFiles = sort(ReferenceEmFiles(KeepIdx));
    % Import samples
    SampleAbsorption = cell(length(SampleAbsFiles), 1);
    SampleEmission = cell(length(SampleEmFiles), 1);
    parfor i = 1:length(SampleAbsFiles)
        SampleAbsorption{i} = readAbs(SampleAbsFiles{i});
        SampleEmission{i} = readEm(SampleEmFiles{i});
    end
    % Import references
    ReferenceAbsorption = cell(length(ReferenceAbsFiles), 1);
    ReferenceEmission = cell(length(ReferenceEmFiles), 1);
    parfor i = 1:length(ReferenceAbsFiles)
        ReferenceAbsorption{i} = readAbs(ReferenceAbsFiles{i});
        ReferenceEmission{i} = readEm(ReferenceEmFiles{i});
    end
    % Fetch sample parameters
    SampleTitles = cellfun(@(x) x.Title, SampleAbsorption, 'UniformOutput', false);
    SampleTitles = regexp(SampleTitles, '_', 'split');
    SampleTitles = vertcat(SampleTitles{:});
    SampleExperiments = SampleTitles(:, 1);
    SampleSolvents = SampleTitles(:, 3);
    [~, SampleUniqueIdx] = unique(cellfun(@(e, s) strcat(e, s), SampleExperiments, SampleSolvents, 'UniformOutput', false));
    % Fetch reference parameters
    ReferenceTitles = cellfun(@(x) x.Title, ReferenceAbsorption, 'UniformOutput', false);
    ReferenceTitles = regexp(ReferenceTitles, '_', 'split');
    ReferenceTitles = vertcat(ReferenceTitles{:});
    ReferenceExperiments = ReferenceTitles(:, 1);
    ReferenceSolvents = ReferenceTitles(:, 3);
    ReferenceCompounds = ReferenceTitles(:, 5);
    %[~, ReferenceUniqueIdx] = unique(cellfun(@(e, s) strcat(e, s), ReferenceExperiments, ReferenceSolvents, 'UniformOutput', false));
    % Build results table
    Results = cell2table(cell(length(SampleUniqueIdx), 6), 'VariableNames', {'Experiment', 'Solvent', 'QuantumYield', 'ReferenceCompound', 'ReferenceSolvent', 'ReferenceQuantumYield'});
    Results.Experiment = SampleExperiments(SampleUniqueIdx);
    Results.Solvent = SampleSolvents(SampleUniqueIdx);
    ReferenceIdx = cellfun(@(x) strcmp(ReferenceExperiments, x), Results.Experiment, 'UniformOutput', false);
    ReferenceIdx = cellfun(@(x) find(x, 1, 'first'), ReferenceIdx);
    Results.ReferenceCompound = ReferenceCompounds(ReferenceIdx);
    Results.ReferenceSolvent = ReferenceSolvents(ReferenceIdx);
    % Lookup refractive indices
    SampleSolventRefractiveIndex = cellfun(@(x) RefractiveIndexTable.RefractiveIndex(strcmp(RefractiveIndexTable.Abbreviation, x)), Results.Solvent);
    ReferenceSolventRefractiveIndex = cellfun(@(x) RefractiveIndexTable.RefractiveIndex(strcmp(RefractiveIndexTable.Abbreviation, x)), Results.ReferenceSolvent);
    % Lookup reference quantum yield
    SolventIdx = cellfun(@(x) strcmp(QuantumYieldTable.Abbreviation, x), Results.ReferenceCompound, 'UniformOutput', false);
    CompoundIdx = cellfun(@(x) strcmp(QuantumYieldTable.Solvent, x), Results.ReferenceSolvent, 'UniformOutput', false);
    Idx = cellfun(@(s, c) find(and(s, c)), SolventIdx, CompoundIdx);
    Results.ReferenceQuantumYield = QuantumYieldTable.QuantumYield(Idx);
    % Calculate gradients
    AbsIdx = cellfun(@(e, s) strcmp(SampleExperiments, e) & strcmp(SampleSolvents, s), Results.Experiment, Results.Solvent, 'UniformOutput', false);
    EmIdx = AbsIdx; % assumed to be okay, as import-files are sorted
    SampleGradient = cellfun(@(ai, ei) calculateGradient(SampleAbsorption(ai), SampleEmission(ei)), AbsIdx, EmIdx);
    AbsIdx = cellfun(@(e, s) strcmp(ReferenceExperiments, e) & strcmp(ReferenceSolvents, s), Results.Experiment, Results.ReferenceSolvent, 'UniformOutput', false);
    EmIdx = AbsIdx; % assumed to be okay, as import-files are sorted
    ReferenceGradient = cellfun(@(ai, ei) calculateGradient(ReferenceAbsorption(ai), ReferenceEmission(ei)), AbsIdx, EmIdx);
    % Calculate quantum yield
    Results.QuantumYield = round(Results.ReferenceQuantumYield .* (SampleGradient ./ ReferenceGradient) .* ( SampleSolventRefractiveIndex.^2 ./ ReferenceSolventRefractiveIndex.^2 ), 4, 'significant');
    % Save results
    writetable(Results, fullfile(SampleFolder, ['QY_results_ref_', ReferenceAbsorption{1}.Compound, '.csv']));
end