classdef readFLIM < handle
    properties
        AbsoluteFileName
        Importer
        Title
        Date
        Replicate
        Type
        Solvent
        Concentration
        Compound
        Info
        Results
        Data
    end
    methods
        function obj = readFLIM(AbsoluteFileName, varargin)
            % Ask for file(s), if none is provided
            if ~exist('AbsoluteFileName', 'var') || isempty(AbsoluteFileName)
                [File, Path] = uigetfile('*_FLIM_*', 'Please Select Data To Import', 'MultiSelect', 'on');
                assert(isa(Path, 'char') & ~isempty(File), 'No File Selected!')
                AbsoluteFileName = fullfile(Path, File);
            end
            if isa(AbsoluteFileName, 'char')
                AbsoluteFileName = {AbsoluteFileName};
            end
            % Default arguments
            obj.AbsoluteFileName = AbsoluteFileName;
            % Handle varargin
            assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
            for i = 1:2:length(varargin)
                switch varargin{i}
                    otherwise
                        error('Unknown Argument Passed: %s', varargin{i})
                end
            end
            % If any arguments are not defined by now, prompt user
            %
            % Import and handle data
            obj.readInfoFromFileName()
            obj.importData()
            obj.calculateResults()
        end
        function readInfoFromFileName(obj)
            AbsoluteFileNames = regexp(obj.AbsoluteFileName, '^.+(?=_)', 'match');
            UniqueAbsoluteFileName = unique(vertcat(AbsoluteFileNames{:}));
            assert(length(UniqueAbsoluteFileName) == 1, 'No Single Unique Filename Could Be Inferred From Files!')
            [~, FileName, ~] = fileparts(UniqueAbsoluteFileName{:});
            obj.Title = FileName;
            [obj.Date, obj.Replicate, obj.Type, obj.Solvent, obj.Concentration, obj.Compound] = readInformationFromFileName(obj.Title);
        end
        function importData(obj)
            % Determine importer to use
            [~, ~, Ext] = cellfun(@(x) fileparts(x), obj.AbsoluteFileName, 'UniformOutput', false);
            assert(length(unique(Ext)) == 1, 'Multiple File Types Selected!')
            switch Ext{1}
                case '.asc'
                    obj.Importer = @AscFile;
                otherwise
                    error('No Importer For This Filetype')
            end
            [obj.Data, obj.Info] = obj.Importer(obj.AbsoluteFileName);
        end
        function calculateResults(obj)
            obj.Results = cell2table(cell(1, 14), 'VariableNames', {'MeanPhotons', 'MeanChi', 'MeanA1', 'SDA1', 'MeanT1', 'SDT1', 'MeanA2', 'SDA2', 'MeanT2', 'SDT2', 'MeanA3', 'SDA3', 'MeanT3', 'SDT3'});
            obj.Results{1, :} = {NaN};
            if isfield(obj.Data, 'Photons')
                obj.Results.MeanPhotons = round(mean(obj.Data.Photons, 'all'));
            end
            if isfield(obj.Data, 'Chi')
                obj.Results.MeanChi = round(mean(obj.Data.Chi, 'all'));
            end
            if isfield(obj.Data, 'A1')
                obj.Results.MeanA1 = round(mean(obj.Data.A1, 'all'));
                obj.Results.SDA1 = round(std(obj.Data.A1, [], 'all'));
            end
            if isfield(obj.Data, 'A2')
                obj.Results.MeanA2 = round(mean(obj.Data.A2, 'all'));
                obj.Results.SDA2 = round(std(obj.Data.A2, [], 'all'));
            end
            if isfield(obj.Data, 'A3')
                obj.Results.MeanA3 = round(mean(obj.Data.A3, 'all'));
                obj.Results.SDA3 = round(std(obj.Data.A3, [], 'all'));
            end
            if isfield(obj.Data, 'T1')
                obj.Results.MeanT1 = round(mean(obj.Data.T1, 'all'));
                obj.Results.SDT1 = round(std(obj.Data.T1, [], 'all'));
            end
            if isfield(obj.Data, 'T2')
                obj.Results.MeanT2 = round(mean(obj.Data.T2, 'all'));
                obj.Results.SDT2 = round(std(obj.Data.T2, [], 'all'));
            end
            if isfield(obj.Data, 'T3')
                obj.Results.MeanT3 = round(mean(obj.Data.T3, 'all'));
                obj.Results.SDT3 = round(std(obj.Data.T3, [], 'all'));
            end
        end
    end
end
            
            
            