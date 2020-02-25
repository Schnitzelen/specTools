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
        function obj = readAbs(AbsoluteFileName, PeakExpectedAbove)
            % Ask for peak expect, if none is provided
            if ~exist('PeakExpectedAbove', 'var')
                PeakExpectedAbove = input('Please Specify Above Which Wavelength Peak Is Expected: ');
            end            
            obj.PeakExpectedAbove = PeakExpectedAbove;
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
            % Fetch variables to work on
            Wavelength = obj.Data.Wavelength;
            Absorption = obj.Data.Absorption;
            % Correct discontinuity at 601 nm
            AffectedIdx = Wavelength <= 601;
            if any(AffectedIdx) && length(Absorption) > length(AffectedIdx)
                PerturbedIdx = find(AffectedIdx);
                NonPerturbedAbs = Absorption(max(PerturbedIdx) + 1);
                PerturbedAbs = Absorption(max(PerturbedIdx));
                Offset = NonPerturbedAbs - PerturbedAbs;
                Absorption(PerturbedIdx) = Absorption(PerturbedIdx) + Offset;
%                 % Check correction
%                 plot(Wavelength, obj.Data.Absorption)
%                 hold on
%                 plot(Wavelength, Absorption)
%                 hold off
            end
            % Correct lamp change around 380 nm
            AffectedWavelength.Max = 380 + 1;
            AffectedWavelength.Min = str2double(obj.Info{1}.InstrumentParameters.LampChange(1:end-3)) - 1;
            AffectedIdx = AffectedWavelength.Min < Wavelength & Wavelength <= AffectedWavelength.Max;
            if any(AffectedIdx)
                % Choose correction method based on wavelength
                IsInBeginning = AffectedWavelength.Min < min(Wavelength);
                IsInEnd = max(Wavelength) < AffectedWavelength.Max;
                if IsInBeginning
                    PerturbedIdx = find(Wavelength <= AffectedWavelength.Max);
                    NonPerturbedIdx = max(PerturbedWavelengthIdx) + 1 : max(PerturbedWavelengthIdx) + 5;
                elseif IsInEnd
                    PerturbedIdx = find(AffectedWavelength.Min <= Wavelength);
                    NonPerturbedIdx = min(PerturbedWavelengthIdx) - 5 : min(PerturbedWavelengthIdx) - 1;
                else
                    PerturbedIdx = find(AffectedIdx);
                    NonPerturbedIdx = [min(PerturbedIdx) - 1, max(PerturbedIdx) + 1];
                end
                if IsInBeginning || IsInEnd
                    % Do linear interpolation to add offset
                    PerturbedX = Wavelength([min(PerturbedIdx), max(PerturbedIdx)]);
                    PerturbedY = Absorption([min(PerturbedIdx), max(PerturbedIdx)]);
                    PerturbedFit = polyfit(PerturbedX, PerturbedY, 1);
                    NonPerturbedX = Wavelength(NonPerturbedIdx);
                    NonPerturbedY = Absorption(NonPerturbedIdx);
                    NonPerturbedFit = polyfit(NonPerturbedX, NonPerturbedY, 1);
                    for i = 1:length(PerturbedIdx)
                        PerturbedAbs = PerturbedFit(1) * Wavelength(PerturbedIdx(i)) + PerturbedFit(2);
                        NonPerturbedAbs = NonPerturbedFit(1) * Wavelength(PerturbedIdx(i)) + NonPerturbedFit(2);
                        Offset = NonPerturbedAbs - PerturbedAbs;
                        Absorption(PerturbedIdx(i)) = Absorption(PerturbedIdx(i)) + Offset;
                    end
%                     % Check correction
%                     plot(Wavelength, obj.Data.Absorption)
%                     hold on
%                     plot(PerturbedX, PerturbedFit(1) * PerturbedX + PerturbedFit(2))
%                     plot(NonPerturbedX, NonPerturbedFit(1) * PerturbedX + NonPerturbedFit(2))
%                     plot(Wavelength, Absorption)
%                     hold off
                else
                    % In small increments, everything is a straight line:
                    % Get linear fit for edge above perturbed region
                    AboveArtifactIdx = max(NonPerturbedIdx) : length(Absorption);
                    AboveArtifactWavelength = Wavelength(AboveArtifactIdx);
                    AboveArtifactAbsorption = Absorption(AboveArtifactIdx);
                    SmoothAboveArtifactAbsorption = smooth(AboveArtifactAbsorption);
                    AboveArtifactFit = polyfit(AboveArtifactWavelength(1:3), SmoothAboveArtifactAbsorption(1:3), 1);
                    % Get linear fit for edge below perturbed region
                    BelowArtifactIdx = 1 : min(NonPerturbedIdx);
                    BelowArtifactWavelength = Wavelength(BelowArtifactIdx);
                    BelowArtifactAbsorption = Absorption(BelowArtifactIdx);
                    SmoothBelowArtifactAbsorption = smooth(BelowArtifactAbsorption);
                    BelowArtifactFit = polyfit(BelowArtifactWavelength(end-3:end), SmoothBelowArtifactAbsorption(end-3:end), 1);
                    %scatter(BelowArtifactWavelength, BelowArtifactAbsorption, 'b')
                    %hold on
                    %scatter(AboveArtifactWavelength, AboveArtifactAbsorption, 'b')
                    %ylim([0 0.1]);
                    % Combine fits to correct
                    for i = 1:length(PerturbedIdx)
                        PerturbedWavelength = Wavelength(PerturbedIdx(i));
                        AboveArtifactFitContribution = AboveArtifactFit(1) * PerturbedWavelength + AboveArtifactFit(2);
                        BelowArtifactFitContribution = BelowArtifactFit(1) * PerturbedWavelength + BelowArtifactFit(2);
                        % Using logistic function to calculate fraction of
                        % contribution for each fit
                        Fraction = 1 / ( 1 + exp(- (i - (length(PerturbedIdx) / 2))));
                        % Moving from below-fit towards above-fit
                        CombinedContribution = Fraction * AboveArtifactFitContribution + ( 1 - Fraction ) * BelowArtifactFitContribution;
                        Absorption(PerturbedIdx(i)) = CombinedContribution;
                        %scatter(PerturbedWavelength, TotalContribution, 'g')
                    end
                end
            end
            % Store corrected absorption
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
                    % If max abs appears for more wavelengths, find middle
                    if length(Absorption == MaxAbs) > 1
                        MaxIdx = round(mean(find(Absorption(Idx) == MaxAbs)));
                        MaxWavelength = Wavelength(Idx);
                        MaxWavelength = MaxWavelength(MaxIdx);
                        MaxIdx = find(Wavelength == MaxWavelength);
                    end
                    % Determine spectral range
                    if MaxAbs > 10 * 0.0003 % smallest abs step = 0.0003
                        Peak = Wavelength(MaxIdx);
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
            Compound = strrep(obj.Compound, '%', '\%');
            Solvent = strrep(obj.Solvent, '%', '\%');
            title(sprintf('%s{Raw Absorption of %s in %s}', '\textbf', Compound, Solvent), 'Interpreter', 'latex');
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
            Compound = strrep(obj.Compound, '%', '\%');
            Solvent = strrep(obj.Solvent, '%', '\%');
            title(sprintf('%s{Corrected Absorption of %s in %s}', '\textbf', Compound, Solvent), 'Interpreter', 'latex');
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
            Compound = strrep(obj.Compound, '%', '\%');
            Solvent = strrep(obj.Solvent, '%', '\%');
            title(sprintf('%s{Normalized Corrected Absorption of %s in %s}', '\textbf', Compound, Solvent), 'Interpreter', 'latex');
            xlabel('Wavelength (nm)', 'Interpreter', 'latex');
            ylabel('Absorption (a.u.)', 'Interpreter', 'latex');
            ylim([0, 1]);
            xlim([min(obj.Data.Wavelength), max(obj.Data.Wavelength)]);
            hold off
        end
    end
end