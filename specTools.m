function specTools(varargin)
    % Prepare arguments
    %SampleFolder = {};
    %ReferenceFolder = '';
    SampleFolder = strcat(getenv('userprofile'), '\OneDrive - Syddansk Universitet\Samples\NR');
    ReferenceFolder = strcat(getenv('userprofile'), '\OneDrive - Syddansk Universitet\Samples\RhoB');
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
        SampleFolder = uigetdir(pwd(), 'Please Select Folder Containing Data to Analyze');
    end
    assert(ischar(SampleFolder), 'No Sample Folder Selected!');
    if isempty(ReferenceFolder)
        ReferenceFolder = uigetdir(pwd(), 'Please Select Folder Containing Reference Data');
    end
    assert(ischar(ReferenceFolder), 'No Reference Folder Selected!');
    disp(SampleFolder)
    DataFolder = fullfile(SampleFolder, 'data');
    % Get absorption measurements
    AbsFiles = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', 'abs', 'OnlyNewestUniqueSolvents', true);
    AbsData = cellfun(@(x) readAbs(x), AbsFiles, 'UniformOutput', false);
    % Get excitation measurements
    ExFiles = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', 'ex', 'OnlyNewestUniqueSolvents', true);
    ExData = cellfun(@(x) readEx(x), ExFiles, 'UniformOutput', false);
    % Get emission measurements
    EmFiles = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', 'em', 'OnlyNewestUniqueSolvents', true);
    EmData = cellfun(@(x) readEm(x), EmFiles, 'UniformOutput', false);
    % Determine solvents to plot
    UniqueSolvents = unique(vertcat(cellfun(@(x) x.Solvent, AbsData, 'UniformOutput', false), cellfun(@(x) x.Solvent, ExData, 'UniformOutput', false), cellfun(@(x) x.Solvent, EmData, 'UniformOutput', false)));
    PolarityTable = readtable(fullfile(getenv('userprofile'), 'Documents', 'MATLAB', 'SpecTools', 'ref_polarity.csv'));
    if 1 < length(UniqueSolvents)
        [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), UniqueSolvents), 'descend');
        UniqueSolvents = UniqueSolvents(PolaritySorting);
    end
    % Plot spectra for each solvent
    ColorMap = parula(length(UniqueSolvents));
    Fig = figure;
    hold on
    xlabel('wavelength (nm)', 'Interpreter', 'latex');
    ylabel('normalized signal', 'Interpreter', 'latex');
    ylim([0, 1.1])
    for i = 1:length(UniqueSolvents)
        Solvent = UniqueSolvents{i};
        Color = ColorMap(i, :);
        Idx = cellfun(@(x) strcmp(x.Solvent, Solvent), AbsData);
        plot(AbsData{Idx}.Data.Wavelength, AbsData{Idx}.Data.NormalizedAbsorption, '--', 'Color', Color, 'HandleVisibility', 'off')
        Idx = cellfun(@(x) strcmp(x.Solvent, Solvent), ExData);
        plot(ExData{Idx}.Data.Wavelength, ExData{Idx}.Data.NormalizedIntensity, '.', 'Color', Color, 'HandleVisibility', 'off')
        Idx = cellfun(@(x) strcmp(x.Solvent, Solvent), EmData);
        plot(EmData{Idx}.Data.Wavelength, EmData{Idx}.Data.NormalizedIntensity, '-', 'Color', Color, 'DisplayName', Solvent)
    end
    legend({}, 'Location', 'NorthWest', 'Interpreter', 'latex')
    hold off
    FileName = fullfile(SampleFolder, 'spectra');
    print(Fig, FileName, '-djpeg')
    % Build spectral results table
    SpectralResultsTable = cell2table(cell(length(UniqueSolvents), 8), 'VariableNames', {'Solvent', 'ExPeak', 'DeltaExPeak', 'AbsPeak', 'DeltaAbsPeak', 'EmPeak', 'DeltaEmPeak', 'StokesShift'});
    SpectralResultsTable.Solvent = UniqueSolvents;
    SpectralResultsTable{:, 2:end} = {NaN};
    %
    ExSolvents = cellfun(@(x) x.Solvent, ExData, 'UniformOutput', false);
    SpectralResultsTable.ExPeak = round(cellfun(@(x) ExData{(strcmp(ExSolvents, x))}.SpectralRange.Peak, SpectralResultsTable.Solvent));
    SpectralResultsTable.DeltaExPeak = arrayfun(@(x) x - SpectralResultsTable.ExPeak(1), SpectralResultsTable.ExPeak);
    %
    AbsSolvents = cellfun(@(x) x.Solvent, AbsData, 'UniformOutput', false);
    SpectralResultsTable.AbsPeak = round(cellfun(@(x) AbsData{(strcmp(AbsSolvents, x))}.SpectralRange.Peak, SpectralResultsTable.Solvent));
    SpectralResultsTable.DeltaAbsPeak = arrayfun(@(x) x - SpectralResultsTable.AbsPeak(1), SpectralResultsTable.AbsPeak);
    %
    EmSolvents = cellfun(@(x) x.Solvent, EmData, 'UniformOutput', false);
    SpectralResultsTable.EmPeak = round(cellfun(@(x) EmData{(strcmp(EmSolvents, x))}.SpectralRange.Peak, SpectralResultsTable.Solvent));
    SpectralResultsTable.DeltaEmPeak = arrayfun(@(x) x - SpectralResultsTable.EmPeak(1), SpectralResultsTable.EmPeak);
    %
    SpectralResultsTable.StokesShift = SpectralResultsTable.EmPeak - SpectralResultsTable.AbsPeak;
    % Save spectral results table
    FileName = fullfile(SampleFolder, 'spectral_peaks.csv');
    writetable(SpectralResultsTable, FileName)
    % Plot normalized spectral results values
    Polarity = cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), UniqueSolvents);
    ExNorm = SpectralResultsTable.ExPeak / max(SpectralResultsTable.ExPeak);
    AbsNorm = SpectralResultsTable.AbsPeak / max(SpectralResultsTable.AbsPeak);
    EmNorm = SpectralResultsTable.EmPeak / max(SpectralResultsTable.EmPeak);
    StokesNorm = SpectralResultsTable.StokesShift / max(SpectralResultsTable.StokesShift);
    Color = parula(4);
    Fig = figure;
    hold on
    xlabel('polarity relative to H$_{2}$O', 'Interpreter', 'latex');
    ylabel('relative change', 'Interpreter', 'latex');
    ylim([0, 1.1])
    plot(Polarity, ExNorm, 'o-', 'Color', Color(1, :), 'DisplayName', 'Excitation')
    plot(Polarity, AbsNorm, 'o-', 'Color', Color(2, :), 'DisplayName', 'Absorption')
    plot(Polarity, EmNorm, 'o-', 'Color', Color(3, :), 'DisplayName', 'Emission')
    plot(Polarity, StokesNorm, 'o-', 'Color', Color(4, :), 'DisplayName', 'Stokes Shift')
    legend({}, 'Location', 'East', 'Interpreter', 'latex')
    hold off
    FileName = fullfile(SampleFolder, 'spectral_results');
    print(Fig, FileName, '-djpeg')
    % Calculate lifetime results
    FLIMData = collectLifetimeData('SampleFolder', SampleFolder);
    FLIMResults = cell2table(cell(length(unique(FLIMData.Solvent)), 3), 'VariableNames', {'Solvent', 'MeanLifetime', 'SDLifetime'});
    FLIMResults.Solvent = unique(FLIMData.Solvent);
    [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), FLIMResults.Solvent), 'descend');
    FLIMResults.Solvent = FLIMResults.Solvent(PolaritySorting);
    SolventIdx = cellfun(@(x) strcmp(FLIMData.Solvent, x), FLIMResults.Solvent, 'UniformOutput', false);
    FLIM = cellfun(@(x) FLIMData.MeanT1(x), SolventIdx, 'UniformOutput', false);
    FLIMResults.MeanLifetime = cellfun(@(x) round(mean(cell2mat(x)), 4, 'significant'), FLIM, 'UniformOutput', false);
    FLIMResults.SDLifetime = cellfun(@(x) round(std(cell2mat(x)), 4, 'significant'), FLIM, 'UniformOutput', false);
    % Calculate quantum yield results
    QYData = calculateQuantumYield('SampleFolder', SampleFolder, 'ReferenceFolder', ReferenceFolder);
    QYResults = cell2table(cell(length(unique(QYData.Solvent)), 3), 'VariableNames', {'Solvent', 'MeanQY', 'SDQY'});
    QYResults.Solvent = unique(QYData.Solvent);
    [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), QYResults.Solvent), 'descend');
    QYResults.Solvent = QYResults.Solvent(PolaritySorting);
    SolventIdx = cellfun(@(x) strcmp(QYData.Solvent, x), QYResults.Solvent, 'UniformOutput', false);
    QY = cellfun(@(x) QYData.QuantumYield(x), SolventIdx, 'UniformOutput', false);
    QYResults.MeanQY = cellfun(@(x) round(mean(cell2mat(x)), 4, 'significant'), QY, 'UniformOutput', false);
    QYResults.SDQY = cellfun(@(x) round(std(cell2mat(x)), 4, 'significant'), QY, 'UniformOutput', false);
    % Calculate molar attenuation coefficient results
    MACData = calculateMolarAttenuation('SampleFolder', SampleFolder);
    MACResults = cell2table(cell(length(unique(MACData.Solvent)), 3), 'VariableNames', {'Solvent', 'MeanMAC', 'SDMAC'});
    MACResults.Solvent = unique(MACData.Solvent);
    [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), MACResults.Solvent), 'descend');
    MACResults.Solvent = MACResults.Solvent(PolaritySorting);
    SolventIdx = cellfun(@(x) strcmp(MACData.Solvent, x), MACResults.Solvent, 'UniformOutput', false);
    MAC = cellfun(@(x) MACData.MolarAttenuationCoefficient(x), SolventIdx, 'UniformOutput', false);
    MACResults.MeanMAC = cellfun(@(x) round(mean(cell2mat(x)), 4, 'significant'), MAC, 'UniformOutput', false);
    MACResults.SDMAC = cellfun(@(x) round(std(cell2mat(x)), 4, 'significant'), MAC, 'UniformOutput', false);
    % Build physical properties table
    UniqueSolvents = unique(vertcat(FLIMResults.Solvent, QYResults.Solvent, MACResults.Solvent));
    PhysicalPropertiesTable = cell2table(cell(length(UniqueSolvents), 7), 'VariableNames', {'Solvent', 'MeanLifetime', 'SDLifetime', 'MeanQuantumYield', 'SDQuantumYield', 'MeanMolarAttenuationCoefficient', 'SDMolarAttenuationCoefficient'});
    [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), UniqueSolvents), 'descend');
    PhysicalPropertiesTable.Solvent = UniqueSolvents(PolaritySorting);
    PhysicalPropertiesTable{:, 2:end} = {'NA'};
    for i = 1:height(PhysicalPropertiesTable)
        Solvent = PhysicalPropertiesTable.Solvent{i};
        if any(strcmp(FLIMResults.Solvent, Solvent))
            PhysicalPropertiesTable.MeanLifetime{i} = FLIMResults.MeanLifetime{strcmp(FLIMResults.Solvent, Solvent)};
            PhysicalPropertiesTable.SDLifetime{i} = FLIMResults.SDLifetime{strcmp(FLIMResults.Solvent, Solvent)};
        end
        if any(strcmp(QYResults.Solvent, Solvent))
            PhysicalPropertiesTable.MeanQuantumYield{i} = QYResults.MeanQY{strcmp(QYResults.Solvent, Solvent)};
            PhysicalPropertiesTable.SDQuantumYield{i} = QYResults.SDQY{strcmp(QYResults.Solvent, Solvent)};
        end
        if any(strcmp(MACResults.Solvent, Solvent))
            PhysicalPropertiesTable.MeanMolarAttenuationCoefficient{i} = MACResults.MeanMAC{strcmp(MACResults.Solvent, Solvent)};
            PhysicalPropertiesTable.SDMolarAttenuationCoefficient{i} = MACResults.SDMAC{strcmp(MACResults.Solvent, Solvent)};
        end
    end
    % Save physical properties table
    FileName = fullfile(SampleFolder, 'physical_properties.csv');
    writetable(PhysicalPropertiesTable, FileName)
    % Collect two-photon excitation results
    [TPEData, ReferenceName] = collectTwoPhotonExcitationData('SampleFolder', SampleFolder, 'ReferenceFolder', ReferenceFolder);
    % Plot two-photon excitation spectra
    Fig = figure;
    hold on
    xlabel('wavelength (nm)', 'Interpreter', 'latex')
    ylabel('$\phi_{f} \cdot \sigma_{2P}$ (GM)', 'Interpreter', 'latex')
    plot(TPEData.Wavelength, TPEData.ReferenceTPA, 'bo-', 'DisplayName', ReferenceName);
    Solvent = regexp(TPEData.Properties.VariableNames(3:2:end), '(?<=^Mean).+$', 'match');
    Solvent = horzcat(Solvent{:});
    MeanAP = TPEData{:, 3:2:end};
    SDAP = TPEData{:, 4:2:end};
    for i = 1:length(Solvent)
        errorbar(TPEData.Wavelength, MeanAP(:, i), SDAP(:, i), 'DisplayName', Solvent{i});
    end
    legend({}, 'Interpreter', 'latex')
    FileName = fullfile(SampleFolder, '2PEx');
    print(Fig, FileName, '-djpeg')
    % Generate latex report
    generateLatexReport('SampleFolder', SampleFolder);
end