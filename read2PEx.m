% By Brian Bjarke Jensen (schnitzelen@gmail.com) 25/11-2018

classdef read2PEx < handle
    % Class used for reading and containing two-photon absorption data
    properties
        TableValuePath
        TableValues
        Sample2P
        Sample1P
        Reference2P
        Reference1P
        Results
    end
    methods
        function obj = read2PEx(AbsoluteFileName)
            obj.TableValuePath = fullfile(getenv('userprofile'), '\Documents\Matlab\SpecTools\');
            % Ask for path, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*_2pa_*.txt', 'Please Select 2P Data to Import');
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.Sample2P.AbsoluteFileName = AbsoluteFileName;
            obj.import2PExSample();
            obj.import1PEmSample();
            obj.import2PExReference();
            obj.import1PEmReference();
            obj.calculateCorrectedEmissionIntensity();
            obj.lookUpReferenceTableValueTPA();
            obj.determineExcitationSpectralOverlapWithReferences();
            obj.calculateActionPotential();
        end
        function import2PExSample(obj)
            obj.Sample2P = obj.import2PEx(obj.Sample2P.AbsoluteFileName);
        end
        function import1PEmSample(obj)
            obj.Sample1P = obj.import1PEm(obj.Sample2P);
        end
        function import2PExReference(obj)
            ParentFolder = fileparts(fileparts(fileparts(obj.Sample2P.AbsoluteFileName)));
            FileName = dir(fullfile(ParentFolder, '**', strcat(obj.Sample2P.Date, '_2pa_*_', num2str(obj.Sample2P.Replicate), '_', num2str(obj.Sample2P.ExcitationWavelength), '_*')));
            assert(~isempty(FileName), 'No Reference 2P Excitation Files Found!');
            if length(FileName) > 1
                % Choose possible references
                Info = regexp({FileName.name}.', '_', 'split');
                Info = vertcat(Info{:});
                Solvent = Info(:, 3);
                Compound = Info(:, 5);
                TableValueFileNames = dir(fullfile(obj.TableValuePath, 'tpa_reference_*'));
                TableValues = regexp({TableValueFileNames.name}.', '_', 'split');
                TableValues = vertcat(TableValues{:});
                TableSolvents = TableValues(:,3);
                TableCompounds = regexp(TableValues(:,4), '\.', 'split');
                TableCompounds = vertcat(TableCompounds{:});
                TableCompounds = TableCompounds(:, 1);
                IsSolventInTableValues = cellfun(@(x) any(strcmp(x, TableSolvents)), Solvent);
                IsCompoundInTableValues = cellfun(@(x) any(strcmp(x, TableCompounds)), Compound);
                IsValidReference = and(IsSolventInTableValues, IsCompoundInTableValues);
                FileName = FileName(IsValidReference);
            end
            obj.Reference2P = cell(length(FileName), 1);
            for i = 1:length(FileName)
                obj.Reference2P{i} = obj.import2PEx(fullfile(FileName(i).folder, FileName(i).name));
            end
        end
        function import1PEmReference(obj)
            obj.Reference1P = cell(length(obj.Reference2P), 1);
            for i = 1:length(obj.Reference2P)
                obj.Reference1P{i} = obj.import1PEm(obj.Reference2P{i});
            end
        end
        function calculateCorrectedEmissionIntensity(obj)
            % Sample full emission
            UpperSpectralLimit = obj.Sample1P.SpectralRange.Emission.Max;
            LowerSpectralLimit = obj.Sample1P.SpectralRange.Emission.Min;
            Idx = and(LowerSpectralLimit <= obj.Sample1P.Data.EmissionWavelength, obj.Sample1P.Data.EmissionWavelength <= UpperSpectralLimit);
            FullEmission = trapz(obj.Sample1P.Data.EmissionWavelength(Idx), obj.Sample1P.Data.NormalizedCorrectedIntensity(Idx));
            % Sample partial emission
            obj.Sample2P.UpperSpectralLimit = min(obj.Sample2P.SpectralRange.Max, obj.Sample1P.SpectralRange.Emission.Max);
            obj.Sample2P.LowerSpectralLimit = max(obj.Sample2P.SpectralRange.Min, obj.Sample1P.SpectralRange.Emission.Min);
            Idx = and(obj.Sample2P.LowerSpectralLimit <= obj.Sample1P.Data.EmissionWavelength, obj.Sample1P.Data.EmissionWavelength <= obj.Sample2P.UpperSpectralLimit);
            PartialEmission = trapz(obj.Sample1P.Data.EmissionWavelength(Idx), obj.Sample1P.Data.NormalizedCorrectedIntensity(Idx));
            % Sample correction factor
            obj.Sample2P.EmissionCorrectionFactor = FullEmission / PartialEmission;
            % Sample corrected integrated emission
            Idx = and(obj.Sample2P.LowerSpectralLimit <= obj.Sample2P.Data(:, 1), obj.Sample2P.Data(:, 1) <= obj.Sample2P.UpperSpectralLimit);
            obj.Sample2P.CorrectedEmissionIntensity = obj.Sample2P.EmissionCorrectionFactor * trapz(obj.Sample2P.Data(Idx, 1), obj.Sample2P.Data(Idx, 4));
            % References
            for i = 1:length(obj.Reference2P)
                % Full emission
                UpperSpectralLimit = obj.Reference1P{i}.SpectralRange.Emission.Max;
                LowerSpectralLimit = obj.Reference1P{i}.SpectralRange.Emission.Min;
                Idx = and(LowerSpectralLimit <= obj.Reference1P{i}.Data.EmissionWavelength, obj.Reference1P{i}.Data.EmissionWavelength <= UpperSpectralLimit);
                FullEmission = trapz(obj.Reference1P{i}.Data.EmissionWavelength(Idx), obj.Reference1P{i}.Data.NormalizedCorrectedIntensity(Idx));
                % Partial emission
                obj.Reference2P{i}.UpperSpectralLimit = min(obj.Reference2P{i}.SpectralRange.Max, obj.Reference1P{i}.SpectralRange.Emission.Max);
                obj.Reference2P{i}.LowerSpectralLimit = max(obj.Reference2P{i}.SpectralRange.Min, obj.Reference1P{i}.SpectralRange.Emission.Min);
                Idx = and(obj.Reference2P{i}.LowerSpectralLimit <= obj.Reference1P{i}.Data.EmissionWavelength, obj.Reference1P{i}.Data.EmissionWavelength <= obj.Reference2P{i}.UpperSpectralLimit);
                PartialEmission = trapz(obj.Reference1P{i}.Data.EmissionWavelength(Idx), obj.Reference1P{i}.Data.NormalizedCorrectedIntensity(Idx));
                % Correction factor
                obj.Reference2P{i}.EmissionCorrectionFactor = FullEmission / PartialEmission;
                % Corrected integrated emission
                Idx = and(obj.Reference2P{i}.LowerSpectralLimit <= obj.Reference2P{i}.Data(:, 1), obj.Reference2P{i}.Data(:, 1) <= obj.Reference2P{i}.UpperSpectralLimit);
                obj.Reference2P{i}.CorrectedEmissionIntensity = obj.Reference2P{i}.EmissionCorrectionFactor * trapz(obj.Reference2P{i}.Data(Idx, 1), obj.Reference2P{i}.Data(Idx, 4));
            end 
        end
        function lookUpReferenceTableValueTPA(obj)
            ReferenceSolvent = cell(length(obj.Reference2P), 1);
            ReferenceCompound = cell(length(obj.Reference2P), 1);
            ReferenceTPA = cell(length(obj.Reference2P), 1);
            for i = 1:length(obj.Reference2P)
                ReferenceSolvent{i} = obj.Reference2P{i}.Solvent;
                ReferenceCompound{i} = obj.Reference2P{i}.Compound;
                ReferenceTPA{i} = readtable(fullfile(obj.TableValuePath, strcat('tpa_reference_', ReferenceSolvent{i}, '_', ReferenceCompound{i}, '.csv')));
            end
            obj.TableValues = table(ReferenceSolvent, ReferenceCompound, ReferenceTPA);
        end
        function determineExcitationSpectralOverlapWithReferences(obj)
            for i = 1:length(obj.Reference2P)
                IsExcitationAboveMinumumTableValueWavelength = min(obj.TableValues.ReferenceTPA{i}.Wavelength) <= obj.Reference2P{i}.ExcitationWavelength;
                IsExcitationBelowMaximumTableValueWavelength = obj.Reference2P{i}.ExcitationWavelength <= max(obj.TableValues.ReferenceTPA{i}.Wavelength);
                obj.Reference2P{i}.IsExcitationInTableValues = and(IsExcitationAboveMinumumTableValueWavelength, IsExcitationBelowMaximumTableValueWavelength);
            end
        end
        function calculateActionPotential(obj)
            UsefulData = sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P));
            if UsefulData == 0
                warning('No Useful Data Found For %s', obj.Sample2P.AbsoluteFileName);
                obj.Results = cell2table(cell(1, 6), 'VariableNames', {'Wavelength', 'ActionPotential', 'ReferenceCompound', 'ReferenceSolvent', 'SampleFile', 'ReferenceFile'});
            else
                Wavelength = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
                ActionPotential = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
                ReferenceCompound = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
                ReferenceSolvent = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
                SampleFile = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
                ReferenceFile = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
                for i = 1:length(obj.Reference2P)
                    if obj.Reference2P{i}.IsExcitationInTableValues
                        Wavelength{i} = obj.Sample2P.ExcitationWavelength;
                        SampleContribution = obj.Sample2P.CorrectedEmissionIntensity / obj.Sample2P.Concentration;
                        ReferenceContribution = obj.Reference2P{i}.CorrectedEmissionIntensity / obj.Reference2P{i}.Concentration;
                        ReferenceTableValueTPA = obj.TableValues.ReferenceTPA{i}.TPA(obj.TableValues.ReferenceTPA{i}.Wavelength == Wavelength{i});
                        ActionPotential{i} = round(SampleContribution / ReferenceContribution * ReferenceTableValueTPA, 5, 'significant');
                        ReferenceCompound{i} = obj.Reference2P{i}.Compound;
                        ReferenceSolvent{i} = obj.Reference2P{i}.Solvent;
                        SampleFile{i} = obj.Sample2P.Title;
                        ReferenceFile{i} = obj.Reference2P{i}.Title;
                    end
                end
                obj.Results = table(Wavelength, ActionPotential, ReferenceCompound, ReferenceSolvent, SampleFile, ReferenceFile);
            end
        end
        function Fig = plotEmissionOverlap(obj)
            Fig = cell(length(obj.Reference2P), 1);
            for i = 1:length(obj.Reference2P)
                Fig{i} = figure;
                hold on
                % Sample
                plot(obj.Sample1P.Data.EmissionWavelength, obj.Sample1P.Data.NormalizedCorrectedIntensity, '.b', 'LineWidth', 2, 'DisplayName', sprintf('%s (%s)', obj.Sample2P.Compound, obj.Sample2P.Solvent));
                plot([obj.Sample2P.LowerSpectralLimit, obj.Sample2P.LowerSpectralLimit], [0, 1], '--b', 'DisplayName', '2P Range');
                plot([obj.Sample2P.UpperSpectralLimit, obj.Sample2P.UpperSpectralLimit], [0, 1], '--b', 'HandleVisibility', 'off');
                % Reference
                plot(obj.Reference1P{i}.Data.EmissionWavelength, obj.Reference1P{i}.Data.NormalizedCorrectedIntensity, '.r', 'LineWidth', 2, 'DisplayName', sprintf('%s (%s)', obj.Reference2P{i}.Compound, obj.Reference2P{i}.Solvent));
                plot([obj.Reference2P{i}.LowerSpectralLimit, obj.Reference2P{i}.LowerSpectralLimit], [0, 1], '--r', 'DisplayName', '2P Range');
                plot([obj.Reference2P{i}.UpperSpectralLimit, obj.Reference2P{i}.UpperSpectralLimit], [0, 1], '--r', 'HandleVisibility', 'off');
                title('\textbf{Emission}', 'Interpreter', 'latex');
                xlabel('Wavelength (nm)', 'Interpreter', 'latex');
                ylabel('Normalized Intensity (a.u.)', 'Interpreter', 'latex');
                legend({}, 'Interpreter', 'latex');
                hold off
            end
        end
        function Fig = plotExcitationOverlap(obj)
            Fig = cell(length(obj.Reference2P), 1);
            for i = 1:length(obj.Reference2P)
                Fig{i} = figure;
                hold on
                % Reference TPA
                plot(obj.TableValues.ReferenceTPA{i}.Wavelength, obj.TableValues.ReferenceTPA{i}.TPA, '-or', 'LineWidth', 2, 'DisplayName', sprintf('%s (%s)', obj.TableValues.ReferenceCompound{i}, obj.TableValues.ReferenceSolvent{i}));
                % Excitation wavelength
                plot([obj.Sample2P.ExcitationWavelength, obj.Sample2P.ExcitationWavelength], [0, max(obj.TableValues.ReferenceTPA{i}.TPA)], '--k', 'DisplayName', '$\lambda_{ex}$');
                title('\textbf{2P Action Potential}', 'Interpreter', 'latex');
                xlabel('Wavelength (nm)', 'Interpreter', 'latex');
                ylabel('$\Phi \cdot \sigma_{2P}$ (GM)', 'Interpreter', 'latex');
                legend({}, 'Interpreter', 'latex');
                hold off
            end
        end
        function saveResults(obj)
            [Folder, Name, ~] = fileparts(obj.Sample2P.AbsoluteFileName);
            FileName = fullfile(fileparts(Folder), strcat(Name, '_results.csv'));
            writetable(obj.Results, FileName);
        end
    end
    methods(Static)
        function S = import2PEx(FileName)
            S.AbsoluteFileName = FileName;
            Info = strsplit(S.AbsoluteFileName, '\');
            S.Title = Info{end};
            Info = strsplit(S.Title, '_');
            S.Date = Info{1};
            S.Type = Info{2};
            S.Solvent = Info{3};
            Unit = {'mM', 'uM', 'nM', 'pM'};
            Factor = [10^-3, 10^-6, 10^-9, 10^-12];
            S.Concentration = str2double(strrep(Info{4}(1:end-2), ',', '.')) * Factor(strcmp(Info{4}(end-1:end), Unit));
            S.Compound = Info{5};
            S.Replicate = str2double(Info{6});
            S.ExcitationWavelength = str2double(Info{7});
            S.Intensity = str2double(Info{8});
            S.Dilution = str2double(Info{9}(1:end-4));
            S.Data = importdata(S.AbsoluteFileName);
            S.Data = S.Data(4:end, :); % remove first 3 datapoints that are always weird
            S.IntegratedEmission = trapz(S.Data(:, 1), S.Data(:, 4));
            S.SpectralRange.Min = min(S.Data(:, 1));
            S.SpectralRange.Max = max(S.Data(:, 1));
            % Estimate optimal concentration
            DetectorSaturationIntensity = 64000;
            TargetIntensity = DetectorSaturationIntensity * 0.8;
            MaxIntensity = max(S.Data(:, 4));
            S.OptimalConcentration = round(S.Concentration * TargetIntensity / MaxIntensity, 5, 'significant');
            if MaxIntensity < 0.001 * DetectorSaturationIntensity
                warning('Low Emission Intensity For Sample %s. Actual Concentration Is %d uM, Suggested Concentration Is %d uM.', S.Title, (S.Concentration * 10^6), (S.OptimalConcentration * 10^6));
            end
        end
        function S = import1PEm(Data2P)
            ParentFolder = fileparts(Data2P.AbsoluteFileName);
            FileNameTemplate = fullfile(ParentFolder, strcat('*em_', Data2P.Solvent, '*'));
            FileName = dir(FileNameTemplate);
            assert(~isempty(FileName), sprintf('No 1P Emission Files Found: %s', FileNameTemplate));
            if length(FileName) > 1
                % Choose most recent measurement
                Dates = cellfun(@(x) str2double(x(1:6)), {FileName.name}.');
                [~, Idx] = max(Dates);
                FileName = FileName(Idx);
            end
            FileName = fullfile(FileName.folder, FileName.name);
            [~, ~, Ext] = fileparts(FileName);
            switch Ext
                case '.ifx'
                    S = readIfx(FileName);
                case '.rtf'
                    % Read file
                    fid = fopen(FileName);
                    Header = cellfun(@(x) fgetl(fid), cell(3, 1), 'UniformOutput', false);
                    Text = cell(0, 1);
                    while ~feof(fid)
                        Text{end+1, 1} = fgetl(fid);
                    end
                    fclose(fid);
                    Text = Text(1:end-2);
                    Text = regexprep(Text, ',', '.');
                    Info = cellfun(@(x) textscan(x, '%f\\tab %f\\par'), Text, 'UniformOutput', false);
                    Info = vertcat(Info{:});
                    % Create data-table
                    S.Data = cell2table(Info, 'VariableNames', {'EmissionWavelength', 'CorrectedIntensity'});
                    % Create spectral range struct
                    S.RelativeLimit = 0.05;
                    NormalizedCorrectedIntensity = S.Data.CorrectedIntensity / max(S.Data.CorrectedIntensity);
                    S.Data = [S.Data, array2table(NormalizedCorrectedIntensity)];
                    Idx = S.Data.NormalizedCorrectedIntensity >= S.RelativeLimit;
                    S.SpectralRange.Emission.Max = max(S.Data.EmissionWavelength(Idx));
                    S.SpectralRange.Emission.Min = min(S.Data.EmissionWavelength(Idx));
                otherwise
                    error('Sample 1P Emission File Format Not Supported!');
            end
        end
    end
end