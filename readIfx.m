% By Brian Bjarke Jensen on 21/3-2018
% Latest update 25/2-2019

classdef readIfx < handle
    % Class used for reading and containing ifx-file information
    properties
        AbsoluteFileName
        Title
        Date
        Replicate
        Type
        Solvent
        Concentration
        Compound
        PeakExpectedAbove
        SpectralRangeRelativeLimit
        SpectralRange
        Integrated
        Info
        Data
    end
    methods
        function obj = readIfx(AbsoluteFileName, PeakExpectedAbove)
            obj.PeakExpectedAbove = 350;
            obj.SpectralRangeRelativeLimit = 0.05;
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.ifx', 'Please Select Data To Import');
                AbsoluteFileName = strcat(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            % Ask for peak expect, if none is provided
            if ~exist('PeakExpectedAbove', 'var')
                PeakExpectedAbove = input('Please Specify Above Which Wavelength Peak Is Expected: ');
            end            
            obj.PeakExpectedAbove = PeakExpectedAbove;
            obj.readInfoFromFileName()
            obj.importData()
            obj.correctInstrumentArtifacts()
            obj.integrateCorrectedIntensity()
            obj.normalizeCorrectedIntensity()
            obj.estimateSpectralRange()
        end
        function readInfoFromFileName(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            [obj.Date, obj.Replicate, obj.Type, obj.Solvent, obj.Concentration.Value, obj.Compound] = readInformationFromFileName(obj.Title);
        end
        function importData(obj)
            % Read file
            File = importdata(obj.AbsoluteFileName);
            % Create Info-struct from header
            Header = regexp(File.textdata(1:end-1), '=', 'split');
            Header = vertcat(Header{:});
            Header(:, 1) = regexprep(Header(:, 1), ' ', '');
            for i = 1:length(Header)
                Key = Header{i, 1};
                Value = Header{i, 2};
                ValueHasCells = contains(Value, ',');
                ValueHasLetters = isnan(str2double(Value));
                if ValueHasCells && ~any(strcmp(Key, {'Title', 'DetectorGains'}))
                    ValueIsStruct = contains(Value, ':');
                    if ValueIsStruct
                        Value = regexp(Value, ',', 'split').';
                        Value = regexp(Value, ':', 'split');
                        Value = vertcat(Value{:});
                        for j = 1:size(Value, 1)
                            if isnan(str2double(Value{j, 2}))
                                S.(Value{j, 1}) = Value{j, 2};
                            else
                                S.(Value{j, 1}) = str2double(Value{j, 2});
                            end
                        end
                    else
                        S = regexp(Value, ',', 'split');
                    end
                    obj.Info.(Key) = S;
                elseif ValueHasLetters
                    obj.Info.(Header{i, 1}) = Header{i, 2};
                else
                    obj.Info.(Header{i, 1}) = str2double(Header{i, 2});
                end
            end
            % Create data-table
            obj.Data = array2table(File.data, 'VariableNames', obj.Info.Columns);
        end
        function correctInstrumentArtifacts(obj)
            % Determine type of scan
            IsAnisotropyScan = any(strcmp(obj.Data.Properties.VariableNames, 'Anisotropy'));
            if IsAnisotropyScan
                return
            end
            IsEmissionScan = any(strcmp(obj.Data.Properties.VariableNames, 'EmissionWavelength'));
            IsExcitationScan = any(strcmp(obj.Data.Properties.VariableNames, 'ExcitationWavelength'));
            assert(sum([IsEmissionScan, IsExcitationScan]) > 0);
            if IsEmissionScan
                % Determine affected data-points
                AffectedDataPointsHalfWidth = 5;
                Em = obj.Data.EmissionWavelength;
                if IsExcitationScan % Applies for fluorescence scans
                    Ex = obj.Data.ExcitationWavelength;
                else
                    Ex = obj.Info.ExcitationWavelength.fixed;
                end
                Int = obj.Data.Intensity;
                AffectedIdx = Em == Ex;
                AffectedIdx = or(AffectedIdx, Em == Ex * 2); % the second order is not precise...
                AffectedIdx = find(AffectedIdx);
                for i = 1:length(AffectedIdx)
                    % Choose correction method based on wavelength
                    IsCloseToBeginning =  Em(AffectedIdx(i)) <= ( obj.Info.EmissionWavelength.from + AffectedDataPointsHalfWidth );
                    IsCloseToEnd = ( obj.Info.EmissionWavelength.to - AffectedDataPointsHalfWidth ) <= Em(AffectedIdx(i));
                    if IsCloseToBeginning
                        PerturbedWavelengthIdx = [];
                        Idx = AffectedIdx(i);
                        while Idx > 0 && Em(Idx) ~= obj.Info.EmissionWavelength.to
                            PerturbedWavelengthIdx(end + 1) = Idx;
                            Idx = Idx - 1;
                        end
                        FittingIdx = max(PerturbedWavelengthIdx) + 1 : max(PerturbedWavelengthIdx) + AffectedDataPointsHalfWidth;
                    elseif IsCloseToEnd
                        PerturbedWavelengthIdx = [];
                        Idx = AffectedIdx(i);
                        while Idx <= length(Em) && Em(Idx) ~= obj.Info.EmissionWavelength.from
                            PerturbedWavelengthIdx(end + 1) = Idx;
                            Idx = Idx + 1;
                        end
                        FittingIdx = min(PerturbedWavelengthIdx) - AffectedDataPointsHalfWidth : min(PerturbedWavelengthIdx) - 1;
                    else
                        PerturbedWavelengthIdx = AffectedIdx(i) - AffectedDataPointsHalfWidth : AffectedIdx(i) + AffectedDataPointsHalfWidth;
                        FittingIdx = [min(PerturbedWavelengthIdx) - 1, max(PerturbedWavelengthIdx) + 1];
                    end
                    % Do linear interpolation to correct
                    X = Em(FittingIdx);
                    Y = Int(FittingIdx);
                    Fit = polyfit(X, Y, 1);
                    for j = 1:length(PerturbedWavelengthIdx)
                        Int(PerturbedWavelengthIdx(j)) = Fit(1) * Em(PerturbedWavelengthIdx(j)) + Fit(2);
                    end
                end
            elseif IsExcitationScan
                % Determine affected data-points
                AffectedDataPointsHalfWidth = 4;
                Em = obj.Info.EmissionWavelength.fixed;
                Ex = obj.Data.ExcitationWavelength;
                Int = obj.Data.Intensity;
                AffectedIdx = Em == Ex;
                AffectedIdx = or(AffectedIdx, Em == Ex * 2);
                AffectedIdx = find(AffectedIdx);
                for i = 1:length(AffectedIdx)
                    % Choose correction method based on wavelength
                    IsCloseToBeginning =  Ex(AffectedIdx(i)) <= ( obj.Info.ExcitationWavelength.from + AffectedDataPointsHalfWidth );
                    IsCloseToEnd = ( obj.Info.ExcitationWavelength.to - AffectedDataPointsHalfWidth ) <= Ex(AffectedIdx(i));
                    if IsCloseToBeginning
                        PerturbedWavelengthIdx = [];
                        Idx = AffectedIdx(i);
                        while Idx > 0 && Ex(Idx) ~= obj.Info.ExcitationWavelength.to
                            PerturbedWavelengthIdx(end + 1) = Idx;
                            Idx = Idx - 1;
                        end
                        FittingIdx = max(PerturbedWavelengthIdx) + 1 : max(PerturbedWavelengthIdx) + AffectedDataPointsHalfWidth;
                    elseif IsCloseToEnd
                        PerturbedWavelengthIdx = [];
                        Idx = AffectedIdx(i);
                        while Idx < length(Ex) && Ex(Idx) ~= obj.Info.ExcitationWavelength.from
                            PerturbedWavelengthIdx(end + 1) = Idx;
                            Idx = Idx + 1;
                        end
                        FittingIdx = min(PerturbedWavelengthIdx) - AffectedDataPointsHalfWidth : min(PerturbedWavelengthIdx) - 1;
                    else
                        PerturbedWavelengthIdx = AffectedIdx(i) - AffectedDataPointsHalfWidth : AffectedIdx(i) + AffectedDataPointsHalfWidth;
                        FittingIdx = [min(PerturbedWavelengthIdx) - 1, max(PerturbedWavelengthIdx) + 1];
                    end
                    % Do linear interpolation to correct
                    X = Ex(FittingIdx);
                    Y = Int(FittingIdx); 
                    Fit = polyfit(X, Y, 1);
                    for j = 1:length(PerturbedWavelengthIdx)
                        Int(PerturbedWavelengthIdx(j)) = Fit(1) * Ex(PerturbedWavelengthIdx(j)) + Fit(2);
                    end
                end
            end
            obj.Data.CorrectedIntensity = Int;
        end
        function integrateCorrectedIntensity(obj)
            % Determine type of scan
            IsAnisotropyScan = any(strcmp(obj.Data.Properties.VariableNames, 'Anisotropy'));
            if IsAnisotropyScan
                return
            end
            IsEmissionScan = any(strcmp(obj.Data.Properties.VariableNames, 'EmissionWavelength'));
            IsExcitationScan = any(strcmp(obj.Data.Properties.VariableNames, 'ExcitationWavelength'));
            assert(sum([IsEmissionScan, IsExcitationScan]) > 0);
            if IsEmissionScan
                if IsExcitationScan % Applies for fluorescence scans
                    Ex = obj.Info.ExcitationWavelength.from : obj.Info.ExcitationWavelength.step : obj.Info.ExcitationWavelength.to;
                else
                    Ex = obj.Info.ExcitationWavelength.fixed;
                end
                Em = obj.Info.EmissionWavelength.from : obj.Info.EmissionWavelength.step : obj.Info.EmissionWavelength.to;
                Val = NaN(length(Ex), 1);
                for i = 1:length(Ex)
                    Begin = length(Em) * ( i - 1) + 1;
                    End = length(Em) * ( i - 1) + length(Em);
                    Idx = Begin : End;
                    Int = obj.Data.CorrectedIntensity(Idx);
                    Val(i) = trapz(Em, Int);
                end
                obj.Integrated.Emission = table(Ex.', Val, 'VariableNames', {'ExcitationWavelength', 'Value'});
            elseif IsExcitationScan
                Em = obj.Info.EmissionWavelength.fixed;
                Val = trapz(obj.Data.ExcitationWavelength, obj.Data.CorrectedIntensity);
                obj.Integrated.Excitation = table(Em, Val, 'VariableNames', {'EmissionWavelength', 'Value'});
            end
        end
        function normalizeCorrectedIntensity(obj)
            IsAnisotropyScan = any(strcmp(obj.Data.Properties.VariableNames, 'Anisotropy'));
            if IsAnisotropyScan
                return
            end
            obj.Data.NormalizedCorrectedIntensity = obj.Data.CorrectedIntensity / max(obj.Data.CorrectedIntensity);    
        end
        function estimateSpectralRange(obj)
            if ~isempty(obj.Concentration.Value)
                if obj.Concentration.Value.Value == 0
                    return
                end
            end
            % Determine type of scan
            IsAnisotropyScan = any(strcmp(obj.Data.Properties.VariableNames, 'Anisotropy'));
            if IsAnisotropyScan
                return
            end
            IsEmissionScan = any(strcmp(obj.Data.Properties.VariableNames, 'EmissionWavelength'));
            IsExcitationScan = any(strcmp(obj.Data.Properties.VariableNames, 'ExcitationWavelength'));
            assert(sum([IsEmissionScan, IsExcitationScan]) > 0);
            if IsEmissionScan
                if IsExcitationScan % Applies for fluorescence scans
                    Ex = obj.Info.ExcitationWavelength.from : obj.Info.ExcitationWavelength.step : obj.Info.ExcitationWavelength.to;
                else
                    Ex = obj.Info.ExcitationWavelength.fixed;
                end
                Em = obj.Info.EmissionWavelength.from : obj.Info.EmissionWavelength.step : obj.Info.EmissionWavelength.to;
                Peak = NaN(length(Ex), 1);
                Min = NaN(length(Ex), 1);
                Max = NaN(length(Ex), 1);
                for i = 1:length(Ex)
                    Begin = length(Em) * ( i - 1) + 1;
                    End = length(Em) * ( i - 1) + length(Em);
                    Idx = Begin : End;
                    Int = obj.Data.NormalizedCorrectedIntensity(Idx);
                    [MaxInt, MaxIdx] = max(Int(Em > obj.PeakExpectedAbove));
                    if MaxInt > obj.SpectralRangeRelativeLimit
                        P = Em(Em > obj.PeakExpectedAbove);
                        Peak(i) = P(MaxIdx);
                        MaxIdx = find(Em == Peak(i));
                        Idx = MaxIdx;
                        while Idx > 0
                            if Int(Idx) <= obj.SpectralRangeRelativeLimit
                                Min(i) = Em(Idx);
                                break
                            end
                            Idx = Idx - 1;
                        end
                        Idx = MaxIdx;
                        while Idx <= length(Em)
                            if Int(Idx) <= obj.SpectralRangeRelativeLimit
                                Max(i) = Em(Idx);
                                break
                            end
                            Idx = Idx + 1;
                        end
                    end
                end
                obj.SpectralRange.Emission = table(Ex.', Min, Peak, Max, 'VariableNames', {'ExcitationWavelength', 'Min', 'Peak', 'Max'});
            elseif IsExcitationScan
                Em = obj.Info.EmissionWavelength.fixed;
                Ex = obj.Info.ExcitationWavelength.from : obj.Info.ExcitationWavelength.step : obj.Info.ExcitationWavelength.to;
                Peak = NaN(length(Em), 1);
                Min = NaN(length(Em), 1);
                Max = NaN(length(Em), 1);
                Int = obj.Data.NormalizedCorrectedIntensity;
                [MaxInt, MaxIdx] = max(Int(Ex > obj.PeakExpectedAbove));
                if MaxInt > obj.SpectralRangeRelativeLimit
                    P = Ex(Ex > obj.PeakExpectedAbove);
                    Peak = P(MaxIdx);
                    MaxIdx = find(Ex == Peak);
                    Idx = MaxIdx;
                    while Idx > 0
                        if Int(Idx) <= obj.SpectralRangeRelativeLimit
                            Min = Ex(Idx);
                            break
                        end
                        Idx = Idx - 1;
                    end
                    Idx = MaxIdx;
                    while Idx <= length(Ex)
                        if Int(Idx) <= obj.SpectralRangeRelativeLimit
                            Max = Ex(Idx);
                            break
                        end
                        Idx = Idx + 1;
                    end
                end
                obj.SpectralRange.Excitation = table(Em.', Min, Peak, Max, 'VariableNames', {'EmissionWavelength', 'Min', 'Peak', 'Max'});
            end
        end
        function Fig = plotRawIntensity(obj)
            Fig = figure;
            hold on
            % Determine type of scan
            IsEmissionScan = any(strcmp(obj.Data.Properties.VariableNames, 'EmissionWavelength'));
            IsExcitationScan = any(strcmp(obj.Data.Properties.VariableNames, 'ExcitationWavelength'));
            assert(sum([IsEmissionScan, IsExcitationScan]) > 0);
            if IsEmissionScan && IsExcitationScan
                Em = obj.Info.EmissionWavelength.from : obj.Info.EmissionWavelength.step : obj.Info.EmissionWavelength.to;
                Ex = obj.Info.ExcitationWavelength.from : obj.Info.ExcitationWavelength.step : obj.Info.ExcitationWavelength.to;
                Int = reshape(obj.Data.Intensity, [length(Em), length(Ex)]);
                Em = repmat(Em.', 1, length(Ex));
                Ex = repmat(Ex, length(Em), 1);
                surf(Em, Ex, Int)
                xlabel('emission wavelength (nm)', 'Interpreter', 'latex')
                ylabel('excitation wavelength (nm)', 'Interpreter', 'latex')
                zlabel('intensity (a.u.)', 'Interpreter', 'latex')
            elseif IsEmissionScan
                plot(obj.Data.EmissionWavelength, obj.Data.Intensity)
                xlabel('wavelength (nm)', 'Interpreter', 'latex')
                ylabel('intensity (a.u.)', 'Interpreter', 'latex')
            elseif IsExcitationScan
                plot(obj.Data.ExcitationWavelength, obj.Data.Intensity)
                xlabel('wavelength (nm)', 'Interpreter', 'latex')
                ylabel('intensity (a.u.)', 'Interpreter', 'latex')
            end
        end
        function Fig = plotCorrectedIntensity(obj)
            Fig = figure;
            hold on
            % Determine type of scan
            IsEmissionScan = any(strcmp(obj.Data.Properties.VariableNames, 'EmissionWavelength'));
            IsExcitationScan = any(strcmp(obj.Data.Properties.VariableNames, 'ExcitationWavelength'));
            assert(sum([IsEmissionScan, IsExcitationScan]) > 0);
            if IsEmissionScan && IsExcitationScan
                Em = obj.Info.EmissionWavelength.from : obj.Info.EmissionWavelength.step : obj.Info.EmissionWavelength.to;
                Ex = obj.Info.ExcitationWavelength.from : obj.Info.ExcitationWavelength.step : obj.Info.ExcitationWavelength.to;
                Int = reshape(obj.Data.CorrectedIntensity, [length(Em), length(Ex)]);
                Em = repmat(Em.', 1, length(Ex));
                Ex = repmat(Ex, length(Em), 1);
                surf(Em, Ex, Int)
                xlabel('emission wavelength (nm)', 'Interpreter', 'latex')
                ylabel('excitation wavelength (nm)', 'Interpreter', 'latex')
                zlabel('intensity (a.u.)', 'Interpreter', 'latex')
            elseif IsEmissionScan
                plot(obj.Data.EmissionWavelength, obj.Data.CorrectedIntensity)
                xlabel('wavelength (nm)', 'Interpreter', 'latex')
                ylabel('intensity (a.u.)', 'Interpreter', 'latex')
            elseif IsExcitationScan
                plot(obj.Data.ExcitationWavelength, obj.Data.CorrectedIntensity)
                xlabel('wavelength (nm)', 'Interpreter', 'latex')
                ylabel('intensity (a.u.)', 'Interpreter', 'latex')
            end
        end
        function Fig = plotNormalizedCorrectedIntensity(obj)
            Fig = figure;
            hold on
            % Determine type of scan
            IsEmissionScan = any(strcmp(obj.Data.Properties.VariableNames, 'EmissionWavelength'));
            IsExcitationScan = any(strcmp(obj.Data.Properties.VariableNames, 'ExcitationWavelength'));
            assert(sum([IsEmissionScan, IsExcitationScan]) > 0);
            if IsEmissionScan && IsExcitationScan
                Em = obj.Info.EmissionWavelength.from : obj.Info.EmissionWavelength.step : obj.Info.EmissionWavelength.to;
                Ex = obj.Info.ExcitationWavelength.from : obj.Info.ExcitationWavelength.step : obj.Info.ExcitationWavelength.to;
                Int = reshape(obj.Data.NormalizedCorrectedIntensity, [length(Em), length(Ex)]);
                Em = repmat(Em.', 1, length(Ex));
                Ex = repmat(Ex, length(Em), 1);
                surf(Em, Ex, Int)
                xlabel('emission wavelength (nm)', 'Interpreter', 'latex')
                ylabel('excitation wavelength (nm)', 'Interpreter', 'latex')
                zlabel('intensity (a.u.)', 'Interpreter', 'latex')
            elseif IsEmissionScan
                plot(obj.Data.EmissionWavelength, obj.Data.NormalizedCorrectedIntensity)
                xlabel('wavelength (nm)', 'Interpreter', 'latex')
                ylabel('intensity (a.u.)', 'Interpreter', 'latex')
            elseif IsExcitationScan
                plot(obj.Data.ExcitationWavelength, obj.Data.NormalizedCorrectedIntensity)
                xlabel('wavelength (nm)', 'Interpreter', 'latex')
                ylabel('intensity (a.u.)', 'Interpreter', 'latex')
            end
        end
        function PartialEmissionCorrectionFactor = calculatePartialEmissionCorrectionFactor(obj, WavelengthMin, WavelengthMax)
            AboveMinIdx = WavelengthMin <= obj.Data.EmissionWavelength;
            BelowMaxIdx = obj.Data.EmissionWavelength <= WavelengthMax;
            Idx = AboveMinIdx & BelowMaxIdx;
            PartialEmission = trapz(obj.Data.EmissionWavelength(Idx), obj.Data.CorrectedIntensity(Idx));
            FullEmission = obj.Integrated.Emission.Value;
            PartialEmissionCorrectionFactor = FullEmission / PartialEmission;
        end
    end
end
