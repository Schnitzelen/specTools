% By Brian Bjarke Jensen 17/1-2019

classdef wrapQY < handle
    % Class used for containing and organizing multiple readQY data-objects
    properties
        AbsoluteFolderPath
        Results
        Raw
        Data
    end
    methods
        function obj = wrapQY(AbsoluteFolderPath)
            % Ask for folder, if none is provided
            if ~exist('AbsoluteFolderPath', 'var')
                AbsoluteFolderPath = uigetdir(pwd(), 'Please Select Folder Containing Quantum Yield Data to Import');
            end
            obj.AbsoluteFolderPath = AbsoluteFolderPath;
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
        end
        function importData(obj)
            % Determine absorption filenames
            AbsD = dir(fullfile(obj.AbsoluteFolderPath, '**', '*_qy_*.TXT'));
            Info = regexp({AbsD.name}.', '_', 'split');
            AbsDates = cellfun(@(x) x{1}, Info, 'UniformOutput', false);
            % Determine emission filenames
            EmD = dir(fullfile(obj.AbsoluteFolderPath, '**', '*_qy_*.ifx'));
            Info = regexp({EmD.name}.', '_', 'split');
            EmDates = cellfun(@(x) x{1}, Info, 'UniformOutput', false);
            % Drop filenames without partner
            PairIdx = cellfun(@(x) strcmp(AbsDates.', x), EmDates, 'UniformOutput', false);
            PairIdx = vertcat(PairIdx{:});
            IsAbsInEm = any(PairIdx, 1);
            IsEmInAbs = any(PairIdx, 2);
            AbsD = AbsD(IsAbsInEm);
            EmD = EmD(IsEmInAbs);
            % Split files by date, solvent and compound, and create filelist
            AbsInfo = regexp({AbsD.name}.', '_', 'split');
            AbsInfo = vertcat(AbsInfo{:});
            AbsDates = AbsInfo(:, 1);
            AbsSolvents = AbsInfo(:, 3);
            AbsCompounds = regexp(AbsInfo(:, 5), '\.', 'split');
            AbsCompounds = vertcat(AbsCompounds{:});
            AbsCompounds = AbsCompounds(:, 1);
            [~, Idx, ~] = unique(cellfun(@(x, y, z) strcat(x, y, z), AbsDates, AbsSolvents, AbsCompounds, 'UniformOutput', false));
            UniqueDates = AbsDates(Idx);
            UniqueSolvents = AbsSolvents(Idx);
            UniqueCompounds = AbsCompounds(Idx);
            EmInfo = regexp({EmD.name}.', '_', 'split');
            EmInfo = vertcat(EmInfo{:});
            EmDates = EmInfo(:, 1);
            EmSolvents = EmInfo(:, 3);
            EmCompounds = regexp(EmInfo(:, 5), '\.', 'split');
            EmCompounds = vertcat(EmCompounds{:});
            EmCompounds = EmCompounds(:, 1);
            FileList = cell(length(UniqueSolvents), 1);
            for i = 1:length(AbsDates)
                % Absorption
                IsSameDate = strcmp(UniqueDates, AbsDates{i});
                IsSameSolvent = strcmp(UniqueSolvents, AbsSolvents{i});
                IsSameCompound = strcmp(UniqueCompounds, AbsCompounds{i});
                Idx = IsSameDate & IsSameSolvent & IsSameCompound;
                FileList{Idx}{end + 1, 1} = fullfile(AbsD(i).folder, AbsD(i).name);
                % Emission
                IsSameDate = strcmp(UniqueDates, EmDates{i});
                IsSameSolvent = strcmp(UniqueSolvents, EmSolvents{i});
                IsSameCompound = strcmp(UniqueCompounds, EmCompounds{i});
                Idx = IsSameDate & IsSameSolvent & IsSameCompound;
                FileList{Idx}{end + 1, 1} = fullfile(EmD(i).folder, EmD(i).name);
            end
            % Calculate quantum yield
            obj.Data = cellfun(@(x) calcQY(x), FileList, 'UniformOutput', false);
            % Sort results according to polarity
            if length(obj.Data) > 1
                PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
                [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x.Solvent)), obj.Data), 'descend');
                obj.Data = obj.Data(PolaritySorting);
            end
        end
        function buildRawTable(obj)
            obj.Raw = cellfun(@(x) x.Raw, obj.Data, 'UniformOutput', false);
            obj.Raw = vertcat(obj.Raw{:});
        end
        function buildResultsTable(obj)
            ColumnNames = obj.Data{1}.Results.Properties.VariableNames;
            obj.Results = cellfun(@(x) table2cell(x.Results), obj.Data, 'UniformOutput', false);
            obj.Results = cell2table(vertcat(obj.Results{:}), 'VariableNames', ColumnNames);
        end
        function Fig = plotRaw(obj)
            Fig = cell(length(obj.Data), 1);
            for i = 1:length(obj.Data)
                Fig{i} = obj.Data{i}.plotRaw();
            end
        end
        function Fig = plotSpectralOverlap(obj)
            Fig = cell(length(obj.Data), 1);
            for i = 1:length(obj.Data)
                Fig{i} = obj.Data{i}.plotSpectralOverlap();
            end
        end
    end
end             