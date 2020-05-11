function [Report, Fig] = estimateOptimalEmissionOverlap(varargin)
    % Default arguments
    SpectralPeakPadding = 10; % nm
    PeakExpectedAbove = 350; % nm
    SampleFolder = {};
    SampleSolvent = {};
    ReferenceFolder = {};
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'SpectralPeakPadding'
                SpectralPeakPadding = varargin{i + 1};
            case 'PeakExpectedAbove'
                PeakExpectedAbove = varargin{i + 1};
            case 'SampleFolder'
                SampleFolder = varargin{i + 1};
                if isa(SampleFolder, 'char')
                    SampleFolder = {SampleFolder};
                end
            case 'SampleSolvent'
                SampleSolvent = varargin{i + 1};
                if isa(SampleSolvent, 'char')
                    SampleSolvent = {SampleSolvent};
                end
            case 'ReferenceFolder'
                ReferenceFolder = varargin{i + 1};
                if isa(ReferenceFolder, 'char')
                    ReferenceFolder = {ReferenceFolder};
                end
            otherwise
                error('Unknown Argument Passed: %s', varargin{i})
        end
    end
    % If any arguments are not defined by now, propt user
    if isempty(SampleFolder)
        SampleFolder = uigetdir(pwd(), 'Please Choose Sample Folder');
%         SampleFolder = cell(0);
%         Folder = uigetdir(pwd(), 'Please Choose First Sample Folder');
%         while isa(Folder, 'char')
%             SampleFolder = vertcat(SampleFolder, Folder);
%             Folder = uigetdir(pwd(), 'Please Choose Next Sample Folder');
%         end
    end
    assert(~isempty(SampleFolder) && ~isempty(SampleFolder{1}), 'No Sample Selected!')
    if isempty(ReferenceFolder)
        ReferenceFolder = uigetdir(pwd(), 'Please Choose Reference Folder');
    end
    assert(~isempty(ReferenceFolder) && ~isempty(ReferenceFolder{1}), 'No Reference Selected!')
    if isempty(SampleSolvent)
        SampleSolvent = input('Please Specify Solvent(s) (separate multiple solvents by space): ', 's');
        if contains(SampleSolvent, ' ')
            disp('here')
            SampleSolvent = strsplit(SampleSolvent, ' ');
        elseif isa(SampleSolvent, 'char')
            SampleSolvent = {SampleSolvent};
        end
    end
    assert(~isempty(SampleSolvent) && ~isempty(SampleSolvent{1}), 'No Solvent Specified!')
    % Determine suitable reference
    Files = dir(fullfile(ReferenceFolder{1}, 'data', '*_em_*'));
    [~, FileNames, ~] = cellfun(@(x) fileparts(x), {Files.name}, 'UniformOutput', false);
    [~, ~, ~, ReferenceSolvent, ~, ReferenceCompound] = cellfun(@(x) readInformationFromFileName(x), FileNames, 'UniformOutput', false);
    IsInReferenceTable = cellfun(@(c, s) isInQuantumYieldTable(c, s), ReferenceCompound, ReferenceSolvent);
    if 1 < sum(IsInReferenceTable)
        Idx = find(IsInReferenceTable, 1);
        warning('Multiple Possible References Found. Using %s!', [ReferenceCompound{Idx}, ' in ', ReferenceSolvent{Idx}])
    else
        Idx = find(IsInReferenceTable);
    end
    Reference = fullfile(Files(Idx).folder, Files(Idx).name);
    % Import reference data
    Reference = readEm(Reference);
    % Determine suitable samples
    Files = cellfun(@(s) fullfile(SampleFolder, 'data', strcat('*_em_', s, '_*')), SampleSolvent);
    Files = cellfun(@(f) dir(f), Files, 'UniformOutput', false);
    for i = 1:length(Files)
        if 1 < length(Files{i})
            % If more of the same measurement, keep the most recent
            [~, FileNames, ~] = cellfun(@(x) fileparts(x), {Files{i}.name}, 'UniformOutput', false);
            [Date, ~, ~, ~, ~, ~] = cellfun(@(x) readInformationFromFileName(x), FileNames, 'UniformOutput', false);
            NewestDate = num2str(max(cellfun(@(x) str2num(x), Date)));
            Idx = cellfun(@(x) strcmp(NewestDate, x), Date);
            Files{i} = Files{i}(Idx);
        end
    end
    Sample = cellfun(@(x) fullfile(x.folder, x.name), Files, 'UniformOutput', false);
    % Import samples
    Sample = cellfun(@(f) readEm(f), Sample, 'UniformOutput', false);
    % Fetch emission intensities with common wavelengths
    WavelengthLow = max([min(Reference.Data.Wavelength), cellfun(@(x) min(x.Data.Wavelength), Sample)]);
    WavelengthHigh = min([max(Reference.Data.Wavelength), cellfun(@(x) max(x.Data.Wavelength), Sample)]);
    Step = max([diff(Reference.Data.Wavelength(1:2)), cellfun(@(x) diff(x.Data.Wavelength(1:2)), Sample)]);
    Wavelength = [WavelengthLow : Step : WavelengthHigh];
    Wavelength = Wavelength(PeakExpectedAbove <= Wavelength);
    ReferenceEmission = Reference.Data.Intensity(any(Reference.Data.Wavelength == Wavelength, 2));
    SampleEmission = cellfun(@(x) x.Data.Intensity(any(x.Data.Wavelength == Wavelength, 2)), Sample, 'UniformOutput', false);
    Emission = table(Wavelength', ReferenceEmission, SampleEmission{:}, 'VariableNames', [{'Wavelength'}, {'Reference'}, cellfun(@(x) x.Solvent, Sample, 'UniformOutput', false)]);
    % calculate normalized emission intensities
    NormalizedEmission = Emission;
    NormalizedEmission{:, 2:end} = NormalizedEmission{:, 2:end} ./ max(Emission{:, 2:end}, [], 1);
    % Determine wavelength with largest overlap between normalized spectra
    NormalizedEmission.Summed = sum(NormalizedEmission{:, 2:end}, 2);
    [~, Idx] = max(NormalizedEmission.Summed);
    OptimalWavelength = NormalizedEmission.Wavelength(Idx);
    % Calculate concentration-normalized emission
    Factor = [10^0, 10^-3, 10^-6, 10^-9];
    Unit = {'M', 'mM', 'uM', 'nM'};
    Concentration = [Reference.Concentration.Value * Factor(strcmp(Unit, Reference.Concentration.Unit)), cellfun(@(x) x.Concentration.Value * Factor(strcmp(Unit, x.Concentration.Unit)), Sample)];
    ConcentrationNormalizedEmission = Emission;
    ConcentrationNormalizedEmission{:, 2:end} = ConcentrationNormalizedEmission{:, 2:end} ./ Concentration;
    % Determine optimal spectral interval
    PeakWavelength = [Reference.SpectralRange.Peak, cellfun(@(x) x.SpectralRange.Peak, Sample)];
    OptimalSpectralRangeHigh = max(PeakWavelength) + SpectralPeakPadding;
    OptimalSpectralRangeLow = min(PeakWavelength) - SpectralPeakPadding;
    % Plot concentration-normalized spectra with optimal overlap
    Fig = figure;
    hold on
    xlabel('wavelength (nm)', 'Interpreter', 'latex');
    ylabel('normalized intensity (M$^{-1}$)', 'Interpreter', 'latex');
    YLim = max(max(ConcentrationNormalizedEmission{:, 2:end}));
    ylim([0, YLim]);
    plot(ConcentrationNormalizedEmission.Wavelength, ConcentrationNormalizedEmission.Reference, 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', Reference.Compound, Reference.Solvent))
    for i = 1:length(Sample)
        plot(ConcentrationNormalizedEmission.Wavelength, ConcentrationNormalizedEmission{:, i+2}, 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', Sample{i}.Compound, Sample{i}.Solvent))
    end
    plot([OptimalSpectralRangeLow, OptimalSpectralRangeLow], get(gca, 'ylim'), '--k', 'DisplayName', sprintf('Optimal Overlap: %0.0f nm to %0.0f nm', OptimalSpectralRangeLow, OptimalSpectralRangeHigh))
    plot([OptimalSpectralRangeHigh, OptimalSpectralRangeHigh], get(gca, 'ylim'), '--k', 'HandleVisibility', 'off')
    legend({}, 'Location', 'NorthEast', 'Interpreter', 'latex');
    hold off
    % Generate report
    Report = sprintf('optimal emission interval: %0.0f nm to %0.0f nm\n', OptimalSpectralRangeLow, OptimalSpectralRangeHigh);
%     % Calculate normalized emission intensity
%     Emission.NormalizedIntensity.Sample = cellfun(@(x) [x.Data.EmissionWavelength, x.Data.Intensity / max(x.Data.Intensity(x.Data.EmissionWavelength >= x.PeakExpectedAbove))], Emission.Sample, 'UniformOutput', false);
%     Emission.NormalizedIntensity.Reference = [Emission.Reference{1}.Data.EmissionWavelength, Emission.Reference{1}.Data.Intensity / max(Emission.Reference{1}.Data.Intensity(Emission.Reference{1}.Data.Intensity >= Emission.Reference{1}.PeakExpectedAbove))];
%     % Calculate concentration-normalized emission intensity
%     Factor = [10^0, 10^-3, 10^-6, 10^-9];
%     Unit = {'M', 'mM', 'uM', 'nM'};
%     Emission.ConcentrationNormalizedIntensity.Sample = cellfun(@(x) [x.Data.EmissionWavelength, x.Data.Intensity / ( x.Concentration.Value * Factor(strcmp(Unit, x.Concentration.Unit)) ) ], Emission.Sample, 'UniformOutput', false);
%     Emission.ConcentrationNormalizedIntensity.Reference = [Emission.Reference{1}.Data.EmissionWavelength, Emission.Reference{1}.Data.Intensity / ( Emission.Reference{1}.Concentration.Value * Factor(strcmp(Unit, Emission.Reference{1}.Concentration.Unit)) )];
%     % Discard wavelengths that do not overlap
%     OverlappingWavelength.Min = max([min(Emission.Reference{1}.Data.EmissionWavelength); cellfun(@(x) min(x.Data.EmissionWavelength), Emission.Sample)]);
%     OverlappingWavelength.Max = min([max(Emission.Reference{1}.Data.EmissionWavelength); cellfun(@(x) max(x.Data.EmissionWavelength), Emission.Sample)]);
%     UsefulSampleIndex = cellfun(@(x) and(OverlappingWavelength.Min <= x(:, 1), x(:, 1) <= OverlappingWavelength.Max), Emission.ConcentrationNormalizedIntensity.Sample, 'UniformOutput', false);
%     Emission.ConcentrationNormalizedIntensity.Sample = cellfun(@(x, y) x(y, :), Emission.ConcentrationNormalizedIntensity.Sample, UsefulSampleIndex, 'UniformOutput', false);
%     UsefulReferenceIndex = and(OverlappingWavelength.Min <= Emission.ConcentrationNormalizedIntensity.Reference(:, 1), Emission.ConcentrationNormalizedIntensity.Reference(:, 1) <= OverlappingWavelength.Max);
%     Emission.ConcentrationNormalizedIntensity.Reference = Emission.ConcentrationNormalizedIntensity.Reference(UsefulReferenceIndex, :);
%     % Determine wavelength with largest emission overlap
%     Wavelength = Emission.ConcentrationNormalizedIntensity.Reference(:, 1);
%     % Max of sum of normalized intensity will yield the best overlap if all
%     % intensities were equally bright
%     Intensity = cellfun(@(x, y) x.Data.NormalizedCorrectedIntensity(y), Emission.Sample, UsefulSampleIndex, 'UniformOutput', false).';
%     Intensity = sum(horzcat(Intensity{:}, Emission.Reference{1}.Data.NormalizedCorrectedIntensity(UsefulReferenceIndex)), 2);
%     [~, Index] = max(sum(Intensity, 2));
%     OptimalWavelength = Wavelength(Index);
%     fprintf('Optimal emission overlap wavelength: %d nm\n', OptimalWavelength);
%     % Plot suggested emission measurement
%     figure;
%     hold on
%     plot(Emission.NormalizedIntensity.Reference(:, 1), Emission.NormalizedIntensity.Reference(:, 2), 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', Emission.Reference{1}.Compound, Emission.Reference{1}.Solvent));
%     title('\bf{Emission}', 'Interpreter', 'latex');
%     xlabel('wavelength [nm]', 'Interpreter', 'latex');
%     ylabel('normalized Intensity [M$^{-1}$]', 'Interpreter', 'latex');
%     cellfun(@(x, y) plot(x(:,1), x(:,2), 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', y.Compound, y.Solvent)), Emission.NormalizedIntensity.Sample, Emission.Sample);
%     plot([OptimalWavelength, OptimalWavelength], get(gca, 'ylim'), '--k', 'DisplayName', sprintf('Optimal Overlap: %d nm', OptimalWavelength));
%     legend({}, 'Location', 'NorthEast', 'Interpreter', 'latex');
%     hold off
end