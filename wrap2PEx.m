% By Brian Bjarke Jensen 21/1-2019

classdef wrap2PEx < handle
    % Class used for containing and organizing multiple solvent analysis of
    % multi2PEx data-objects
    properties
        AbsoluteFolderPath
        Results
        Raw
        Data
    end
    methods
        function obj = wrap2PEx(AbsoluteFolderPath)
            % Ask for folder, if none is provided
            if ~exist('AbsoluteFolderPath', 'var')
                AbsoluteFolderPath = uigetdir(pwd(), 'Please Select Folder Containing 2P Absorption Data to Import');
            end
            obj.AbsoluteFolderPath = AbsoluteFolderPath;
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
        end
        function importData(obj)
            D = dir(fullfile(obj.AbsoluteFolderPath, 'data\*_2pa_*.txt'));
            Solvents = regexp({D.name}.', '_', 'split');
            Solvents = unique(cellfun(@(x) x{3}, Solvents, 'UniformOutput', false));
            Index = cellfun(@(x) contains({D.name}.', x), Solvents, 'UniformOutput', false);
            FileList = cellfun(@(x) arrayfun(@(y) fullfile(y.folder, y.name), D(x), 'UniformOutput', false), Index, 'UniformOutput', false);
            Data = cell(length(FileList), 1);
            for i = 1:length(Data)
                Data{i} = multi2PEx(FileList{i});
            end
            obj.Data = Data;
            PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
            [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x.SampleSolvent)), obj.Data), 'descend');
            obj.Data = obj.Data(PolaritySorting);
        end
        function buildRawTable(obj)
            SampleSolvent = cellfun(@(x) repmat({x.SampleSolvent}, height(x.Raw), 1), obj.Data, 'UniformOutput', false);
            SampleSolvent = vertcat(SampleSolvent{:});
            SampleSolvent = table(SampleSolvent);
            RawTables = cellfun(@(x) x.Raw, obj.Data, 'UniformOutput', false);
            RawTables = vertcat(RawTables{:});
            obj.Raw = [SampleSolvent, RawTables];
        end
        function buildResultsTable(obj)
            obj.Results = cellfun(@(x) x.Results, obj.Data, 'UniformOutput', false);
        end
        function saveResults(obj)
            for i = 1:length(obj.Results)
                obj.Data{i}.saveResults();
            end
        end
        function plot(obj)
            for i = 1:length(obj.Results)
                obj.Data{i}.plotTPA();
            end
        end
    end
end