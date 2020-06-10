classdef readEm < handle
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
        PeakExpectedAbove
        SpectralRangeThreshold
        SpectralRange
        IntegratedIntensity
        Info
        Data
    end
    methods
        function obj = readEm(AbsoluteFileName, varargin)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var') || isempty(AbsoluteFileName)
                [File, Path] = uigetfile('*_em_*', 'Please Select Data To Import');
                assert(isa(Path, 'char') & isa(File, 'char'), 'No File Selected!')
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            % Set default values
            obj.PeakExpectedAbove = 350;
            obj.SpectralRangeThreshold = 0.05;
            % Handle varargin
            assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
            for i = 1:2:length(varargin)
                switch varargin{i}
                    case 'PeakExpectedAbove'
                        obj.PeakExpectedAbove = varargin{i + 1};
                    case 'SpectralRangeThreshold'
                        obj.SpectralRangeThreshold = varargin{i + 1};
                    otherwise
                        error('Unknown Argument Passed: %s', varargin{i})
                end
            end
            % Import and handle data
            obj.readInfoFromFileName()
            obj.importData()
            obj.integrateIntensity()
            obj.normalizeIntensity()
            obj.estimateSpectralRange()
        end
        function readInfoFromFileName(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            [obj.Date, obj.Replicate, obj.Type, obj.Solvent, obj.Concentration, obj.Compound] = readInformationFromFileName(obj.Title);
        end
        function importData(obj)
            % Determine importer to use
            [~, ~, Ext] = fileparts(obj.AbsoluteFileName);
            switch Ext
                case '.ifx'
                    obj.Importer = @IfxFile;
                case '.csv'
                    obj.Importer = @CsvFile;
                otherwise
                    error('No Importer For This Filetype')
            end
            [obj.Data, obj.Info] = obj.Importer(obj.AbsoluteFileName);
        end
        function integrateIntensity(obj)
            X = obj.Data.Wavelength;
            Y = obj.Data.Intensity;
            obj.IntegratedIntensity = trapz(X, Y);
        end
        function normalizeIntensity(obj)
            obj.Data.NormalizedIntensity = obj.Data.Intensity / max(obj.Data.Intensity);
        end
        function estimateSpectralRange(obj, varargin)
            % Handle varargin
            assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
            for i = 1:2:length(varargin)
                switch varargin{i}
                    case 'PeakExpectedAbove'
                        obj.PeakExpectedAbove = varargin{i + 1};
                    case 'SpectralRangeThreshold'
                        obj.SpectralRangeThreshold = varargin{i + 1};
                    otherwise
                        error('Unknown Argument Passed: %s', varargin{i})
                end
            end
            % Make sure that fluorophor is present
            if isempty(obj.Concentration) || obj.Concentration.Value == 0
                return
            end
            % Calculate
            [Low, Peak, High] = determineSpectralRange(obj.Data.Wavelength, obj.Data.Intensity, 'Threshold', obj.SpectralRangeThreshold, 'PeakExpectedAbove', obj.PeakExpectedAbove);
            obj.SpectralRange.Min = Low;
            obj.SpectralRange.Peak = Peak;
            obj.SpectralRange.Max = High;
        end
        function CorrectionFactor = calculatePartialEmissionCorrectionFactor(obj, WavelengthMin, WavelengthMax)
            X = obj.Data.Wavelength;
            Y = obj.Data.Intensity;
            assert(min(X) <= WavelengthMin & WavelengthMin <= max(X), 'Lower Wavelength Limit Is Outside Measured Wavelength Range!')
            assert(min(X) <= WavelengthMax & WavelengthMax <= max(X), 'Upper Wavelength Limit Is Outside Measured Wavelength Range!')
            Idx = WavelengthMin <= X & X <= WavelengthMax;
            PartialEmission = trapz(X(Idx), Y(Idx));
            FullEmission = obj.IntegratedIntensity;
            CorrectionFactor = FullEmission / PartialEmission;
        end
    end
end