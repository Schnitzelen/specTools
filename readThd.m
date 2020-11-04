classdef readThd < handle
    % Class used for reading and containing thd-lifeitme data
    properties
        AbsoluteFileName
        Title
        Date
        Type
        Solvent
        Concentration
        Compound
        Replicate
        Info
        Data
    end
    methods
        function obj = readThd(AbsoluteFileName)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.thd', 'Please Select Data to Import');
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            obj.readInfoFromFileName()
            obj.importData()
        end
        function readInfoFromFileName(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            [obj.Date, obj.Replicate, obj.Type, obj.Solvent, obj.Concentration, obj.Compound] = readInformationFromFileName(obj.Title);
        end
        function importData(obj)
            % Read binary data from hdd
            fid = fopen(obj.AbsoluteFileName);
            BinaryData = fread(fid);
            fclose(fid);
            % Determine hardware
            Offset = 0;
            SectionLength = 16;
            Idx = (Offset+1):(Offset+1)+(SectionLength-1); % converting to matlab index
            Hardware = BinaryData(Idx);
            Hardware = Hardware(Hardware ~= 0);
            Hardware = native2unicode(Hardware);
            obj.Info.Hardware = Hardware';
            % Determine version
            Offset = 16;
            SectionLength = 6;
            Idx = (Offset+1):(Offset+1)+(SectionLength-1);
            Version = BinaryData(Idx);
            Version = Version(Version ~= 0);
            Version = native2unicode(Version);
            obj.Info.Version = Version';
            
            
            
        end
    end
end