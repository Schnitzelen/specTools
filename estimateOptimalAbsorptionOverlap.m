function [Report, Fig] = estimateOptimalAbsorptionOverlap(varargin)
    % Default arguments
    TargetAbsorptionMax = 0.1; % optical density
    SpectralPeakPadding = 10; % nm
    PeakExpectedAbove = 350; % nm
    SampleFolder = {};
    SampleSolvent = {};
    ReferenceFolder = {};
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'TargetAbsorptionMax'
                TargetAbsorptionMax = varargin{i + 1};
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
        if isa(SampleFolder, 'char')
            SampleFolder = {SampleFolder};
        end
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
        if isa(ReferenceFolder, 'char')
            ReferenceFolder = {ReferenceFolder};
        end
    end
    assert(~isempty(ReferenceFolder) && ~isempty(ReferenceFolder{1}), 'No Reference Selected!')
    if isempty(SampleSolvent)
        SampleSolvent = input('Please Specify Solvent(s) (separate multiple solvents by space): ', 's');
        if contains(SampleSolvent, ' ')
            SampleSolvent = strsplit(SampleSolvent, ' ');
        elseif isa(SampleSolvent, 'char')
            SampleSolvent = {SampleSolvent};
        end
    end
    assert(~isempty(SampleSolvent) && ~isempty(SampleSolvent{1}), 'No Solvent Specified!')
    % Determine suitable reference
    Files = dir(fullfile(ReferenceFolder{1}, 'data', '*_abs_*'));
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
    Reference = readAbs(Reference);
    % Determine suitable samples
    Files = cellfun(@(s) fullfile(SampleFolder, 'data', strcat('*_abs_', s, '_*')), SampleSolvent);
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
    Sample = cellfun(@(f) readAbs(f), Sample, 'UniformOutput', false);
    % Fetch absorptions with common wavelengths
    WavelengthLow = max([min(Reference.Data.Wavelength), cellfun(@(x) min(x.Data.Wavelength), Sample)]);
    WavelengthHigh = min([max(Reference.Data.Wavelength), cellfun(@(x) max(x.Data.Wavelength), Sample)]);
    Step = max([diff(Reference.Data.Wavelength(1:2)), cellfun(@(x) diff(x.Data.Wavelength(1:2)), Sample)]);
    Wavelength = [WavelengthLow : Step : WavelengthHigh];
    Wavelength = Wavelength(PeakExpectedAbove <= Wavelength);
    ReferenceAbsorption = Reference.Data.Absorption(any(Reference.Data.Wavelength == Wavelength, 2));
    SampleAbsorption = cellfun(@(x) x.Data.Absorption(any(x.Data.Wavelength == Wavelength, 2)), Sample, 'UniformOutput', false);
    Absorption = table(Wavelength', ReferenceAbsorption, SampleAbsorption{:}, 'VariableNames', [{'Wavelength'}, {'Reference'}, cellfun(@(x) x.Solvent, Sample, 'UniformOutput', false)]);
    % calculate normalized absorptions
    NormalizedAbsorption = Absorption;
    NormalizedAbsorption{:, 2:end} = NormalizedAbsorption{:, 2:end} ./ max(Absorption{:, 2:end}, [], 1);
    % Determine wavelength with largest overlap between normalized spectra
    NormalizedAbsorption.Summed = sum(NormalizedAbsorption{:, 2:end}, 2);
    [~, Idx] = max(NormalizedAbsorption.Summed);
    OptimalWavelength = NormalizedAbsorption.Wavelength(Idx);
    % Calculate concentration-normalized absorption
    Factor = [10^0, 10^-3, 10^-6, 10^-9];
    Unit = {'M', 'mM', 'uM', 'nM'};
    Concentration = [Reference.Concentration.Value * Factor(strcmp(Unit, Reference.Concentration.Unit)), cellfun(@(x) x.Concentration.Value * Factor(strcmp(Unit, x.Concentration.Unit)), Sample)];
    ConcentrationNormalizedAbsorption = Absorption;
    ConcentrationNormalizedAbsorption{:, 2:end} = ConcentrationNormalizedAbsorption{:, 2:end} ./ Concentration;
    % Determine optimal concentrations
    OptimalConcentration = cell2table(num2cell(NaN(6, 2+length(Sample))), 'VariableNames', [{'Absorption'}, {'Reference'}, cellfun(@(x) x.Solvent, Sample, 'UniformOutput', false)]);
    OptimalConcentration.Absorption = [0 : (TargetAbsorptionMax/5) : TargetAbsorptionMax]';
    Idx = ConcentrationNormalizedAbsorption.Wavelength == OptimalWavelength;
    OptimalConcentration{end, 2:end} = TargetAbsorptionMax ./ ConcentrationNormalizedAbsorption{Idx, 2:end};
    OptimalConcentration{1:end-1, 2:end} = OptimalConcentration{1:end-1, 1} / OptimalConcentration{end, 1} * OptimalConcentration{end, 2:end};
    % Determine optimal spectral interval
    PeakWavelength = [Reference.SpectralRange.Peak, cellfun(@(x) x.SpectralRange.Peak, Sample)];
    OptimalSpectralRangeHigh = max(PeakWavelength) + SpectralPeakPadding;
    OptimalSpectralRangeLow = min(PeakWavelength) - SpectralPeakPadding;
    % Plot concentration-normalized spectra with optimal overlap
    Fig = figure;
    hold on
    xlabel('wavelength (nm)', 'Interpreter', 'latex');
    ylabel('normalized absorption (M$^{-1}$)', 'Interpreter', 'latex');
    YLim = max(max(ConcentrationNormalizedAbsorption{:, 2:end}));
    ylim([0, YLim]);
    plot(ConcentrationNormalizedAbsorption.Wavelength, ConcentrationNormalizedAbsorption.Reference, 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', Reference.Compound, Reference.Solvent))
    for i = 1:length(Sample)
        plot(ConcentrationNormalizedAbsorption.Wavelength, ConcentrationNormalizedAbsorption{:, i+2}, 'LineWidth', 2, 'DisplayName', sprintf('%s in %s', Sample{i}.Compound, Sample{i}.Solvent))
    end
    plot([OptimalSpectralRangeLow, OptimalSpectralRangeLow], get(gca, 'ylim'), '--k', 'DisplayName', sprintf('optimal overlap: %0.0f nm to %0.0f nm', OptimalSpectralRangeHigh, OptimalSpectralRangeLow))
    plot([OptimalSpectralRangeHigh, OptimalSpectralRangeHigh], get(gca, 'ylim'), '--k', 'HandleVisibility', 'off')
    plot([OptimalWavelength, OptimalWavelength], get(gca, 'ylim'), '-k', 'DisplayName', sprintf('optimal excitation: %d nm', OptimalWavelength));
    legend({}, 'Location', 'NorthWest', 'Interpreter', 'latex');
    hold off
    % Generate report
    Report = sprintf('reference: %s in %s\n', Reference.Compound, Reference.Solvent);
    Report = horzcat(Report, sprintf('optimal absorption interval: %0.0f nm to %0.0f nm\n', round(OptimalSpectralRangeHigh), round(OptimalSpectralRangeLow)));
    Report = horzcat(Report, sprintf('suggested concentrations (M) for %s in %s:\n', Reference.Compound, Reference.Solvent));
    Report = horzcat(Report, sprintf('%0.3e\t%0.3e\t%0.3e\t%0.3e\t%0.3e\t%0.3e\n', OptimalConcentration.Reference'));
    for i = 1:length(Sample)
        Report = horzcat(Report, sprintf('suggested concentrations (M) for %s in %s:\n', Sample{i}.Compound, Sample{i}.Solvent));
        Report = horzcat(Report, sprintf('%0.3e\t%0.3e\t%0.3e\t%0.3e\t%0.3e\t%0.3e\n', OptimalConcentration{:, i + 2}'));
    end
    Report = horzcat(Report, sprintf('optimal excitation wavelength: %0.0f nm\n', OptimalWavelength));
end