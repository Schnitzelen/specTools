% By Brian Bjarke Jensen 4/1-2019

classdef calcQY < handle
    % Class used for containing and calculating quantum yield data
    properties
        TableValuePath
        AbsoluteFileList
        RefractiveIndexTable
        QuantumYieldTable
        Date
        Solvent
        Compound
        Data
        OneP
        Raw
        Fit
        Results
    end
    methods
        % Jeg bør tilføje noget der selv vurderer antallet af betydende
        % cifre i resultatet baseret på data!!!
        function obj = calcQY(AbsoluteFileList)
            obj.TableValuePath = fullfile(getenv('userprofile'), '/Documents/Matlab/SpecTools/');
            % Ask for folder path, if none is provided
            if ~exist('AbsoluteFileList', 'var')
                AbsoluteFileList = uigetdir(getenv('userprofile'), 'Please Select Quantum Yield Data to Import', 'MultiSelect', 'on');
            end
            obj.AbsoluteFileList = AbsoluteFileList;
            obj.importSampleData()
            obj.importReferenceData()
            obj.buildRawDataTable()
            obj.correctIntegratedEmission()
            obj.buildResultsTable()
        end
        function importSampleData(obj)
            % Make sure that file list is proper
            assert(length(obj.AbsoluteFileList) > 2);
            [~, FileNames, ~] = cellfun(@(x) fileparts(x), obj.AbsoluteFileList, 'UniformOutput', false);
            Info = regexp(FileNames, '_', 'split');
            Info = vertcat(Info{:});
            obj.Date = unique(Info(: ,1));
            obj.Solvent = unique(Info(:, 3));
            assert(length(obj.Solvent) == 1, 'Multiple Solvents Selected!');
            obj.Solvent = vertcat(obj.Solvent{:});
            obj.Compound = unique(Info(:, 5));
            assert(length(obj.Compound) == 1, 'Multiple Compounds Selected!');
            obj.Compound = vertcat(obj.Compound{:});
            % Import sample data and full spectra
            obj.Data.Sample = obj.importData(obj.AbsoluteFileList);
            obj.OneP.Sample = obj.importFullSpectra(obj.AbsoluteFileList);
        end
        function importReferenceData(obj)
            % Load list of quantum yield references
            obj.QuantumYieldTable = readtable(fullfile(obj.TableValuePath, 'ref_quantum_yield.csv'));
            % Locate all quantum yield data
            ReferencePath = fileparts(fileparts(fileparts(obj.AbsoluteFileList{1})));
            QuantumYieldFiles = dir(fullfile(ReferencePath, '**', '*_qy_*'));
            Info = regexp({QuantumYieldFiles.name}.', '_', 'split');
            Info = vertcat(Info{:});
            Dates = Info(:, 1);
            Solvents = Info(:, 3);
            Compounds = Info(:, 5);
            Compounds = regexp(Compounds, '\.', 'split');
            Compounds = vertcat(Compounds{:});
            Compounds = Compounds(:, 1);
            % Determine useful references based on filenames
            IsInReferenceTable = cellfun(@(x, y) any(and(strcmp(obj.QuantumYieldTable.Abbreviation, x), strcmp(obj.QuantumYieldTable.Solvent, y))), Compounds, Solvents);
            IsSameDate = cellfun(@(x) any(strcmp(x, obj.Date)), Dates);
            IsAlreadyASample = arrayfun(@(x) any(strcmp(fullfile(x.folder, x.name), obj.AbsoluteFileList)), QuantumYieldFiles);
            UsefulReferences = IsInReferenceTable & IsSameDate & ~IsAlreadyASample;
            FileList = arrayfun(@(x, y) fullfile(x.folder, x.name), QuantumYieldFiles(UsefulReferences), 'UniformOutput', false);
            % In the weird case of multiple useful sample compounds:
            if length(unique(Compounds(UsefulReferences))) > 1
                % Choose reference that is highest on the QYtable list
                Idx = min(cellfun(@(x) min(find(strcmp(obj.QuantumYieldTable.Abbreviation, x))), unique(Compounds(UsefulReferences))));
                ReferenceCompoundToUse = obj.QuantumYieldTable.Abbreviation(Idx);
                Idx = contains(FileList, ReferenceCompoundToUse);
                FileList = FileList(Idx);
            end
            % Import reference data and full spectra
            obj.Data.Reference = obj.importData(FileList);
            obj.OneP.Reference = obj.importFullSpectra(FileList);
        end
        function buildRawDataTable(obj)
            % Sample
            SampleSolvent = cellfun(@(x) x.Solvent, obj.Data.Sample.Emission, 'UniformOutput', false);
            SampleEmissionIntensity = cellfun(@(x) x.Integrated.Emission.Value, obj.Data.Sample.Emission);
            Wavelength = cellfun(@(x) x.Integrated.Emission.ExcitationWavelength, obj.Data.Sample.Emission);
            SampleAbsorption = cellfun(@(x, y) x.Data.Absorption(x.Data.Wavelength == y), obj.Data.Sample.Absorption, num2cell(Wavelength));
            % Reference
            ReferenceCompound = cellfun(@(x) x.Compound, obj.Data.Reference.Emission, 'UniformOutput', false);
            ReferenceSolvent = cellfun(@(x) x.Solvent, obj.Data.Reference.Emission, 'UniformOutput', false);
            ReferenceEmissionIntensity = cellfun(@(x) x.Integrated.Emission.Value, obj.Data.Reference.Emission);
            ReferenceAbsorption = cellfun(@(x, y) x.Data.Absorption(x.Data.Wavelength == y), obj.Data.Sample.Absorption, num2cell(Wavelength));
            % Determine refractive indices
            obj.RefractiveIndexTable = readtable(fullfile(obj.TableValuePath, 'ref_refractive_index.csv'));
            SampleRefractiveIndex = cellfun(@(x) obj.RefractiveIndexTable.RefractiveIndex(strcmp(obj.RefractiveIndexTable.Abbreviation, x)), SampleSolvent);
            ReferenceRefractiveIndex = cellfun(@(x) obj.RefractiveIndexTable.RefractiveIndex(strcmp(obj.RefractiveIndexTable.Abbreviation, x)), ReferenceSolvent);
            % Determine reference quantum yield
            IsSameCompound = cellfun(@(x) strcmp(obj.QuantumYieldTable.Abbreviation, x), ReferenceCompound, 'UniformOutput', false);
            IsSameSolvent = cellfun(@(x) strcmp(obj.QuantumYieldTable.Solvent, x), ReferenceSolvent, 'UniformOutput', false);
            Idx = cellfun(@(x, y) and(x, y), IsSameCompound, IsSameSolvent, 'UniformOutput', false);
            ReferenceQuantumYield = cellfun(@(x) obj.QuantumYieldTable.QuantumYield(x), Idx);
            % Create raw table
            obj.Raw = table(Wavelength, SampleSolvent, SampleRefractiveIndex, SampleAbsorption, SampleEmissionIntensity, ReferenceCompound, ReferenceSolvent, ReferenceRefractiveIndex, ReferenceQuantumYield, ReferenceAbsorption, ReferenceEmissionIntensity);
        end
        function correctIntegratedEmission(obj)
            MeasuredWavelengthLow = obj.Data.Sample.Emission{1}.Info.EmissionWavelength.from;
            MeasuredWavelengthHigh = obj.Data.Sample.Emission{1}.Info.EmissionWavelength.to;
            % Sample
            PartialEmissionCorrectionFactor = obj.OneP.Sample.Emission.calculatePartialEmissionCorrectionFactor(MeasuredWavelengthLow, MeasuredWavelengthHigh);
            obj.Raw.SampleCorrectedEmissionIntensity = obj.Raw.SampleEmissionIntensity * PartialEmissionCorrectionFactor;
            % Reference
            PartialEmissionCorrectionFactor = obj.OneP.Reference.Emission.calculatePartialEmissionCorrectionFactor(MeasuredWavelengthLow, MeasuredWavelengthHigh);
            obj.Raw.ReferenceCorrectedEmissionIntensity = obj.Raw.ReferenceEmissionIntensity * PartialEmissionCorrectionFactor;
        end
        function buildResultsTable(obj)
            % Reference
            ReferenceCompound = obj.Raw.ReferenceCompound{1};
            ReferenceSolvent = obj.Raw.ReferenceSolvent{1};
            ReferenceRefractiveIndex = obj.Raw.ReferenceRefractiveIndex(1);
            ReferenceQuantumYield = obj.Raw.ReferenceQuantumYield(1);
            % Solvent
            SampleSolvent = obj.Raw.SampleSolvent{1};
            SampleRefractiveIndex = obj.Raw.SampleRefractiveIndex(1);
            % Calculate gradients
%             FT = fittype('a * x + b', 'dependent', {'y'}, 'independent', {'x'}, 'coefficients', {'a', 'b'});
%             obj.Fit.Reference = fit(obj.Raw.ReferenceAbsorption, obj.Raw.ReferenceCorrectedEmissionIntensity, FT, 'StartPoint', [1, 1]);
            obj.Fit.Reference = polyfit(obj.Raw.ReferenceAbsorption, obj.Raw.ReferenceCorrectedEmissionIntensity, 1);
            ReferenceGradient = round(obj.Fit.Reference(1), 4, 'significant');
            %obj.Fit.Sample = fit(obj.Raw.SampleAbsorption, obj.Raw.SampleCorrectedEmissionIntensity, FT, 'StartPoint', [10^8, 10^5]);
            obj.Fit.Sample = polyfit(obj.Raw.SampleAbsorption, obj.Raw.SampleCorrectedEmissionIntensity, 1);
            SampleGradient = round(obj.Fit.Sample(1), 4, 'significant');
            % Calculate quantum yield
            SampleQuantumYield = ReferenceQuantumYield * ( SampleGradient / ReferenceGradient ) * ( SampleRefractiveIndex^2 / ReferenceRefractiveIndex^2 );
            SampleQuantumYield = round(SampleQuantumYield, 4, 'significant');
            % Create results table
            obj.Results = table(ReferenceCompound, ReferenceSolvent, ReferenceRefractiveIndex, ReferenceGradient, ReferenceQuantumYield, SampleSolvent, SampleRefractiveIndex, SampleGradient, SampleQuantumYield);
        end
        function Fig = plotRaw(obj)
            Fig = figure;
            hold on
            % Reference
            scatter(obj.Raw.ReferenceAbsorption, obj.Raw.ReferenceCorrectedEmissionIntensity, 'r', 'HandleVisibility', 'off');
            X = [0; obj.Raw.ReferenceAbsorption];
            Y = obj.Fit.Reference(1) * X + obj.Fit.Reference(2);
            plot(X, Y, 'r', 'DisplayName', obj.Results.ReferenceCompound);
            % Sample
            scatter(obj.Raw.SampleAbsorption, obj.Raw.SampleCorrectedEmissionIntensity, 'b', 'HandleVisibility', 'off');
            X = [0; obj.Raw.SampleAbsorption];
            Y = obj.Fit.Sample(1) * X + obj.Fit.Sample(2);
            plot(X, Y, 'b', 'DisplayName', obj.Compound);
            XMax = max([obj.Raw.SampleAbsorption; obj.Raw.ReferenceAbsorption]);
            xlim([0, XMax]);
            YMax = max([obj.Raw.SampleCorrectedEmissionIntensity; obj.Raw.ReferenceCorrectedEmissionIntensity]);
            ylim([0, YMax]);
            legend({}, 'Interpreter', 'latex');
            title(sprintf('%s{Quantum Yield Gradient Plot of %s in %s}', '\textbf', obj.Compound, obj.Solvent), 'Interpreter', 'latex');
            xlabel('absorption (a.u.)', 'Interpreter', 'latex');
            ylabel('emission (a.u.)', 'Interpreter', 'latex');
            hold off
        end
        function Fig = plotSpectralOverlap(obj)
            Fig = figure;
            hold on
            title('\textbf{Quantum Yield Spectral Overlap}', 'Interpreter', 'latex');
            % Setting up x-axis
            XMin = min([min(obj.OneP.Sample.Absorption.Data.Wavelength), min(obj.OneP.Reference.Absorption.Data.Wavelength)]);
            XMax = max([max(obj.OneP.Sample.Emission.Data.EmissionWavelength), max(obj.OneP.Reference.Emission.Data.EmissionWavelength)]);
            xlim([XMin, XMax]);
            xlabel('wavelength (nm)', 'Interpreter', 'latex');
            % Plotting left (absorption) y-axis
            LeftYMax = max([max(obj.OneP.Sample.Absorption.Data.Absorption(obj.OneP.Sample.Absorption.Data.Wavelength > obj.OneP.Sample.Absorption.PeakExpectedAbove)), max(obj.OneP.Reference.Absorption.Data.Absorption(obj.OneP.Reference.Absorption.Data.Wavelength > obj.OneP.Reference.Absorption.PeakExpectedAbove))]);
            yyaxis left
            ylim([0, LeftYMax]);
            ylabel('absorption (a.u.)', 'Interpreter', 'latex');
            LegendName = sprintf('%s in %s', obj.OneP.Sample.Absorption.Compound, obj.OneP.Sample.Absorption.Solvent);
            plot(obj.OneP.Sample.Absorption.Data.Wavelength, obj.OneP.Sample.Absorption.Data.Absorption, 'DisplayName', LegendName);
            LegendName = sprintf('%s in %s', obj.OneP.Reference.Absorption.Compound, obj.OneP.Reference.Absorption.Solvent);
            plot(obj.OneP.Reference.Absorption.Data.Wavelength, obj.OneP.Reference.Absorption.Data.Absorption, 'DisplayName', LegendName);
            plot([obj.Data.Sample.Emission{1}.Info.ExcitationWavelength.fixed, obj.Data.Sample.Emission{1}.Info.ExcitationWavelength.fixed], [0, LeftYMax], 'LineWidth', 2, 'DisplayName', 'Excitation');
            legend({}, 'Location', 'northwest', 'Interpreter', 'latex');
            % Setting up right (emission) y-axis
            RightYMax = max([max(obj.OneP.Sample.Emission.Data.Intensity(obj.OneP.Sample.Emission.Data.EmissionWavelength > obj.OneP.Sample.Emission.PeakExpectedAbove)), max(obj.OneP.Reference.Emission.Data.Intensity(obj.OneP.Reference.Emission.Data.EmissionWavelength > obj.OneP.Reference.Emission.PeakExpectedAbove))]);
            yyaxis right
            ylim([0, RightYMax]);
            ylabel('intensity (a.u.)', 'Interpreter', 'latex');
            plot(obj.OneP.Sample.Emission.Data.EmissionWavelength, obj.OneP.Sample.Emission.Data.Intensity, 'HandleVisibility', 'off');
            plot(obj.OneP.Reference.Emission.Data.EmissionWavelength, obj.OneP.Reference.Emission.Data.Intensity, 'HandleVisibility', 'off');
            plot([min(obj.Data.Sample.Emission{1}.Data.EmissionWavelength), min(obj.Data.Sample.Emission{1}.Data.EmissionWavelength)], [0, RightYMax], 'LineWidth', 2, 'DisplayName', 'Measured Emission');
            plot([max(obj.Data.Sample.Emission{1}.Data.EmissionWavelength), max(obj.Data.Sample.Emission{1}.Data.EmissionWavelength)], [0, RightYMax], 'LineWidth', 2, 'HandleVisibility', 'off');
        end
    end
    methods(Static)
        function S = importData(FileList)
            AbsFileList = FileList(contains(FileList, '.TXT'));
            EmFileList = FileList(contains(FileList, '.ifx'));
            % Import sample absorption-data
            S.Absorption = cellfun(@(x) readAbs(x), AbsFileList, 'UniformOutput', false);
            % Import sample emission-data
            S.Emission = cellfun(@(x) readIfx(x), EmFileList, 'UniformOutput', false);
        end
        function S = importFullSpectra(FileList)
            % Define where to look for full spectra
            [Path, File, ~] = fileparts(FileList{1});
            % Determine solvent and compound
            Info = strsplit(File, '_');
            Solvent = Info{3};
            Compound = Info{5};
            % Locate and import full emission spectrum
            D = dir(fullfile(Path, '**', strcat('*_em_', Solvent, '_*_', Compound, '.ifx')));
            if length(D) == 0
                error('Full Emission Sample Data Could Not Be Located: %s', fullfile(Path, '**', strcat('*_em_', Solvent, '_*_', Compound, '.ifx')));
            elseif length(D) == 1
                Idx = 1;
            elseif length(D) > 1
                % Find most recent measurement
                Info = regexp({D.name}.', '_', 'split');
                Info = vertcat(Info{:});
                Dates = str2double(Info(:, 1));
                [~, Idx] = max(Dates);
            end
            FileName = fullfile(D(Idx).folder, D(Idx).name);
            S.Emission = readIfx(FileName);
            % Locate and import full absorption spectrum
            D = dir(fullfile(Path, '**', strcat('*_abs_', Solvent, '_*_', Compound, '.TXT')));
            if length(D) == 0
                warning('Full Emission Sample Data Could Not Be Located');
            elseif length(D) == 1
                Idx = 1;
            elseif length(D) > 1
                % Find most recent measurement
                Info = regexp({D.name}.', '_', 'split');
                Info = vertcat(Info{:});
                Dates = str2double(Info(:, 1));
                [~, Idx] = max(Dates);
            end
            FileName = fullfile(D(Idx).folder, D(Idx).name);
            S.Absorption = readAbs(FileName);
        end
    end
end