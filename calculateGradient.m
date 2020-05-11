function Gradient = calculateGradient(AbsorptionData, EmissionData)
    % Sort data according to concentration
    Concentration = cellfun(@(x) x.Concentration.Value, EmissionData);
    [~, Idx] = sort(Concentration);
    EmissionData = EmissionData(Idx);
    Concentration = cellfun(@(x) x.Concentration.Value, AbsorptionData);
    [~, Idx] = sort(Concentration);
    AbsorptionData = AbsorptionData(Idx);
    % Import full emission spectrum
    Solvent = EmissionData{1}.Solvent;
    Compound = EmissionData{1}.Compound;
    ExperimentFolder = fileparts(EmissionData{1}.AbsoluteFileName);
    Files = dir(fullfile(ExperimentFolder, ['*_em_', Solvent, '_*_', Compound, '.*']));
    % Keep only most recent measurement
    Dates = arrayfun(@(x) x.name, Files, 'UniformOutput', false);
    Dates = regexp(Dates, '_', 'split');
    Dates = cellfun(@(x) str2num(x{1}), Dates);
    [~, Idx] = max(Dates);
    Files = Files(Idx);
    FullEmission = readEm(fullfile(Files.folder, Files.name));
    % Calculate corrected emission intensities
    WavelengthLow = cellfun(@(x) min(x.Data.Wavelength), EmissionData);
    WavelengthHigh = cellfun(@(x) max(x.Data.Wavelength), EmissionData);
    CorrectionFactor = arrayfun(@(l, h) FullEmission.calculatePartialEmissionCorrectionFactor(l, h), WavelengthLow, WavelengthHigh);
    EmissionIntensity = cellfun(@(x) x.IntegratedIntensity, EmissionData);
    CorrectedIntensity = EmissionIntensity .* CorrectionFactor;
    % Fetch absorption at excitation wavelength
    ExcitationWavelength = cellfun(@(x) x.Info.ExcitationWavelength, EmissionData, 'UniformOutput', false);
    ExcitationWavelength = regexp(ExcitationWavelength, 'fixed:', 'split');
    ExcitationWavelength = cellfun(@(x) str2double(x{2}), ExcitationWavelength);
    [~, AbsorptionWavelengthIdx] = cellfun(@(a, e) min(abs(a.Data.Wavelength - e)), AbsorptionData, num2cell(ExcitationWavelength));
    Absorption = cellfun(@(a, i) a.Data.Absorption(i), AbsorptionData, num2cell(AbsorptionWavelengthIdx));
    % Fit data
    Fit = fit(Absorption, CorrectedIntensity, fittype({'x'}));
    Gradient = Fit.a;
    %plot(Fit, Absorption, CorrectedIntensity)
end