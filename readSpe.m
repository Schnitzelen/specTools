% By Brian Bjarke Jensen (schnitzelen@gmail.com) 11/4-2018

classdef readSpe < handle
    % Class used for reading and containing two photon absorption cross
    % section-data
    properties
        AbsFilePath
        SampleName
        ExcitationWavelength
        PowerStep
        ScanNumber
        FileHeader
        Data
    end
    methods (Static)
        % Create object
        function obj = readSpe(AbsFilePath)
            % Ask for file if none is provided
            if ~exist('AbsFilePath', 'var')
                [File, Path] = uigetfile('*.SPE', 'Please Select Data to Import');
                obj.AbsFilePath = strcat(Path, File);
            else
                obj.AbsFilePath = AbsFilePath;
            end
            Title = strsplit(obj.AbsFilePath, '\');
            Title = strsplit(Title{end}, '.');
            Title = strsplit(Title{1}, '-');
            obj.SampleName = Title{1};
            obj.ExcitationWavelength = Title{2};
            obj.PowerStep = Title{3};
            obj.ScanNumber = Title{4};
            obj.ImportData()
        end
    end
    methods
        function ImportData(obj)
            obj.FileHeader = speread_header(obj.AbsFilePath);
            Intensity = speread_frame(obj.FileHeader, 1);
            Intensity = Intensity.';
            WavelengthRange = 111; % nm, valid for SP2150i only...
            WavelengthRangeLow = obj.FileHeader.SpecCenterWlNm - WavelengthRange / 2;
            WavelengthRangeHigh = obj.FileHeader.SpecCenterWlNm + WavelengthRange / 2;
            NumberOfSteps = obj.FileHeader.xdim - 1;
            WavelengthPerStep = WavelengthRange / NumberOfSteps;
            Wavelength = [WavelengthRangeLow : WavelengthPerStep : WavelengthRangeHigh].';
            obj.Data = table(Wavelength, Intensity);
            StuckData = obj.Data.Intensity(1);
            i = 1;
            while obj.Data.Intensity(i) == StuckData && i+1 ~= length(obj.Data.Intensity)
                i = i + 1;
            end
            if i == length(obj.Data.Intensity)
                disp('empty dataset not imported: obj.AbsFilePath');
            else
                obj.Data(1:i, :) = [];
            end
        end
    end
end