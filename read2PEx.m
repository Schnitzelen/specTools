% By Brian Bjarke Jensen (schnitzelen@gmail.com) 25/11-2018

classdef read2PEx < handle
    % Class used for reading and containing two-photon absorption data
    properties
        Title
        Date
        Type
        Solvent
        Concentration
        Compound
        SampleFiles
        Raw
        SpectralRange
        FullEmission
        Data
    end
    methods
        function obj = read2PEx(varargin)
            % Prepare arguments
            obj.SampleFiles = {};
            % Handle varargin
             assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
            for i = 1:2:length(varargin)
                switch varargin{i}
                    case 'SampleFiles'
                        obj.SampleFiles = varargin{i + 1};
                    otherwise
                        error('Unknown Argument Passed: %s', varargin{i})
                end
            end
            % If any arguments are not defined by now, prompt user
            if isempty(obj.SampleFiles)
                [File, Path] = uigetfile('*_2pa_*.txt', 'Please Select 2P Data to Import', 'MultiSelect', 'on');
                assert(isa(Path, 'char') & ~isempty(File), 'No File Selected!')
                obj.SampleFiles = fullfile(Path, File);
            end
            obj.readInfoFromFileName()
            obj.importRawData()
            obj.import1PEmission()
            obj.determineSpectralRange()
            obj.buildDataTable()
        end
        function readInfoFromFileName(obj)
            [~, FileNames, ~] = cellfun(@(x) fileparts(x), obj.SampleFiles, 'UniformOutput', false);
            FileNames = regexp(FileNames, '_', 'split');
            Date = unique(cellfun(@(x) x{1}, FileNames, 'UniformOutput', false));
            assert(length(Date) == 1, 'Multiple Sample Dates Detected!')
            obj.Date = Date{:};
            Type = unique(cellfun(@(x) x{2}, FileNames, 'UniformOutput', false));
            assert(length(Type) == 1, 'Multiple Sample Types Detected!')
            obj.Type = Type{:};
            Solvent = unique(cellfun(@(x) x{3}, FileNames, 'UniformOutput', false));
            assert(length(Solvent) == 1, 'Multiple Sample Solvents Detected!')
            obj.Solvent = Solvent{:};
            Concentration = unique(cellfun(@(x) x{4}, FileNames, 'UniformOutput', false));
            assert(length(Concentration) == 1, 'Multiple Sample Concentrations Detected!')
            [obj.Concentration.Value, obj.Concentration.Unit] = splitStringIntoValueAndUnit(Concentration{:});
            Compound = unique(cellfun(@(x) x{5}, FileNames, 'UniformOutput', false));
            assert(length(Compound) == 1, 'Multiple Sample Compounds Detected!')
            obj.Compound = Compound{:};
            obj.Title = strjoin(FileNames{1}(1:5), '_');
        end
        function importRawData(obj)
            obj.Raw = cellfun(@(x) obj.import2PEx(x), obj.SampleFiles, 'UniformOutput', false);
        end
        function import1PEmission(obj)
            DataFolder = fileparts(obj.SampleFiles{1});
            FileList = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', 'em', 'OnlyNewestUniqueSolvents', true);
            FileList = FileList(contains(FileList, obj.Solvent));
            assert(length(FileList) == 1, 'No Full Emission Data Located For Experiment %s', FileList{1})
            obj.FullEmission = readEm(FileList{1});
        end
        function determineSpectralRange(obj)
            obj.SpectralRange.Emission.Min = max(cellfun(@(x) min(x.Data.Wavelength), obj.Raw));
            obj.SpectralRange.Emission.Max = min(cellfun(@(x) max(x.Data.Wavelength), obj.Raw));
            obj.SpectralRange.Excitation.Min = min(cellfun(@(x) x.ExcitationWavelength, obj.Raw));
            obj.SpectralRange.Excitation.Max = max(cellfun(@(x) x.ExcitationWavelength, obj.Raw));
        end
        function buildDataTable(obj)
            ExcitationWavelengths = cellfun(@(x) x.ExcitationWavelength, obj.Raw);
            UniqueExcitationWavelengths = unique(ExcitationWavelengths);
            obj.Data = cell2table(cell(length(UniqueExcitationWavelengths), 5), 'VariableNames', {'Wavelength', 'MeanIntensity', 'SDIntensity', 'MeanCorrectedIntensity', 'SDCorrectedIntensity'});
            obj.Data.Wavelength = UniqueExcitationWavelengths;
            IntegratedEmission = cellfun(@(x) x.IntegratedEmission, obj.Raw);
            ExcitationWavelengths = cellfun(@(x) x.ExcitationWavelength, obj.Raw);
            Idx = arrayfun(@(x) ExcitationWavelengths == x, obj.Data.Wavelength, 'UniformOutput', false);
            obj.Data.MeanIntensity = cellfun(@(x) mean(IntegratedEmission(x)), Idx);
            obj.Data.SDIntensity = cellfun(@(x) std(IntegratedEmission(x)), Idx);
            CorrectionFactor = obj.FullEmission.calculatePartialEmissionCorrectionFactor(obj.SpectralRange.Emission.Min, obj.SpectralRange.Emission.Max);
            obj.Data.MeanCorrectedIntensity = obj.Data.MeanIntensity * CorrectionFactor;
            obj.Data.SDCorrectedIntensity = obj.Data.SDIntensity * CorrectionFactor;
        end

%         function calculateActionPotential(obj)
%             UsefulData = sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P));
%             if UsefulData == 0
%                 warning('No Useful Data Found For %s', obj.Sample2P.AbsoluteFileName);
%                 obj.Results = cell2table(cell(1, 6), 'VariableNames', {'Wavelength', 'ActionPotential', 'ReferenceCompound', 'ReferenceSolvent', 'SampleFile', 'ReferenceFile'});
%             else
%                 Wavelength = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
%                 ActionPotential = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
%                 ReferenceCompound = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
%                 ReferenceSolvent = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
%                 SampleFile = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
%                 ReferenceFile = cell(sum(cellfun(@(x) x.IsExcitationInTableValues, obj.Reference2P)), 1);
%                 for i = 1:length(obj.Reference2P)
%                     if obj.Reference2P{i}.IsExcitationInTableValues
%                         Wavelength{i} = obj.Sample2P.ExcitationWavelength;
%                         SampleContribution = obj.Sample2P.CorrectedEmissionIntensity / obj.Sample2P.Concentration;
%                         ReferenceContribution = obj.Reference2P{i}.CorrectedEmissionIntensity / obj.Reference2P{i}.Concentration;
%                         ReferenceTableValueTPA = obj.TableValues.ReferenceTPA{i}.TPA(obj.TableValues.ReferenceTPA{i}.Wavelength == Wavelength{i});
%                         ActionPotential{i} = round(SampleContribution / ReferenceContribution * ReferenceTableValueTPA, 5, 'significant');
%                         ReferenceCompound{i} = obj.Reference2P{i}.Compound;
%                         ReferenceSolvent{i} = obj.Reference2P{i}.Solvent;
%                         SampleFile{i} = obj.Sample2P.Title;
%                         ReferenceFile{i} = obj.Reference2P{i}.Title;
%                     end
%                 end
%                 obj.Results = table(Wavelength, ActionPotential, ReferenceCompound, ReferenceSolvent, SampleFile, ReferenceFile);
%             end
%         end
%         function estimateOptimalConcentration(obj)
%             % Estimate optimal concentration
%             DetectorSaturationIntensity = 64000;
%             TargetIntensity = DetectorSaturationIntensity * 0.8;
%             MaxIntensity = max(S.Data(:, 4));
%             S.OptimalConcentration = round(S.Concentration * TargetIntensity / MaxIntensity, 5, 'significant');
%             if MaxIntensity < 0.001 * DetectorSaturationIntensity
%                 warning('Low Emission Intensity For Sample %s. Actual Concentration Is %d uM, Suggested Concentration Is %d uM.', S.Title, (S.Concentration * 10^6), (S.OptimalConcentration * 10^6));
%             end
%         end
%         function Fig = plotEmissionOverlap(obj)
%             Fig = cell(length(obj.Reference2P), 1);
%             for i = 1:length(obj.Reference2P)
%                 Fig{i} = figure;
%                 hold on
%                 % Sample
%                 plot(obj.Sample1P.Data.EmissionWavelength, obj.Sample1P.Data.NormalizedCorrectedIntensity, '.b', 'LineWidth', 2, 'DisplayName', sprintf('%s (%s)', obj.Sample2P.Compound, obj.Sample2P.Solvent));
%                 plot([obj.Sample2P.LowerSpectralLimit, obj.Sample2P.LowerSpectralLimit], [0, 1], '--b', 'DisplayName', '2P Range');
%                 plot([obj.Sample2P.UpperSpectralLimit, obj.Sample2P.UpperSpectralLimit], [0, 1], '--b', 'HandleVisibility', 'off');
%                 % Reference
%                 plot(obj.Reference1P{i}.Data.EmissionWavelength, obj.Reference1P{i}.Data.NormalizedCorrectedIntensity, '.r', 'LineWidth', 2, 'DisplayName', sprintf('%s (%s)', obj.Reference2P{i}.Compound, obj.Reference2P{i}.Solvent));
%                 plot([obj.Reference2P{i}.LowerSpectralLimit, obj.Reference2P{i}.LowerSpectralLimit], [0, 1], '--r', 'DisplayName', '2P Range');
%                 plot([obj.Reference2P{i}.UpperSpectralLimit, obj.Reference2P{i}.UpperSpectralLimit], [0, 1], '--r', 'HandleVisibility', 'off');
%                 title('\textbf{Emission}', 'Interpreter', 'latex');
%                 xlabel('Wavelength (nm)', 'Interpreter', 'latex');
%                 ylabel('Normalized Intensity (a.u.)', 'Interpreter', 'latex');
%                 legend({}, 'Interpreter', 'latex');
%                 hold off
%             end
%         end
%         function Fig = plotExcitationOverlap(obj)
%             Fig = cell(length(obj.Reference2P), 1);
%             for i = 1:length(obj.Reference2P)
%                 Fig{i} = figure;
%                 hold on
%                 % Reference TPA
%                 plot(obj.TableValues.ReferenceTPA{i}.Wavelength, obj.TableValues.ReferenceTPA{i}.TPA, '-or', 'LineWidth', 2, 'DisplayName', sprintf('%s (%s)', obj.TableValues.ReferenceCompound{i}, obj.TableValues.ReferenceSolvent{i}));
%                 % Excitation wavelength
%                 plot([obj.Sample2P.ExcitationWavelength, obj.Sample2P.ExcitationWavelength], [0, max(obj.TableValues.ReferenceTPA{i}.TPA)], '--k', 'DisplayName', '$\lambda_{ex}$');
%                 title('\textbf{2P Action Potential}', 'Interpreter', 'latex');
%                 xlabel('Wavelength (nm)', 'Interpreter', 'latex');
%                 ylabel('$\Phi \cdot \sigma_{2P}$ (GM)', 'Interpreter', 'latex');
%                 legend({}, 'Interpreter', 'latex');
%                 hold off
%             end
%         end
%         function saveResults(obj)
%             [Folder, Name, ~] = fileparts(obj.Sample2P.AbsoluteFileName);
%             FileName = fullfile(fileparts(Folder), strcat(Name, '_results.csv'));
%             writetable(obj.Results, FileName);
%         end
    end
    methods(Static)
        function S = import2PEx(FileName)
            S.AbsoluteFileName = FileName;
            [~, S.Title, ~] = fileparts(S.AbsoluteFileName);
            Info = strsplit(S.Title, '_');
            S.Replicate = str2double(Info{6});
            S.ExcitationWavelength = str2double(Info{7});
            S.Intensity = str2double(Info{8});
            S.Dilution = str2double(Info{9});
            Data = importdata(S.AbsoluteFileName);
            Data = Data(4:end, :); % remove first 3 datapoints that are always weird
            S.Data = table(Data(:, 1), Data(:, 4), 'VariableNames', {'Wavelength', 'Intensity'});
            S.IntegratedEmission = trapz(S.Data.Wavelength, S.Data.Intensity);
        end
    end
end