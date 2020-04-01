classdef readAsc < handle
    % Class used for reading and containing FLIM related asc-data
    properties
        AbsoluteFileName
        Title
        Date
        Replicate
        Type
        Solvent
        Concentration
        Compound
        FLIMVariable
        Data
        Results
    end
    methods
        function obj = readAsc(AbsoluteFileName)
            % If no file is provided, ask for one
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.txt', 'Please Select Data to Import');
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            obj.readInfoFromFileName()
            obj.importData()
            obj.calculateResults()
        end
        function readInfoFromFileName(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            [obj.Date, obj.Replicate, obj.Type, obj.Solvent, obj.Concentration, Compound] = readInformationFromFileName(obj.Title);
            if contains(Compound, '_')
                Compound = strsplit(Compound, '_');
                obj.Compound = Compound{1};
                obj.FLIMVariable = Compound{2};
            end
        end
        function importData(obj)
            obj.Data = importdata(obj.AbsoluteFileName);
        end
        function calculateResults(obj)
            Compound = obj.Compound;
            Solvent = obj.Solvent;
            Mean = mean(obj.Data, 'all');
            Mean = round(Mean, 4, 'significant');
            SD = std(obj.Data, [], 'all');
            SD = round(SD, 4, 'significant');
            obj.Results = cell2table({Compound, Solvent, Mean, SD}, 'VariableNames', {'Compound', 'Solvent', 'Mean', 'SD'});
        end
        function Fig = showData(obj)
            Fig = figure;
            hold on
            imshow(obj.Data, [min(min(obj.Data)), max(max(obj.Data))])
            hold off
        end
    end
end
            
            
            