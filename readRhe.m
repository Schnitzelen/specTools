% By Brian Bjarke Jensen (schnitzelen@gmail.com) on 17/1-2020

classdef readRhe < handle
    % Class used for reading and containing rheometer data files
    properties
        AbsoluteFileName
        Title
        Date
        Replicate
        Type
        Solvent
        Concentration
        Compound
        Viscosity
        Info
        Data
    end
    methods
        function obj = readRhe(AbsoluteFileName)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*_rhe_*.xlsx', 'Please Select Data To Import');
                AbsoluteFileName = strcat(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            obj.readInfoFromFileName()
            obj.importData()
            obj.determineStabileViscosity()
            %obj.plotRaw()
        end
        function readInfoFromFileName(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            try
                Info = strsplit(obj.Title, '_');
                %assert(length(Info) == 5);
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
            obj.Data = readtable(obj.AbsoluteFileName);
            % Remove data points with wrong format
            Format = 'dd-MM-yyyy HH:mm:ss';
            CorrectFormatIdx = cellfun(@(x) length(x) == length(Format), obj.Data.DateTime);
            obj.Data = obj.Data(CorrectFormatIdx, :);
            % Convert data points
            obj.Data.DateTime = datetime(obj.Data.DateTime, 'InputFormat', Format);
        end
        function determineStabileViscosity(obj)
            Viscosity = obj.Data.Viscosity;
            % Detect stabile part of measurement
            SD = NaN(length(Viscosity), 1);
            for i = 1:length(Viscosity)
                SD(i) = std(Viscosity(i:end));
            end
            Difference = abs(diff(diff(SD))); % curvature
            Idx = Difference < 0.0001;
            Idx = [false; false; Idx]; % add to indices that were removed by diff
            % Calculate mean viscosity from stabile part
            obj.Viscosity.Value = mean(Viscosity(Idx));
            obj.Viscosity.Unit = 'mPaS';
            obj.Data.StabileIndex = Idx;
        end
        function Fig = plotRaw(obj)
            Fig = figure;
            hold on
            xlabel('time');
            ylabel('viscosity (mPaS)');
            StabileIdx = obj.Data.StabileIndex;
            DateTime = obj.Data.DateTime;
            Viscosity = obj.Data.Viscosity;
            plot(DateTime(StabileIdx), Viscosity(StabileIdx), 'bo');
            plot(DateTime(~StabileIdx), Viscosity(~StabileIdx), 'ro');
            hold off
        end
    end
end
