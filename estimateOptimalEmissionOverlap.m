function [OptimalWavelength, Fig] = estimateOptimalEmissionOverlap(varargin)
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
    % Import emission data of all samples
    Emission.Sample = cell(length(SampleFolders), 1);
    for i = 1:length(SampleFolders)
        D = dir(fullfile(SampleFolders{i}, 'data', strcat('*em*', Solvent, '*.ifx')));
        % If more of the same measurement, keep only the most recent
        Names = arrayfun(@(x) strsplit(x.name, '_'), D, 'UniformOutput', false);
        Names = vertcat(Names{:});
        OldData = zeros(length(Names(:, 3)), 1);
        NewestDate = num2str(max(cellfun(@(x) str2num(x), Names(:, 1))));
        NotNewestDate = ~strcmp(Names(:,1), NewestDate);
        D(NotNewestDate, :) = [];
        Emission.Sample{i} = readIfx(fullfile(D.folder, D.name));
    end
    % Import quantum yield reference table
    QuantumYieldTable = readtable(fullfile(getenv('userprofile'), 'Documents/Matlab/SpecTools', 'ref_quantum_yield.csv'));
    % Import reference emission data
    File = dir(fullfile(ReferenceFolder, 'data', strcat('*em*.ifx')));
    Emission.Reference = arrayfun(@(x) readIfx(fullfile(x.folder, x.name)), File, 'UniformOutput', false);
    % Determine suitable references from presence in table values
    Compounds = cellfun(@(x) x.Compound, Emission.Reference, 'UniformOutput', false);
    Solvents = cellfun(@(x) x.Solvent, Emission.Reference, 'UniformOutput', false);
    CompoundInReferenceTable = cellfun(@(x, y) any(and(strcmp(QuantumYieldTable.Abbreviation, x), strcmp(QuantumYieldTable.Solvent, y))), Compounds, Solvents);
    Emission.Reference = Emission.Reference(CompoundInReferenceTable);
    % Calculate normalized emission intensity
    Emission.NormalizedIntensity.Sample = cellfun(@(x) [x.Data.EmissionWavelength, x.Data.Intensity / max(x.Data.Intensity(x.Data.EmissionWavelength >= x.PeakExpectedAbove))], Emission.Sample, 'UniformOutput', false);
    Emission.NormalizedIntensity.Reference = [Emission.Reference{1}.Data.EmissionWavelength, Emission.Reference{1}.Data.Intensity / max(Emission.Reference{1}.Data.Intensity(Emission.Reference{1}.Data.Intensity >= Emission.Reference{1}.PeakExpectedAbove))];
    % Calculate concentration-normalized emission intensity
    Emission.ConcentrationNormalizedIntensity.Sample = cellfun(@(x) [x.Data.EmissionWavelength, x.Data.Intensity / x.Concentration], Emission.Sample, 'UniformOutput', false);
    Emission.ConcentrationNormalizedIntensity.Reference = [Emission.Reference{1}.Data.EmissionWavelength, Emission.Reference{1}.Data.Intensity / Emission.Reference{1}.Concentration];
    % Discard wavelengths that do not overlap
    OverlappingWavelength.Min = max([min(Emission.Reference{1}.Data.EmissionWavelength); cellfun(@(x) min(x.Data.EmissionWavelength), Emission.Sample)]);
    OverlappingWavelength.Max = min([max(Emission.Reference{1}.Data.EmissionWavelength); cellfun(@(x) max(x.Data.EmissionWavelength), Emission.Sample)]);
    UsefulSampleIndex = cellfun(@(x) and(OverlappingWavelength.Min <= x(:, 1), x(:, 1) <= OverlappingWavelength.Max), Emission.ConcentrationNormalizedIntensity.Sample, 'UniformOutput', false);
    Emission.ConcentrationNormalizedIntensity.Sample = cellfun(@(x, y) x(y, :), Emission.ConcentrationNormalizedIntensity.Sample, UsefulSampleIndex, 'UniformOutput', false);
    UsefulReferenceIndex = and(OverlappingWavelength.Min <= Emission.ConcentrationNormalizedIntensity.Reference(:, 1), Emission.ConcentrationNormalizedIntensity.Reference(:, 1) <= OverlappingWavelength.Max);
    Emission.ConcentrationNormalizedIntensity.Reference = Emission.ConcentrationNormalizedIntensity.Reference(UsefulReferenceIndex, :);
    % Determine wavelength with largest emission overlap
    Wavelength = Emission.ConcentrationNormalizedIntensity.Reference(:, 1);
    % Max of sum of normalized intensity will yield the best overlap if all
    % intensities were equally bright
    Intensity = cellfun(@(x, y) x.Data.NormalizedIntensity(y), Emission.Sample, UsefulSampleIndex, 'UniformOutput', false).';
    Intensity = sum(horzcat(Intensity{:}, Emission.Reference{1}.Data.NormalizedIntensity(UsefulReferenceIndex)), 2);
    [~, Index] = max(sum(Intensity, 2));
    OptimalWavelength = Wavelength(Index);
    fprintf('Optimal emission overlap wavelength: %d nm\n', OptimalWavelength);
    % Plot suggested emission measurement
    figure;
    hold on
    plot(Emission.NormalizedIntensity.Reference(:, 1), Emission.NormalizedIntensity.Reference(:, 2), 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', Emission.Reference{1}.Compound, Emission.Reference{1}.Solvent));
    title('\bf{Emission}', 'Interpreter', 'latex');
    xlabel('wavelength [nm]', 'Interpreter', 'latex');
    ylabel('normalized Intensity [M$^{-1}$]', 'Interpreter', 'latex');
    cellfun(@(x, y) plot(x(:,1), x(:,2), 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', y.Compound, y.Solvent)), Emission.NormalizedIntensity.Sample, Emission.Sample);
    plot([OptimalWavelength, OptimalWavelength], get(gca, 'ylim'), '--k', 'DisplayName', sprintf('Optimal Overlap: %d nm', OptimalWavelength));
    legend({}, 'Location', 'NorthEast', 'Interpreter', 'latex');
    hold off
end