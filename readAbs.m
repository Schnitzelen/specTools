% By Brian Bjarke Jensen (schnitzelen@gmail.com) 26/4-2018

classdef readAbs < handle
    % Class used for reading and containing absorption data
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
        Replicates
        PeakExpectedAbove
        PeakExpectedBelow
        SpectralRangeThreshold
        SpectralRange
        TargetAbsorptionMax
        AdvisedConcentration
        Info
        Data
    end
    methods
        function obj = readAbs(AbsoluteFileName, varargin)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var') || isempty(AbsoluteFileName)
                [File, Path] = uigetfile('*_abs_*', 'Please Select Data To Import');
                assert(isa(Path, 'char') & isa(File, 'char'), 'No File Selected!')
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            % Set default values
            obj.PeakExpectedAbove = 350;
            obj.PeakExpectedBelow = 800;
            obj.SpectralRangeThreshold = 0.05;
            obj.TargetAbsorptionMax = 0.1;
            % Handle varargin
            assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
            for i = 1:2:length(varargin)
                switch varargin{i}
                    case 'PeakExpectedAbove'
                        obj.PeakExpectedAbove = varargin{i + 1};
                    case 'PeakExpectedBelow'
                        obj.PeakExpectedBelow = varargin{i + 1};
                    case 'SpectralRangeThreshold'
                        obj.SpectralRangeThreshold = varargin{i + 1};
                    case 'TargetAbsorptionMax'
                        obj.TargetAbsorptionMax = varargin{i + 1};
                    otherwise
                        error('Unknown Argument Passed: %s', varargin{i})
                end
            end
            % Import and handle data
            obj.readInfoFromFileName()
            obj.importData()
            %obj.correctInstrumentArtifacts()
            obj.normalizeAbsorption()
            obj.estimateSpectralRange()
            obj.estimateOptimalConcentration()
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
                case '.TXT'
                    obj.Importer = @TxtFile;
                case '.csv'
                    obj.Importer = @CsvFile;
                otherwise
                    error('No Importer For This Filetype')
            end
            [obj.Data, obj.Info] = obj.Importer(obj.AbsoluteFileName);
        end
        function correctInstrumentArtifacts(obj)
            % Maybe also necessary to move plot to 
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
%                     TestAbsorption = Absorption;
%                     TestAbsorption(AffectedIdx) = NaN;
%                     gaussianInterpolation(Wavelength, TestAbsorption, true);
                    % In small increments, everything is a straight line:
                    % Get linear fit for edge above perturbed region
                    AboveArtifactIdx = max(NonPerturbedIdx) : length(Absorption);
                    AboveArtifactWavelength = Wavelength(AboveArtifactIdx);
                    AboveArtifactAbsorption = Absorption(AboveArtifactIdx);
                    SmoothAboveArtifactAbsorption = smooth(AboveArtifactAbsorption);
                    AboveArtifactFitWavelengthRange = [min(AboveArtifactWavelength), min(AboveArtifactWavelength) + 3];
                    AboveArtifactFitWavelengthIdx = find(min(AboveArtifactFitWavelengthRange) <= AboveArtifactWavelength & AboveArtifactWavelength <= max(AboveArtifactFitWavelengthRange));
                    AboveArtifactFit = polyfit(AboveArtifactWavelength(AboveArtifactFitWavelengthIdx), SmoothAboveArtifactAbsorption(AboveArtifactFitWavelengthIdx), 1);
                    % Get linear fit for edge below perturbed region
                    BelowArtifactIdx = 1 : min(NonPerturbedIdx);
                    BelowArtifactWavelength = Wavelength(BelowArtifactIdx);
                    BelowArtifactAbsorption = Absorption(BelowArtifactIdx);
                    SmoothBelowArtifactAbsorption = smooth(BelowArtifactAbsorption);
                    BelowArtifactFitWavelengthRange = [max(BelowArtifactWavelength) - 3, max(BelowArtifactWavelength)];
                    BelowArtifactFitWavelengthIdx = find(min(BelowArtifactFitWavelengthRange) <= BelowArtifactWavelength & BelowArtifactWavelength <= max(BelowArtifactFitWavelengthRange));
                    BelowArtifactFit = polyfit(BelowArtifactWavelength(BelowArtifactFitWavelengthIdx), SmoothBelowArtifactAbsorption(BelowArtifactFitWavelengthIdx), 1);
%                     scatter(BelowArtifactWavelength, BelowArtifactAbsorption, 'b')
%                     hold on
%                     scatter(AboveArtifactWavelength, AboveArtifactAbsorption, 'b')
%                     ylim([0 0.1]);
                    % Combine fits to correct
%                     for i = 1:length(PerturbedIdx)
%                         PerturbedWavelength = Wavelength(PerturbedIdx(i));
%                         AboveArtifactFitContribution = AboveArtifactFit(1) * PerturbedWavelength + AboveArtifactFit(2);
%                         BelowArtifactFitContribution = BelowArtifactFit(1) * PerturbedWavelength + BelowArtifactFit(2);
%                         % Using logistic function to calculate fraction of
%                         % contribution for each fit
%                         Steepness = 0.25;
%                         Fraction = 1 / ( 1 + exp(- Steepness * (i - (length(PerturbedIdx) / 2))));
%                         % Moving from below-fit towards above-fit
%                         CombinedContribution = Fraction * AboveArtifactFitContribution + ( 1 - Fraction ) * BelowArtifactFitContribution;
%                         Absorption(PerturbedIdx(i)) = CombinedContribution;
%                         %scatter(PerturbedWavelength, CombinedContribution, 'g')
%                     end
                end
            end
            % Store corrected absorption
            obj.Data.CorrectedAbsorption = Absorption;
        end
        function normalizeAbsorption(obj)
            obj.Data.NormalizedAbsorption = obj.Data.Absorption / max(obj.Data.Absorption);
        end
        function estimateSpectralRange(obj)
            if isempty(obj.Concentration) || obj.Concentration.Value == 0
                return
            end
            [Low, Peak, High] = determineSpectralRange(obj.Data.Wavelength, obj.Data.Absorption, 'Threshold', obj.SpectralRangeThreshold, 'PeakExpectedAbove', obj.PeakExpectedAbove);
            obj.SpectralRange.Min = Low;
            obj.SpectralRange.Peak = Peak;
            obj.SpectralRange.Max = High;
        end
        function estimateOptimalConcentration(obj)
            if isempty(obj.Concentration) || obj.Concentration.Value == 0
                obj.AdvisedConcentration = NaN;
                return
            end
            PeakAbsorption = obj.Data.Absorption(obj.Data.Wavelength == obj.SpectralRange.Peak);
            Factor = obj.TargetAbsorptionMax / PeakAbsorption;
            obj.AdvisedConcentration.Value = obj.Concentration.Value * Factor;
            obj.AdvisedConcentration.Unit = obj.Concentration.Unit;
        end
%         function Fig = plotRawAbsorption(obj)
%             Fig = figure;
%             hold on
%             if obj.Replicates == 1
%                 plot(obj.Data.Wavelength, obj.Data.Absorption, 'LineWidth', 2);
%             else
%                 errorbar(obj.Data.Wavelength, obj.Data.Absorption, obj.Data.SD, 'LineWidth', 2);
%             end
%             Compound = strrep(obj.Compound, '%', '\%');
%             Solvent = strrep(obj.Solvent, '%', '\%');
%             title(sprintf('%s{Raw Absorption of %s in %s}', '\textbf', Compound, Solvent), 'Interpreter', 'latex');
%             xlabel('Wavelength (nm)', 'Interpreter', 'latex');
%             ylabel('Absorption (a.u.)', 'Interpreter', 'latex');
%             YMax = max(obj.Data.Absorption(obj.Data.Wavelength > obj.PeakExpectedAbove));
%             ylim([0, YMax * 1.1]);
%             xlim([min(obj.Data.Wavelength), max(obj.Data.Wavelength)]);
%             hold off
%         end
%         function Fig = plotCorrectedAbsorption(obj)
%             Fig = figure;
%             hold on
%             if obj.Replicates == 1
%                 plot(obj.Data.Wavelength, obj.Data.CorrectedAbsorption, 'LineWidth', 2);
%             else
%                 errorbar(obj.Data.Wavelength, obj.Data.CorrectedAbsorption, obj.Data.SD, 'LineWidth', 2);
%             end
%             Compound = strrep(obj.Compound, '%', '\%');
%             Solvent = strrep(obj.Solvent, '%', '\%');
%             title(sprintf('%s{Corrected Absorption of %s in %s}', '\textbf', Compound, Solvent), 'Interpreter', 'latex');
%             xlabel('Wavelength (nm)', 'Interpreter', 'latex');
%             ylabel('Absorption (a.u.)', 'Interpreter', 'latex');
%             YMax = max(obj.Data.CorrectedAbsorption(obj.Data.Wavelength > obj.PeakExpectedAbove));
%             ylim([0, YMax * 1.1]);
%             xlim([min(obj.Data.Wavelength), max(obj.Data.Wavelength)]);
%             hold off
%         end
%         function Fig = plotNormalizedCorrectedAbsorption(obj)
%             Fig = figure;
%             hold on
%             if obj.Replicates == 1
%                 plot(obj.Data.Wavelength, obj.Data.NormalizedCorrectedAbsorption, 'LineWidth', 2);
%             else
%                 errorbar(obj.Data.Wavelength, obj.Data.NormalizedCorrectedAbsorption, obj.Data.SD, 'LineWidth', 2);
%             end
%             Compound = strrep(obj.Compound, '%', '\%');
%             Solvent = strrep(obj.Solvent, '%', '\%');
%             title(sprintf('%s{Normalized Corrected Absorption of %s in %s}', '\textbf', Compound, Solvent), 'Interpreter', 'latex');
%             xlabel('Wavelength (nm)', 'Interpreter', 'latex');
%             ylabel('Absorption (a.u.)', 'Interpreter', 'latex');
%             ylim([0, 1]);
%             xlim([min(obj.Data.Wavelength), max(obj.Data.Wavelength)]);
%             hold off
%         end
    end
end