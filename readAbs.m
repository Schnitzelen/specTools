% By Brian Bjarke Jensen (schnitzelen@gmail.com) 26/4-2018

classdef readAbs < handle
    % Class used for reading and containing absorption data
    properties
        AbsoluteFileName
        Title
        Date
        Type
        Solvent
        Concentration
        Compound
        Replicates
        PeakExpectedAbove
        SpectralRangeRelativeLimit
        SpectralRange
        MaxAbsorptionTarget
        AdvisedConcentration
        Info
        Data
    end
    methods
        function obj = readAbs(AbsoluteFileName)
            obj.PeakExpectedAbove = 350;
            obj.SpectralRangeRelativeLimit = 0.05;
            obj.MaxAbsorptionTarget = 0.1;
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.txt', 'Please Select Data to Import');
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            obj.readInfoFromFileName()
            obj.importData()
            obj.correctInstrumentArtifacts()
            obj.estimateSpectralRange()
            obj.estimateOptimalConcentration()
        end
        function readInfoFromFileName(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            try
                Info = strsplit(obj.Title, '_');
                assert(length(Info) == 5);
                Date = Info{1};
                Type = Info{2};
                Solvent = Info{3};
                Concentration = strrep(Info{4}, ',', '.');
                Idx = length(Concentration);
                while Idx > 0
                    if ~isnan(str2double(Concentration(Idx - 1)))
                        break
                    end
                    Idx = Idx - 1;
                end
                Unit = {'M', 'mM', 'uM', 'nM', 'pM'};
                Factor = [10^0, 10^-3, 10^-6, 10^-9, 10^-12];
                Factor = Factor(strcmp(Concentration(Idx:end), Unit));
                Concentration = str2double(Concentration(1:(Idx - 1))) * Factor;
                Compound = Info{5};
            catch
                return
            end
            obj.Date = Date;
            obj.Type = Type;
            obj.Solvent = Solvent;
            obj.Concentration = Concentration;
            obj.Compound = Compound;
        end
        function importData(obj)
            % Get all text in file
            Text = fileread(obj.AbsoluteFileName);
            Text = strsplit(Text, '\r\n').';
            % Separate information
            obj.Replicates = sum(strcmp(Text, 'Data Points'));
            Header = cell(obj.Replicates, 1);
            Peaks = cell(obj.Replicates, 1);
            Data = cell(obj.Replicates, 1);
            i = 1;
            for r = 1:obj.Replicates
                while ~strcmp(Text{i}, 'Peaks')
                    Header{r}{end + 1, 1} = Text{i};
                    i = i + 1;
                end
                while ~strcmp(Text{i}, 'Data Points')
                    Peaks{r}{end + 1, 1} = Text{i};
                    i = i + 1;
                end
                while ~contains(Text{i}, 'Sample:') && i < length(Text)
                    Data{r}{end + 1, 1} = Text{i};
                    i = i + 1;
                end
            end
            % Create header-data array
            obj.Info = cell(obj.Replicates, 1);
            for r = 1:obj.Replicates
                Info = regexp(Header{r}, ':\t', 'split');
                i = 1;
                while length(Info{i}) ~= 1
                    obj.Info{r}.(strrep(Info{i}{1}, ' ', '')) = Info{i}{2};
                    i = i + 1;
                end
                while i <= length(Info)
                    j = i;
                    i = i + 1;
                    while i <= length(Info) && length(Info{i}) ~= 1
                        obj.Info{r}.(strrep(Info{j}{1}, ' ', '')).(strrep(Info{i}{1}, ' ', '')) = Info{i}{2};
                        i = i + 1;
                    end
                end
            end
            % Create peak-data array
            for r = 1:obj.Replicates
                Columns = Peaks{r}{2};
                Columns = strsplit(Columns, '\t');
                Columns = regexp(Columns, ' ', 'split');
                Columns = cellfun(@(x) x{1}, Columns, 'UniformOutput', false);
                Values = Peaks{r}(3:end);
                if isempty(Values)
                    Values = NaN(1, length(Columns));
                else
                    Values = regexp(Values, '\t', 'split');
                    Values = vertcat(Values{:});
                    Values = str2double(Values);
                end
                obj.Info{r}.Peaks = array2table(Values, 'VariableNames', Columns);
            end
            % Create data array
            for r = 1:obj.Replicates
                RawData = Data{r}(3:end);
                RawData = regexp(RawData, '\t', 'split');
                RawData = vertcat(RawData{:});
                RawData = str2double(RawData);
                obj.Info{r}.RawData = array2table(RawData, 'VariableNames', {'Wavelength', 'Absorption'});
            end
            Wavelength = obj.Info{1}.RawData.Wavelength;
            Absorption = cellfun(@(x) x.RawData.Absorption, obj.Info.', 'UniformOutput', false);
            Absorption = horzcat(Absorption{:});
            AbsorptionSD = std(Absorption, [], 2);
            Absorption = mean(Absorption, 2);
            obj.Data = table(Wavelength, Absorption, AbsorptionSD);
            obj.Data = sortrows(obj.Data);
            assert(~isempty(obj.Data), 'No data could be located within file');
        end
        function correctInstrumentArtifacts(obj)
            % Correct offset around 600 nm
%             WavelengthLow = 600;
%             WavelengthHigh = 603;
%             if obj.Data.Wavelength(end) < WavelengthHigh
%                 Index = obj.Data.Wavelength > WavelengthLow;
%                 obj.Data(Index, :) = [];
%             else
%                 XLow = obj.Data.Wavelength(find(obj.Data.Wavelength == WavelengthHigh));
%                 YLow = obj.Data.Absorption(find(obj.Data.Wavelength == WavelengthHigh));
%                 XHigh = obj.Data.Wavelength(find(obj.Data.Wavelength == WavelengthHigh + 2));
%                 YHigh = obj.Data.Absorption(find(obj.Data.Wavelength == WavelengthHigh + 2));
%                 Fit = polyfit([XLow, XHigh], [YLow, YHigh], 1);
%                 Offset = ( Fit(1) * obj.Data.Wavelength(find(obj.Data.Wavelength == WavelengthLow)) + Fit(2) ) - obj.Data.Absorption(find(obj.Data.Wavelength == WavelengthLow));
%                 BelowWavelengthLow = obj.Data.Wavelength <= WavelengthLow;
%                 obj.Data.Absorption(BelowWavelengthLow) = obj.Data.Absorption(BelowWavelengthLow) + Offset;
%                 AboveWavelengthLow = obj.Data.Wavelength > WavelengthLow;
%                 BelowWavelengthHigh = obj.Data.Wavelength < WavelengthHigh;
%                 Index = and(AboveWavelengthLow, BelowWavelengthHigh);
%                 obj.Data.Absorption(Index) = Fit(1) .* obj.Data.Wavelength(Index) + Fit(2);
%             end
            % Correct offset around 380 nm (lamp change)
            OutsideArtefactUpperLimit = 380 + 1;
            OutsideArtefactLowerLimit = strsplit(obj.Info{1}.InstrumentParameters.LampChange, ' ');
            OutsideArtefactLowerLimit = str2double(OutsideArtefactLowerLimit{1});
            OutsideArtefactLowerLimit = OutsideArtefactLowerLimit - 1;
            Wavelength = obj.Data.Wavelength;
            Absorption = obj.Data.Absorption;
            IsAboveArtefact = Wavelength > OutsideArtefactLowerLimit;
            IsBelowArtefact = Wavelength < OutsideArtefactUpperLimit;
            AffectedIdx = and(IsAboveArtefact, IsBelowArtefact);
            if any(AffectedIdx)
                % Choose correction method based on wavelength
                IsInBeginning = OutsideArtefactLowerLimit < min(Wavelength);
                IsInEnd = max(Wavelength) < OutsideArtefactUpperLimit;
                if IsInBeginning
                    PerturbedWavelengthIdx = find(Wavelength < OutsideArtefactUpperLimit);
                    FittingIdx = max(PerturbedWavelengthIdx) + 1 : max(PerturbedWavelengthIdx) + 5;
                elseif IsInEnd
                    PerturbedWavelengthIdx = find(OutsideArtefactLowerLimit < Wavelength);
                    FittingIdx = min(PerturbedWavelengthIdx) - 5 : min(PerturbedWavelengthIdx) - 1;
                else
                    PerturbedWavelengthIdx = find(AffectedIdx);
                    FittingIdx = [min(PerturbedWavelengthIdx) - 1, max(PerturbedWavelengthIdx) + 1];
                end
                % Do linear interpolation to correct
                X = Wavelength(FittingIdx);
                Y = Absorption(FittingIdx);
                Fit = polyfit(X, Y, 1);
                for i = 1:length(PerturbedWavelengthIdx)
                    Absorption(PerturbedWavelengthIdx(i)) = Fit(1) * Wavelength(PerturbedWavelengthIdx(i)) + Fit(2);
                end
            end
            obj.Data.CorrectedAbsorption = Absorption;
        end
        function estimateSpectralRange(obj)
            if ~isempty(obj.Concentration)
                Peak = NaN;
                Min = NaN;
                Max = NaN;
                if obj.Concentration > 0
                    % Calculate normalized corrected absorption
                    Wavelength = obj.Data.Wavelength;
                    Absorption = obj.Data.CorrectedAbsorption;
                    Idx = Wavelength > obj.PeakExpectedAbove;
                    [MaxAbs, MaxIdx] = max(Absorption(Idx));
                    NormalizedAbsorption = Absorption / MaxAbs;
                    obj.Data.NormalizedCorrectedAbsorption = NormalizedAbsorption;
                    % Determine spectral range
                    if MaxAbs > 10 * 0.003 % smallest abs step = 0.003
                        Peak = Wavelength(Idx);
                        Peak = Peak(MaxIdx);
                        MaxIdx = find(Wavelength == Peak);
                        Idx = MaxIdx;
                        while Idx > 0
                            if NormalizedAbsorption(Idx) <= obj.SpectralRangeRelativeLimit
                                Min = Wavelength(Idx);
                                break
                            end
                            Idx = Idx - 1;
                        end
                        Idx = MaxIdx;
                        while Idx <= length(NormalizedAbsorption)
                            if NormalizedAbsorption(Idx) <= obj.SpectralRangeRelativeLimit
                                Max = Wavelength(Idx);
                                break
                            end
                            Idx = Idx + 1;
                        end
                    end
                end
                obj.SpectralRange = table(Min, Peak, Max);
            end
        end
        function estimateOptimalConcentration(obj)
            if ~isempty(obj.Concentration)
                obj.AdvisedConcentration = NaN;
                if obj.Concentration > 0
                    PeakAbsorption = obj.Data.Absorption(obj.Data.Wavelength == obj.SpectralRange.Peak);
                    Factor = obj.MaxAbsorptionTarget / PeakAbsorption;
                    obj.AdvisedConcentration = obj.Concentration * Factor;
                end
            end
        end
        function Fig = plotRawAbsorption(obj)
            Fig = figure;
            hold on
            if obj.Replicates == 1
                plot(obj.Data.Wavelength, obj.Data.Absorption, 'LineWidth', 2);
            else
                errorbar(obj.Data.Wavelength, obj.Data.Absorption, obj.Data.SD, 'LineWidth', 2);
            end
            title(sprintf('%s{Raw Absorption of %s in %s}', '\textbf', obj.Compound, obj.Solvent), 'Interpreter', 'latex');
            xlabel('Wavelength (nm)', 'Interpreter', 'latex');
            ylabel('Absorption (a.u.)', 'Interpreter', 'latex');
            YMax = max(obj.Data.Absorption(obj.Data.Wavelength > obj.PeakExpectedAbove));
            ylim([0, YMax * 1.1]);
            xlim([min(obj.Data.Wavelength), max(obj.Data.Wavelength)]);
            hold off
        end
        function Fig = plotCorrectedAbsorption(obj)
            Fig = figure;
            hold on
            if obj.Replicates == 1
                plot(obj.Data.Wavelength, obj.Data.CorrectedAbsorption, 'LineWidth', 2);
            else
                errorbar(obj.Data.Wavelength, obj.Data.CorrectedAbsorption, obj.Data.SD, 'LineWidth', 2);
            end
            title(sprintf('%s{Corrected Absorption of %s in %s}', '\textbf', obj.Compound, obj.Solvent), 'Interpreter', 'latex');
            xlabel('Wavelength (nm)', 'Interpreter', 'latex');
            ylabel('Absorption (a.u.)', 'Interpreter', 'latex');
            YMax = max(obj.Data.CorrectedAbsorption(obj.Data.Wavelength > obj.PeakExpectedAbove));
            ylim([0, YMax * 1.1]);
            xlim([min(obj.Data.Wavelength), max(obj.Data.Wavelength)]);
            hold off
        end
        function Fig = plotNormalizedCorrectedAbsorption(obj)
            Fig = figure;
            hold on
            if obj.Replicates == 1
                plot(obj.Data.Wavelength, obj.Data.NormalizedCorrectedAbsorption, 'LineWidth', 2);
            else
                errorbar(obj.Data.Wavelength, obj.Data.NormalizedCorrectedAbsorption, obj.Data.SD, 'LineWidth', 2);
            end
            title(sprintf('%s{Normalized Corrected Absorption of %s in %s}', '\textbf', obj.Compound, obj.Solvent), 'Interpreter', 'latex');
            xlabel('Wavelength (nm)', 'Interpreter', 'latex');
            ylabel('Absorption (a.u.)', 'Interpreter', 'latex');
            ylim([0, 1]);
            xlim([min(obj.Data.Wavelength), max(obj.Data.Wavelength)]);
            hold off
        end
    end
end