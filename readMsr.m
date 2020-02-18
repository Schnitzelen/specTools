% By Brian Bjarke Jensen 11/2-2019

classdef readMsr < handle
    % Class used for reading and containing FLIM-data
    properties
        AbsoluteFileName
        Title
        Date
        Replicate
        Type
        Solvent
        Concentration
        Compound
        Binning
        Data
        Info
        Raw
        Results
    end
    methods
        function obj = readMsr(AbsoluteFileName, Binning)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.msr', 'Please Select Data To Import');
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            if ~exist('Binning', 'var')
                Binning = 'Full';
                %Binning = input('Please Specify Binning:\n');
            end
            obj.Binning = Binning;
            obj.readSampleInformation()
            obj.importData()
            if isa(obj.Binning, 'char') && strcmp(obj.Binning, 'Full')
                obj.calculateLifetimeSimple()
            elseif isa(obj.Binning, 'double')
                obj.calculateLifetimeWithBinning()
            end
            %obj.calculateOverallLifetimeFull()
            %obj.saveResults()
        end
        function readSampleInformation(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            try
                Info = strsplit(obj.Title, '_');
                assert(length(Info) == 5);
                Date = Info{1};
                if contains(Date, '-')
                    Date = strsplit(Date, '-');
                    Replicate = str2double(Date{2});
                    Date = Date{1};
                else
                    Replicate = NaN;
                end
                Type = Info{2};
                Solvent = Info{3};
                Conc = strrep(Info{4}, ',', '.');
                Idx = length(Conc);
                while Idx > 0
                    if ~isnan(str2double(Conc(Idx - 1)))
                        break
                    end
                    Idx = Idx - 1;
                end
                Concentration.Value = str2double(Conc(1:Idx - 1));
                Concentration.Unit = Conc(Idx:end);
                Compound = strrep(Info{5}, ',', '.');
            catch
                return
            end
            obj.Date = Date;
            obj.Replicate = Replicate;
            obj.Type = Type;
            obj.Solvent = Solvent;
            obj.Concentration = Concentration;
            obj.Compound = Compound;
        end
        function importData(obj)
            % Read file using homemade script
            Data = obj.readFile(obj.AbsoluteFileName);
            
            1 == 1;
        end
        function calculateLifetimeSimple(obj)
            
        end
        function calculateLifetimeWithBinning()
            
        end
    end
    methods(Static)
        function Data = readFile(AbsoluteFileName)
            % Read binary data from hdd
            fid = fopen(AbsoluteFileName);
            BinaryData = fread(fid, 'ubit16');
            fclose(fid);
            % Grab data
            %PreDataBinary = BinaryData(1:24)';
            Data = native2unicode(BinaryData(25:end-2628)', 'UTF-8');
            %PostDataIdx = BinaryData(end-2629:end)';
            % Convert data from xml
            
            1 == 1;
        end
    end
end