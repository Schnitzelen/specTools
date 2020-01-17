% By Brian Bjarke Jensen (schnitzelen@gmail.com) on 17/1-2020

classdef readRhe < handle
    % Class used for reading and containing rheometer data files
    properties
        AbsoluteFileName
        Title
        Date
        Type
        Solvent
        Concentration
        Compound
        Info
        Data
    end
    methods
        function obj = readRhe(AbsoluteFileName)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.ifx', 'Please Select Data To Import');
                AbsoluteFileName = strcat(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            obj.readInfoFromFileName()
            obj.importData()
        end
        function readInfoFromFileName(obj)
            1 == 1;
        end
        function importData(obj)
            1 == 1;
        end
    end
end
