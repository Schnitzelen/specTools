% By Brian Bjarke Jensen (schnitzelen@gmail.com) 19/12-2019

classdef multi2PEx < handle
    % Class used for collecting and containing multiple two-photon excitation data
    properties
        AbsoluteFileList
        SampleCompound
        SampleSolvent
        Data
        Raw
        Results
    end
    methods
        function obj = multi2PEx(AbsoluteFileList)
            % Ask for filelist, if none is provided
            if ~exist('AbsoluteFileList', 'var')
                [File, Path] = uigetfile('*_2pa_*.txt', 'Please Select 2P Data to Import', 'MultiSelect', 'on');
                assert(length(File) > 1,  'Multiple Files Must Be Selected!');
                AbsoluteFileList = cellfun(@(x) fullfile(Path, x), File, 'UniformOutput', false);
            end
            obj.AbsoluteFileList = AbsoluteFileList;
            assert(length(obj.AbsoluteFileList) > 1, 'Multiple Files Must Be Selected!');
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
            obj.saveResults();
            obj.plotRawTPA();
            obj.plotTPA();
        end
        function importData(obj)
            Data = cell(length(obj.AbsoluteFileList), 1);
            AbsoluteFileList = obj.AbsoluteFileList;
            for i = 1:length(obj.AbsoluteFileList)
                Data{i} = read2PEx(AbsoluteFileList{i});
            end
            obj.Data = Data;
            SampleCompound = unique(cellfun(@(x) x.Sample2P.Compound, obj.Data, 'UniformOutput', false));
            assert(length(SampleCompound) == 1, 'Multiple Sample Compounds Selected!');
            obj.SampleCompound = SampleCompound{1};
            SampleSolvent = unique(cellfun(@(x) x.Sample2P.Solvent, obj.Data, 'UniformOutput', false));
            assert(length(SampleSolvent) == 1, 'Multiple Sample Solvents Selected!');
            obj.SampleSolvent = SampleSolvent{1};
        end
        function buildRawTable(obj)
            % Determine unique combinations of reference compound and solvent
            ReferenceTPA = cellfun(@(x) x.TableValues, obj.Data, 'UniformOutput', false);
            ReferenceTPA = vertcat(ReferenceTPA{:});
            RemoveIdx = zeros(height(ReferenceTPA), 1);
            for i = 1:height(ReferenceTPA)
                IsCompoundAlreadyPresent = any(strcmp(ReferenceTPA.ReferenceCompound(1:i-1), ReferenceTPA.ReferenceCompound(i)));
                IsSolventAlreadyPresent = any(strcmp(ReferenceTPA.ReferenceSolvent(1:i-1), ReferenceTPA.ReferenceSolvent(i)));
                IsReoccuring(i) = and(IsCompoundAlreadyPresent, IsSolventAlreadyPresent);
            end
            ReferenceTPA = ReferenceTPA(~IsReoccuring, :);
            Data = cell(height(ReferenceTPA), 1);
            ReferenceTPA = [ReferenceTPA, cell2table(Data, 'VariableNames', {'Data'})];
            % Create results table based on references
            Results = cellfun(@(x) [x.Results.Wavelength, x.Results.ActionPotential, x.Results.ReferenceCompound, x.Results.ReferenceSolvent], obj.Data, 'UniformOutput', false);
            Results = vertcat(Results{:});
            for i = 1:height(ReferenceTPA)
                IsReferenceCompound = strcmp(Results(:, 3), ReferenceTPA.ReferenceCompound(i));
                IsReferenceSolvent = strcmp(Results(:, 4), ReferenceTPA.ReferenceSolvent(i));
                Idx = and(IsReferenceCompound, IsReferenceSolvent);
                ReferenceTPA.Data{i} = cell2table(Results(Idx, 1:2), 'VariableNames', {'Wavelength', 'AP'});
            end
            obj.Raw = ReferenceTPA;
        end
        function buildResultsTable(obj)
            Wavelength = cellfun(@(x) x.Wavelength, obj.Raw.Data, 'UniformOutput', false);
            Wavelength = unique(vertcat(Wavelength{:}));
            obj.Results = array2table(Wavelength, 'VariableNames', {'wavelength_nm'});
            for i = 1:height(obj.Raw)
                AP = NaN(height(obj.Results), 2);
                MeasuredWavelengths = unique(obj.Raw.Data{i}.Wavelength);
                for j = 1:length(MeasuredWavelengths)
                    SpecificWavelength = MeasuredWavelengths(j);
                    SpecificAPs = obj.Raw.Data{i}.AP(obj.Raw.Data{i}.Wavelength == SpecificWavelength);
                    SpecificAPs(SpecificAPs < 0) = [];
                    Mean = mean(SpecificAPs); % use median instead?
                    Error = (SpecificAPs - Mean).^2;
                    SD = std(SpecificAPs);
                    while SD > ( 0.1 * Mean )
                        [~, Idx] = max(Error);
                        SpecificAPs(Idx) = [];
                        Mean = mean(SpecificAPs);
                        Error = (SpecificAPs - Mean).^2;
                        SD = std(SpecificAPs);
                    end
                    Idx = find(obj.Results.wavelength_nm == SpecificWavelength);
                    if length(SpecificAPs) > 0
                        AP(Idx, 1) = round(Mean, 5, 'significant');
                    end
                    if length(SpecificAPs) > 1
                        AP(Idx, 2) = round(SD, 5, 'significant');
                    end
                end 
                obj.Results = [obj.Results, array2table(AP, 'VariableNames', {sprintf('mean_AP_GM_ref_%s_%s', obj.Raw.ReferenceCompound{i}, strrep(obj.Raw.ReferenceSolvent{i}, ',', '_')), sprintf('SD_AP_GM_ref_%s_%s', obj.Raw.ReferenceCompound{i}, strrep(obj.Raw.ReferenceSolvent{i}, ',', '_'))})];
            end
        end
        function saveResults(obj)
            [Folder, ~, ~] = fileparts(obj.AbsoluteFileList{1});
            FileName = fullfile(fileparts(Folder), strcat('2P_action_potential_', obj.SampleSolvent, '_results.csv'));
            writetable(obj.Results, FileName);
        end
        function Fig = plotRawTPA(obj)
            Fig = cell(height(obj.Raw), 1);
            for i = 1:height(obj.Raw)
                Fig{i} = figure;
                hold on
                % Reference
                plot(obj.Raw.ReferenceTPA{i}.Wavelength, obj.Raw.ReferenceTPA{i}.TPA, '-ok', 'DisplayName', sprintf('%s (%s)', obj.Raw.ReferenceCompound{i}, obj.Raw.ReferenceSolvent{i}))
                % Sample
                plot(obj.Raw.Data{i}.Wavelength, obj.Raw.Data{i}.AP, 'ob', 'LineWidth', 2, 'DisplayName',  sprintf('%s (%s)', obj.SampleCompound, obj.SampleSolvent))               
                title('\textbf{2P Action Potential}', 'Interpreter', 'latex');
                xlabel('Wavelength (nm)', 'Interpreter', 'latex');
                ylabel('$\Phi \cdot \sigma_{2P}$ (GM)', 'Interpreter', 'latex');
                legend({}, 'Interpreter', 'latex');
                hold off
            end
        end
        function plotTPA(obj)
            for i = 1:height(obj.Raw)
                Fig = figure;
                hold on
                % Reference
                plot(obj.Raw.ReferenceTPA{i}.Wavelength, obj.Raw.ReferenceTPA{i}.TPA, '-ok', 'DisplayName', sprintf('%s (%s)', obj.Raw.ReferenceCompound{i}, obj.Raw.ReferenceSolvent{i}))
                % Sample
                MeanAPIdx = i * 2;
                SDAPIdx = MeanAPIdx + 1;
                Wavelength = table2array(obj.Results(:, 1));
                MeanAP = table2array(obj.Results(:, MeanAPIdx));
                SDAP = table2array(obj.Results(:, SDAPIdx));
                IsNaN = isnan(MeanAP);
                errorbar(Wavelength(~IsNaN), MeanAP(~IsNaN), SDAP(~IsNaN), 'ob', 'LineWidth', 2, 'DisplayName',  sprintf('%s (%s)', obj.SampleCompound, obj.SampleSolvent))
                title('\textbf{2P Action Potential}', 'Interpreter', 'latex');
                xlabel('Wavelength (nm)', 'Interpreter', 'latex');
                ylabel('$\Phi \cdot \sigma_{2P}$ (GM)', 'Interpreter', 'latex');
                legend({}, 'Interpreter', 'latex');
                hold off
                [Folder, ~, ~] = fileparts(obj.AbsoluteFileList{1});
                FileName = fullfile(fileparts(Folder), strcat('2P_action_potential_', obj.SampleSolvent, '_ref_', obj.Raw.ReferenceCompound{i}, '_', obj.Raw.ReferenceSolvent{i}, '_plot'));
                print(Fig, FileName, '-dpng');
            end
        end
    end
end