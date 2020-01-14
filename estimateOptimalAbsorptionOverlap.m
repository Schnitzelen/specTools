function [OptimalWavelength, OptimalConcentration, Fig] = estimateOptimalAbsorptionOverlap(varargin)
    % Confirm that all arguments come in pairs
    assert(rem(length(varargin), 2) == 0, 'Wrong number of arguments');
    % Set provided arguments
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'SampleFolders'
                SampleFolders = varargin{i + 1};
            case 'Solvent'
                Solvent = varargin{i + 1};
            case 'ReferenceFolder'
                ReferenceFolder = varargin{i + 1};
        end
    end
    % If any arguments are not defined by now, prompt the user
    if ~exist('SampleFolders')
        SampleFolders = cell(0);
        SampleFolders{1} = uigetdir('C:\Users\brianbj\OneDrive - Syddansk Universitet\Samples', 'Please Choose First Sample Folder');
        Stop = false;
        while ~Stop
            SampleFolder = uigetdir('C:\Users\brianbj\OneDrive - Syddansk Universitet\Samples', 'Please Choose Next Sample Folder');
            if SampleFolder == 0
                Stop = true;
            else
                SampleFolders = vertcat(SampleFolders, SampleFolder);
            end
        end
    end
    if ~exist('ReferenceFolder')
        ReferenceFolder = uigetdir('C:\Users\brianbj\OneDrive - Syddansk Universitet\Samples', 'Please Choose Reference Folder');
    end
    if ~exist('Solvent')
        Solvent = input('Please Specify Solvent: ', 's');
    end
    % Import absorption data of all samples
    Absorption.Sample = cell(length(SampleFolders), 1);
    for i = 1:length(SampleFolders)
        D = dir(fullfile(SampleFolders{i}, 'data', strcat('*abs*', Solvent, '*.TXT')));
        % If more of the same measurement, keep only the most recent
        Names = arrayfun(@(x) strsplit(x.name, '_'), D, 'UniformOutput', false);
        Names = vertcat(Names{:});
        OldData = zeros(length(Names(:, 3)), 1);
        NewestDate = num2str(max(cellfun(@(x) str2num(x), Names(:, 1))));
        NotNewestDate = ~strcmp(Names(:,1), NewestDate);
        D(NotNewestDate, :) = [];
        Absorption.Sample{i} = readAbs(fullfile(D.folder, D.name));
    end
    % Import reference absorption data
    File = dir(fullfile(ReferenceFolder, 'data', strcat('*abs*.TXT')));
    Absorption.Reference = arrayfun(@(x) readAbs(fullfile(x.folder, x.name)), File, 'UniformOutput', false);
    % Import quantum yield reference table
    QuantumYieldTable = readtable(fullfile(getenv('userprofile'), 'Documents/Matlab/SpecTools', 'ref_quantum_yield.csv'));
    % Determine suitable references from presence in table values
    Compounds = cellfun(@(x) x.Compound, Absorption.Reference, 'UniformOutput', false);
    Solvents = cellfun(@(x) x.Solvent, Absorption.Reference, 'UniformOutput', false);
    CompoundInReferenceTable = cellfun(@(x, y) any(and(strcmp(QuantumYieldTable.Abbreviation, x), strcmp(QuantumYieldTable.Solvent, y))), Compounds, Solvents);
    Absorption.Reference = Absorption.Reference(CompoundInReferenceTable);
    % Calculate normalized absorption
    Absorption.Normalized.Sample = cellfun(@(x) [x.Data.Wavelength, x.Data.Absorption / max(x.Data.Absorption(x.Data.Wavelength >= x.PeakExpectedAbove))], Absorption.Sample, 'UniformOutput', false);
    Absorption.Normalized.Reference = [Absorption.Reference{1}.Data.Wavelength, Absorption.Reference{1}.Data.Absorption / max(Absorption.Reference{1}.Data.Absorption(Absorption.Reference{1}.Data.Wavelength >= Absorption.Reference{1}.PeakExpectedAbove))];
    % Calculate concentration normalized absorption
    ConcentrationNormalized.Sample = cellfun(@(x) [x.Data.Wavelength, x.Data.Absorption / x.Concentration], Absorption.Sample, 'UniformOutput', false);
    ConcentrationNormalized.Reference = [Absorption.Reference{1}.Data.Wavelength, Absorption.Reference{1}.Data.Absorption / Absorption.Reference{1}.Concentration];
    % Discard wavelengths that do not overlap
    OverlappingWavelength.Min = max([Absorption.Reference{1}.PeakExpectedAbove; min(Absorption.Reference{1}.Data.Wavelength); cellfun(@(x) min(x.Data.Wavelength), Absorption.Sample)]);
    OverlappingWavelength.Max = min([max(Absorption.Reference{1}.Data.Wavelength); cellfun(@(x) max(x.Data.Wavelength), Absorption.Sample)]);
    UsefulSampleIndex = cellfun(@(x) and(OverlappingWavelength.Min <= x(:, 1), x(:, 1) <= OverlappingWavelength.Max), Absorption.Normalized.Sample, 'UniformOutput', false);
    Absorption.Normalized.Sample = cellfun(@(x, y) x(y, :), Absorption.Normalized.Sample, UsefulSampleIndex, 'UniformOutput', false);
    UsefulReferenceIndex = and(OverlappingWavelength.Min <= Absorption.Normalized.Reference(:, 1), Absorption.Normalized.Reference(:, 1) <= OverlappingWavelength.Max);
    Absorption.Normalized.Reference = Absorption.Normalized.Reference(UsefulReferenceIndex, :);
    % Determine wavelength with largest absorption overlap
    Wavelength = Absorption.Normalized.Reference(:, 1); 
    % Max of sum of normalized absorption will yield the best overlap if all
    % samples were absorbing equally
    SummedAbsorption = cellfun(@(x) x(:, 2), Absorption.Normalized.Sample, 'UniformOutput', false).';
    SummedAbsorption = sum(horzcat(SummedAbsorption{:}, Absorption.Reference{1}.Data.Absorption(UsefulReferenceIndex)), 2);
    [~, Index] = max(SummedAbsorption);
    OptimalWavelength = Wavelength(Index);
    fprintf('Optimal absorption overlap wavelength: %d nm\n', OptimalWavelength)
    % Plot suggested emission measurement
    figure;
    hold on
    title('\bf{Absorption}', 'Interpreter', 'latex');
    xlabel('wavelength [nm]', 'Interpreter', 'latex');
    ylabel('normalized absorption [M$^{-1}$]', 'Interpreter', 'latex');
    Index = Absorption.Normalized.Reference(:, 1) > 350; 
    YLim = max([max(Absorption.Normalized.Reference(Index, 2)); cellfun(@(x) max(x(Index, 2)), Absorption.Normalized.Sample)])* 1.1;
    ylim([0, YLim]);
    Plot = plot(Absorption.Normalized.Reference(:, 1), Absorption.Normalized.Reference(:, 2), 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', Absorption.Reference{1}.Compound, Absorption.Reference{1}.Solvent));
    cellfun(@(x, y) plot(x(:,1), x(:,2), 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', y.Compound, y.Solvent)), Absorption.Normalized.Sample, Absorption.Sample);
    plot([OptimalWavelength, OptimalWavelength], get(gca, 'ylim'), '--k', 'DisplayName', sprintf('Optimal Overlap: %d nm', OptimalWavelength));
    legend({}, 'Location', 'NorthWest', 'Interpreter', 'latex');
    hold off
    % Determine optimal concentrations
    TargetAbsorptionMax = 0.1;
    OptimalConcentration.Sample = TargetAbsorptionMax ./ cellfun(@(x) x(find(x(:, 1) == OptimalWavelength), 2), ConcentrationNormalized.Sample);
    OptimalConcentration.Reference = TargetAbsorptionMax / ConcentrationNormalized.Reference(find(ConcentrationNormalized.Reference(:, 1) == OptimalWavelength), 2);
    for i = 1:length(OptimalConcentration.Sample)
        Con = [0.2, 0.4, 0.6, 0.8, 1] * OptimalConcentration.Sample(i);
        fprintf('Suggested concentrations for %s in %s: [M]\n', Absorption.Sample{i}.Compound, Absorption.Sample{i}.Solvent)
        fprintf('%d \t%d \t%d \t%d \t%d\n', round(Con(1), 4, 'significant'), round(Con(2), 4, 'significant'), round(Con(3), 4, 'significant'), round(Con(4), 4, 'significant'), round(Con(5), 4, 'significant'))
    end
    Con = [0.2, 0.4, 0.6, 0.8, 1] * OptimalConcentration.Reference;
    fprintf('Suggested concentrations for %s in %s: [M]\n', Absorption.Reference{1}.Compound, Absorption.Reference{1}.Solvent)
    fprintf('%d \t%d \t%d \t%d \t%d\n', round(Con(1), 4, 'significant'), round(Con(2), 4, 'significant'), round(Con(3), 4, 'significant'), round(Con(4), 4, 'significant'), round(Con(5), 4, 'significant'))
end