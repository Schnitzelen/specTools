% By Brian Bjarke Jensen (schnitzelen@gmail.com) 22/11-2018

classdef calc2Pabs < handle
    % Class used for calculating two-photon absorption data
    properties
        TableValuePath
        TableValue
        SampleFileList
        ReferenceFolderPath
        Solvent
        Compound
        OneP
        TwoP
        WavelengthOverlapRange
        QuantumYield
        AllResults
        Result
        DetectorIntensityLimit
        AdvisedSampleConcentration
        TimesAllowedDeviationFromMean
    end
    methods
        function obj = calc2Pabs(SampleFileList)
            obj.TableValuePath = fullfile(getenv('userprofile'), '\Documents\Matlab\SpecTools\');
            obj.ReferenceFolderPath = fileparts(fileparts(fileparts(SampleFileList{1})));
            %obj.ReferenceFolderPath = fullfile(getenv('userprofile'), '\OneDrive - Syddansk Universitet\Samples\Reference Dyes\');
            obj.DetectorIntensityLimit = 64000;
            obj.TimesAllowedDeviationFromMean = 20; % used when removing bad data points
            % Ask for sample folder, if none is provided
            if ~exist('SampleFileList', 'var') || isempty(SampleFileList)
                SampleFileList = uigetfile('*.txt', 'Please Select 2P Absorption Data to Import', 'MultiSelect', 'on');
            end
            obj.SampleFileList = SampleFileList;
            obj.importData();
            obj.determineEmissionWavelengthOverlap();
            %obj.plotEmissionWavelengthOverlap();
            obj.determineEmissionCorrectionFactor();
            obj.lookUpReferenceTPA();
            obj.determineAbsorptionWavelengthOverlap();
            %obj.plotAbsorptionWavelengthOverlap();
            obj.lookUpQuantumYields();
            %obj.plotIndividualDates();
            obj.calculateResult();
            %obj.plotResults();
            obj.estimateOptimalSampleConcentration();
        end
        function importData(obj)
            % Sample 2P
            Dates = regexp(obj.SampleFileList, '\', 'split');
            Dates = vertcat(Dates{:});
            Dates = regexp(Dates(:, end), '_', 'split');
            Dates = vertcat(Dates{:});
            obj.Solvent = Dates{1, 3};
            obj.Compound = Dates{1, 5};
            Dates = Dates(:, 1);
            Index = cellfun(@(x) strcmp(Dates, x), unique(Dates(:, 1)), 'UniformOutput', false);
            assert(nnz(cellfun(@(x) nnz(x), Index)) > 0, 'No Useful 2PA Samples Could Be Located');
            obj.TwoP.Sample = cellfun(@(x) read2Pabs(obj.SampleFileList(x)), Index, 'UniformOutput', false);
            % Sample 1P
            SampleFolder = cellfun(@(x) x.AbsoluteFolderPath, obj.TwoP.Sample, 'UniformOutput', false);
            D = cellfun(@(x) dir(fullfile(x, '*_em_*.ifx')), SampleFolder, 'UniformOutput', false);
            Index = cellfun(@(x, y) contains({x(:).name}.', y.Solvent), D, obj.TwoP.Sample, 'UniformOutput', false);
            assert(nnz(cellfun(@(x) nnz(x), Index)) > 0, 'No Useful 1P Samples Could Be Located');
            obj.OneP.Sample = cellfun(@(x, y) readIfx(fullfile(x(y).folder, x(y).name)), D, Index, 'UniformOutput', false);
            % References 2P
            D = dir(fullfile(obj.ReferenceFolderPath, '**\*_2pa_*.txt'));
            Samples = ismember(arrayfun(@(x) fullfile(x.folder, x.name), D, 'UniformOutput', false), obj.SampleFileList);
            TableValues = regexp(arrayfun(@(x) x.name, dir(fullfile(obj.TableValuePath, 'tpa_reference_*')), 'UniformOutput', false), '_', 'split');
            TableValues = vertcat(TableValues{:});
            TableValueCompounds = cellfun(@(x) x(1:end-4), TableValues(:, 4), 'UniformOutput', false);
            TableValueSolvents = TableValues(:, 3);
            ReferenceInTableValues = cellfun(@(x, y) and(contains({D(:).name}.', x), contains({D(:).name}.', y)), TableValueCompounds, TableValueSolvents, 'UniformOutput', false);
            ReferenceInTableValues = any(horzcat(ReferenceInTableValues{:}), 2);
            ValidReferences = and(ReferenceInTableValues, ~Samples);
            assert(nnz(ValidReferences) > 0, 'No Suitable 2P References Could Be Located');
            D = D(ValidReferences);
            Info = regexp({D(:).name}.', '_', 'split');
            Info = vertcat(Info{:});
            MeasurementDates = cellfun(@(x) x.Date, obj.TwoP.Sample, 'UniformOutput', false);
            SameDate = cellfun(@(x) strcmp(Info(:, 1), x), MeasurementDates, 'UniformOutput', false);
            ReferenceCompounds = unique(Info(:, 5));
            Index = cellfun(@(y) cellfun(@(x) and(y, strcmp(Info(:, 5), x)), ReferenceCompounds, 'UniformOutput', false), SameDate, 'UniformOutput', false);
            Index = vertcat(Index{:});
            assert(nnz(cellfun(@(x) nnz(x), Index)) > 0, 'No Useful References Could Be Located');
            FileLists = cellfun(@(y) arrayfun(@(x) fullfile(x.folder, x.name), D(y), 'UniformOutput', false), Index, 'UniformOutput', false);
            Empty = cellfun(@(x) isempty(x), FileLists);
            obj.TwoP.Reference = cellfun(@(x) read2Pabs(x), FileLists(~Empty), 'UniformOutput', false);
            % References 1P
            ReferenceFolder = cellfun(@(x) x.AbsoluteFolderPath, obj.TwoP.Reference, 'UniformOutput', false);
            D = cellfun(@(x) dir(fullfile(x, '*_em_*.ifx')), ReferenceFolder, 'UniformOutput', false);
            Index = cellfun(@(x, y) contains({x(:).name}.', y.Solvent), D, obj.TwoP.Reference, 'UniformOutput', false);
            cellfun(@(x) assert(nnz(x) > 0), Index);
            obj.OneP.Reference = cellfun(@(x, y) readIfx(fullfile(x(y).folder, x(y).name)), D, Index, 'UniformOutput', false);
        end
        function determineEmissionWavelengthOverlap(obj)
            % Sample
            Date = cellfun(@(x) x.Date, obj.TwoP.Sample, 'UniformOutput', false);
            Solvent = cellfun(@(x) x.Solvent, obj.TwoP.Sample, 'UniformOutput', false);
            Compound = cellfun(@(x) x.Compound, obj.TwoP.Sample, 'UniformOutput', false);
            Low = cellfun(@(x, y) max(x.SpectralRange.Emission.Low, y.SpectralRange.Emission.Low), obj.OneP.Sample, obj.TwoP.Sample);
            High = cellfun(@(x, y) min(x.SpectralRange.Emission.High, y.SpectralRange.Emission.High), obj.OneP.Sample, obj.TwoP.Sample);
            arrayfun(@(x, y) assert(x < y), Low, High);
            obj.WavelengthOverlapRange.Emission.Sample = table(Date, Solvent, Compound, Low, High);
            % References
            Date = cellfun(@(x) x.Date, obj.TwoP.Reference, 'UniformOutput', false);
            Solvent = cellfun(@(x) x.Solvent, obj.TwoP.Reference, 'UniformOutput', false);
            Compound = cellfun(@(x) x.Compound, obj.TwoP.Reference, 'UniformOutput', false);
            Low = cellfun(@(x, y) max(x.SpectralRange.Emission.Low, y.SpectralRange.Emission.Low), obj.OneP.Reference, obj.TwoP.Reference);
            High = cellfun(@(x, y) min(x.SpectralRange.Emission.High, y.SpectralRange.Emission.High), obj.OneP.Reference, obj.TwoP.Reference);
            arrayfun(@(x, y) assert(x < y), Low, High);
            obj.WavelengthOverlapRange.Emission.Reference = table(Date, Solvent, Compound, Low, High);
        end
        function fig = plotEmissionWavelengthOverlap(obj) % old
            fig = figure;
            hold on
            % Reference
            plot(obj.OneP.Reference.Data.EmissionWavelength, obj.OneP.Reference.Data.NormalizedIntensity, '.r', 'LineWidth', 2, 'DisplayName', sprintf('Reference (%s)', obj.TwoP.Reference.Compound{1}));
            plot([obj.WavelengthOverlapRange.Emission.Reference.Low(1), obj.WavelengthOverlapRange.Emission.Reference.Low(1)], [0, 1], '--r', 'DisplayName', '2P Range');
            arrayfun(@(x) plot([x, x], [0, 1], '--r', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Emission.Reference.Low(2:end));
            arrayfun(@(x) plot([x, x], [0, 1], '--r', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Emission.Reference.High);
            % Sample
            plot(obj.OneP.Sample.Data.EmissionWavelength, obj.OneP.Sample.Data.NormalizedIntensity, '.b', 'LineWidth', 2, 'DisplayName', sprintf('Reference (%s)', obj.TwoP.Sample.Compound{1})');
            plot([obj.WavelengthOverlapRange.Emission.Sample.Low(1), obj.WavelengthOverlapRange.Emission.Sample.Low(1)], [0, 1], '--b', 'DisplayName', '2P Range');
            arrayfun(@(x) plot([x, x], [0, 1], '--b', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Emission.Sample.Low(2:end));
            arrayfun(@(x) plot([x, x], [0, 1], '--b', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Emission.Sample.High);
            title('\textbf{Emission}', 'Interpreter', 'latex');
            xlabel('Wavelength [nm]', 'Interpreter', 'latex');
            ylabel('Normalized Intensity [a.u.]', 'Interpreter', 'latex');
            legend({}, 'Interpreter', 'latex');
            hold off
        end
        function determineEmissionCorrectionFactor(obj)
            % Sample full emission
            AboveLowerLimit = cellfun(@(x) x.SpectralRange.Emission.Low <= x.Data.EmissionWavelength, obj.OneP.Sample, 'UniformOutput', false);
            BelowUpperLimit = cellfun(@(x) x.SpectralRange.Emission.High >= x.Data.EmissionWavelength, obj.OneP.Sample, 'UniformOutput', false);
            InRange = cellfun(@(x, y) and(x, y), AboveLowerLimit, BelowUpperLimit, 'UniformOutput', false);
            FullEmission = cellfun(@(x, y) trapz(x.Data.EmissionWavelength(y), x.Data.Intensity(y)), obj.OneP.Sample, InRange, 'UniformOutput', false);
            % Sample partial emission
            AboveLowerLimit = cellfun(@(x, y) x.SpectralRange.Emission.Low <= y.Data.EmissionWavelength, obj.TwoP.Sample, obj.OneP.Sample, 'UniformOutput', false);
            BelowUpperLimit = cellfun(@(x, y) x.SpectralRange.Emission.High >= y.Data.EmissionWavelength, obj.TwoP.Sample, obj.OneP.Sample, 'UniformOutput', false);
            InRange = cellfun(@(x, y) and(x, y), AboveLowerLimit, BelowUpperLimit, 'UniformOutput', false);
            PartialEmission = cellfun(@(x, y) trapz(x.Data.EmissionWavelength(y), x.Data.Intensity(y)), obj.OneP.Sample, InRange, 'UniformOutput', false);
            % Sample correction factor
            obj.WavelengthOverlapRange.Emission.Sample.CorrectionFactor = cellfun(@(x, y) x / y, FullEmission, PartialEmission);
            % Reference full emission
            AboveLowerLimit = cellfun(@(x) x.SpectralRange.Emission.Low <= x.Data.EmissionWavelength, obj.OneP.Reference, 'UniformOutput', false);
            BelowUpperLimit = cellfun(@(x) x.SpectralRange.Emission.High >= x.Data.EmissionWavelength, obj.OneP.Reference, 'UniformOutput', false);
            InRange = cellfun(@(x, y) and(x, y), AboveLowerLimit, BelowUpperLimit, 'UniformOutput', false);
            FullEmission = cellfun(@(x, y) trapz(x.Data.EmissionWavelength(y), x.Data.Intensity(y)), obj.OneP.Reference, InRange, 'UniformOutput', false);
            % Reference partial emission
            AboveLowerLimit = cellfun(@(x, y) x.SpectralRange.Emission.Low <= y.Data.EmissionWavelength, obj.TwoP.Reference, obj.OneP.Reference, 'UniformOutput', false);
            BelowUpperLimit = cellfun(@(x, y) x.SpectralRange.Emission.High >= y.Data.EmissionWavelength, obj.TwoP.Reference, obj.OneP.Reference, 'UniformOutput', false);
            InRange = cellfun(@(x, y) and(x, y), AboveLowerLimit, BelowUpperLimit, 'UniformOutput', false);
            PartialEmission = cellfun(@(x, y) trapz(x.Data.EmissionWavelength(y), x.Data.Intensity(y)), obj.OneP.Reference, InRange, 'UniformOutput', false);
            % Reference correction factor
            obj.WavelengthOverlapRange.Emission.Reference.CorrectionFactor = cellfun(@(x, y) x / y, FullEmission, PartialEmission);
        end
        function lookUpReferenceTPA(obj) % WIP
            Solvent = obj.WavelengthOverlapRange.Emission.Reference.Solvent;
            Compound = obj.WavelengthOverlapRange.Emission.Reference.Compound;
            [~, Index, ~] = unique(strcat(Solvent, Compound));
            Solvent = Solvent(Index);
            Compound = Compound(Index);
            TPA = cell(length(Compound), 1);
            for i = 1:length(Compound)
                try
                    TPA{i} = readtable(fullfile(obj.TableValuePath, strcat('tpa_reference_', Solvent{i}, '_', Compound{i}, '.csv')));
                catch
                    [File, Path, ~] = uigetfile('.csv', sprintf('Please Choose TPA Table Value File for %s in %s', Compound{i}, Solvent{i}), 'MultiSelect', 'on');
                    TPA{i} = readtable(fullfile(Path, File));
                end
            end
            obj.TableValue = table(Solvent, Compound, TPA);
        end
        function determineAbsorptionWavelengthOverlap(obj)
            Date = cellfun(@(x) x.Date, obj.TwoP.Reference, 'UniformOutput', false);
            Solvent = cellfun(@(x) x.Solvent, obj.TwoP.Reference, 'UniformOutput', false);
            Reference = cellfun(@(x) x.Compound, obj.TwoP.Reference, 'UniformOutput', false);
            SameSolvent = cellfun(@(x) strcmp(obj.TableValue.Solvent, x), Solvent, 'UniformOutput', false);
            SameReferenceCompound = cellfun(@(x) strcmp(obj.TableValue.Compound, x), Reference, 'UniformOutput', false);
            Index = cellfun(@(x, y) and(x, y), SameSolvent, SameReferenceCompound, 'UniformOutput', false);
            TableValueLow = cellfun(@(x) min(obj.TableValue.TPA{x}.Wavelength), Index);
            MeasurementLow = cellfun(@(x) x.SpectralRange.Absorption.Low, obj.TwoP.Reference);
            Low = max(TableValueLow, MeasurementLow);
            TableValueHigh = cellfun(@(x) max(obj.TableValue.TPA{x}.Wavelength), Index);
            MeasurementHigh = cellfun(@(x) x.SpectralRange.Absorption.High, obj.TwoP.Reference);
            High = min(TableValueHigh, MeasurementHigh); 
            obj.WavelengthOverlapRange.Absorption = table(Date, Solvent, Reference, Low, High);
        end
        function lookUpQuantumYields(obj)
            % Import table values
            QuantumYieldTableValues = readtable(fullfile(obj.TableValuePath, 'ref_quantum_yield.csv'));
            % Change any '.' to ',' for solvent names
            Index = contains(QuantumYieldTableValues.Solvent, '.');
            QuantumYieldTableValues.Solvent(Index) = strrep(QuantumYieldTableValues.Solvent(Index), '.', ',');
            % Determine unique solvent-reference combinations
            Solvent = cellfun(@(x) x(1).Solvent, obj.TwoP.Reference, 'UniformOutput', false);
            Compound = cellfun(@(x) x(1).Compound, obj.TwoP.Reference, 'UniformOutput', false);
            [~, Index, ~] = unique(strcat(Solvent, Compound));
            Solvent = Solvent(Index);
            Compound = Compound(Index);
            % Look up reference quantum yield
            Index = cellfun(@(x, y) and(strcmp(QuantumYieldTableValues.Solvent, x), strcmp(QuantumYieldTableValues.Abbreviation, y)), Solvent, Compound, 'UniformOutput', false);
            Value = ones(length(Compound), 1);
            Unknown = logical(ones(length(Compound), 1));
            for i = 1:length(Compound)
                if nnz(Index{i}) ~= 1
                    disp('reference quantum yield could not be determined from table values');
                    disp('TIP: check for duplicates or add the reference quantum yield manually for a more swift analysis:');
                    disp(fullfile(obj.TableValuePath, 'ref_quantum_yield.csv'));
                    %Input = input(sprintf('Please enter quantum yield of %s in %s (leave blank if unknown): ', Compound{i}, Solvent{i}));
                    %if isempty(Input)
                    fprintf('%s in %s quantum yield unknown: action potential calculated instead\n', Compound{i}, Solvent{i});
                    %else
                    %Value(i) = Input;
                    %Unknown(i) = true;
                    %end
                else
                    Value(i) = QuantumYieldTableValues.QuantumYield(Index{i});
                    Unknown(i) = false;
                end
            end
            obj.QuantumYield.Reference = table(Solvent, Compound, Value, Unknown);
            % Look up sample
            clearvars Solvent Compound Value QuantumYieldUnknown
            [Solvent, Index, ~] = unique(cellfun(@(x) x.Solvent, obj.TwoP.Sample, 'UniformOutput', false));
            Compound = arrayfun(@(x) obj.TwoP.Sample{x}.Compound, Index, 'UniformOutput', false);
            Index = cellfun(@(x, y) and(strcmp(QuantumYieldTableValues.Solvent, x), strcmp(QuantumYieldTableValues.Abbreviation, y)), Solvent, Compound, 'UniformOutput', false);
            Value = ones(length(Compound), 1);
            Unknown = logical(ones(length(Compound), 1));
            for i = 1:length(Compound)
                if nnz(Index{i}) ~= 1
                    disp('sample quantum yield could not be determined from table values');
                    disp('TIP: check for duplicates or add the reference quantum yield manually for a more swift analysis::');
                    disp(fullfile(obj.TableValuePath, 'ref_quantum_yield.csv'));
                    %Input = input(sprintf('Please enter quantum yield of %s in %s (leave blank if unknown): ', Compound{i}, Solvent{i}));
                    %if isempty(Input)
                        fprintf('%s in %s quantum yield unknown: action potential calculated instead\n', Compound{i}, Solvent{i});
                    %else
                        %Value(i) = Input;
                        %Unknown(i) = false;
                    %end
                else
                    Value(i) = QuantumYieldTableValues.QuantumYield(Index{i});
                    Unknown(i) = false;
                end
            end
            obj.QuantumYield.Sample = table(Solvent, Compound, Value, Unknown);
        end
        function calculateResult(obj)
            % For each reference measurement:
            for i = 1:length(obj.TwoP.Reference)
                % Grab relevant data
                Reference = obj.TwoP.Reference{i};
                ReferenceQuantumYield = obj.QuantumYield.Reference.Value(...
                    and(strcmp(Reference.Solvent, obj.QuantumYield.Reference.Solvent), ...
                    strcmp(Reference.Compound, obj.QuantumYield.Reference.Compound)));
                ReferenceQuantumYieldUnknown = obj.QuantumYield.Reference.Unknown(...
                    and(strcmp(Reference.Solvent, obj.QuantumYield.Reference.Solvent), ...
                    strcmp(Reference.Compound, obj.QuantumYield.Reference.Compound)));
                ReferenceEmissionCorrectionFactor = obj.WavelengthOverlapRange.Emission.Reference.CorrectionFactor(...
                    and(strcmp(Reference.Date, obj.WavelengthOverlapRange.Emission.Reference.Date), ...
                    and(strcmp(Reference.Solvent, obj.WavelengthOverlapRange.Emission.Reference.Solvent), ...
                    strcmp(Reference.Compound, obj.WavelengthOverlapRange.Emission.Reference.Compound))));
                TableValue = obj.TableValue.TPA{and(strcmp(Reference.Solvent, obj.TableValue.Solvent), ...
                    strcmp(Reference.Compound, obj.TableValue.Compound))};
                SameDate = cellfun(@(x) strcmp(Reference.Date, x.Date), obj.TwoP.Sample);
                Sample = obj.TwoP.Sample{SameDate};
                SampleQuantumYield = obj.QuantumYield.Sample.Value(...
                    and(strcmp(Sample.Solvent, obj.QuantumYield.Sample.Solvent), ...
                    strcmp(Sample.Compound, obj.QuantumYield.Sample.Compound)));
                SampleQuantumYieldUnknown = obj.QuantumYield.Sample.Unknown(...
                    and(strcmp(Sample.Solvent, obj.QuantumYield.Sample.Solvent), ...
                    strcmp(Sample.Compound, obj.QuantumYield.Sample.Compound)));
                SampleEmissionCorrectionFactor = obj.WavelengthOverlapRange.Emission.Sample.CorrectionFactor(...
                    and(strcmp(Sample.Date, obj.WavelengthOverlapRange.Emission.Sample.Date), ...
                    and(strcmp(Sample.Solvent, obj.WavelengthOverlapRange.Emission.Sample.Solvent), ...
                    strcmp(Sample.Compound, obj.WavelengthOverlapRange.Emission.Sample.Compound))));
                % Sort reference for bad measurements
                AboveZeroIntegratedEmission = arrayfun(@(x) x > 0, Reference.IntegratedEmission);
                BelowDetectorIntensityLimit = cellfun(@(x) max(x(:, 4)) < obj.DetectorIntensityLimit, Reference.Data);
                KeepIndex = and(AboveZeroIntegratedEmission, BelowDetectorIntensityLimit);
                Reference.purgeData(KeepIndex);
                assert(length(Reference.Data) > 0, 'No useful reference data found');
                % Sort sample for bad measurements
                AboveZeroIntegratedEmission = arrayfun(@(x) x > 0, Sample.IntegratedEmission);
                BelowDetectorIntensityLimit = cellfun(@(x) max(x(:, 4)) < obj.DetectorIntensityLimit, Sample.Data);
                KeepIndex = and(AboveZeroIntegratedEmission, BelowDetectorIntensityLimit);
                Sample.purgeData(KeepIndex);
                %assert(length(Sample.Data) > 0, 'No useful sample data found');
                % Build pairing matrix (relates reference to sample)
                SameReplicate = Reference.Replicate.' == Sample.Replicate;
                SameWavelength = Reference.ExcitationWavelength.' == Sample.ExcitationWavelength;
                SameIntensity = Reference.Intensity.' == Sample.Intensity;
                SameDilution = Reference.Dilution.' == Sample.Dilution;
                PairMatrix = and(SameDilution, and(SameIntensity, and(SameWavelength, SameReplicate)));
                ReferenceIndex = any(PairMatrix, 1);
                %assert(nnz(ReferenceIndex) > 0, 'No Proper References Found');
                SampleIndex = any(PairMatrix, 2);
                %assert(nnz(SampleIndex) > 0, 'No Proper Samples Found');
                if nnz(ReferenceIndex) > 0 && nnz(SampleIndex) > 0
                    % Calculate result
                    ReferenceContribution = ( Reference.IntegratedEmission(ReferenceIndex) .* ReferenceEmissionCorrectionFactor ) ./ ( ReferenceQuantumYield * Reference.Concentration );
                    SampleContribution = ( Sample.IntegratedEmission(SampleIndex) .* SampleEmissionCorrectionFactor ) ./ (SampleQuantumYield * Sample.Concentration );
                    TPA = SampleContribution ./ ReferenceContribution .* arrayfun(@(x) TableValue.TPA(TableValue.Wavelength == x), Sample.ExcitationWavelength(SampleIndex));
                else
                    TPA = [];
                end
                % Build results table
                obj.AllResults{i, 1}.TPA = TPA;
                obj.AllResults{i, 1}.Wavelength = Sample.ExcitationWavelength(SampleIndex);
                obj.AllResults{i, 1}.Reference = Reference.Compound;
                obj.AllResults{i, 1}.Date = Reference.Date;
                obj.AllResults{i, 1}.QuantumYieldUnknown = any([ReferenceQuantumYieldUnknown, SampleQuantumYieldUnknown]);
                obj.AllResults{i, 1}.SampleFileNames = Sample.AbsoluteFileList(SampleIndex);
                obj.AllResults{i, 1}.ReferenceFileNames = Reference.AbsoluteFileList(ReferenceIndex);
            end
            % Sort results according to reference
            ReferenceCompounds = unique(cellfun(@(x) x.Compound, obj.TwoP.Reference, 'UniformOutput', false));
            for i = 1:length(ReferenceCompounds)
                SameCompound = cellfun(@(x) strcmp(x.Reference, ReferenceCompounds{i}), obj.AllResults);
                Wavelength = cellfun(@(x) x.Wavelength, obj.AllResults(SameCompound), 'UniformOutput', false);
                Wavelength = vertcat(Wavelength{:});
                TPA = cellfun(@(x) x.TPA, obj.AllResults(SameCompound), 'UniformOutput', false);
                TPA = vertcat(TPA{:});
                meanTPA = arrayfun(@(x) mean(TPA(Wavelength == x)), unique(Wavelength));
                Distance2Mean = arrayfun(@(x, y) abs( meanTPA(unique(Wavelength) == x) - y ), Wavelength, TPA);
                while max(Distance2Mean) > obj.TimesAllowedDeviationFromMean * mean(Distance2Mean)
                    [~, Index] = max(Distance2Mean);
                    Wavelength(Index) = [];
                    TPA(Index) = [];
                    meanTPA = arrayfun(@(x) mean(TPA(Wavelength == x)), unique(Wavelength));
                    Distance2Mean = arrayfun(@(x, y) abs( meanTPA(unique(Wavelength) == x) - y ), Wavelength, TPA);
                end
                sdTPA = arrayfun(@(x) std(TPA(Wavelength == x)), unique(Wavelength));
                obj.Result{i, 1}.Wavelength = unique(Wavelength);
                obj.Result{i, 1}.Reference = ReferenceCompounds{i};
                obj.Result{i, 1}.QuantumYieldUnknown = any(cellfun(@(x) x.QuantumYieldUnknown, obj.AllResults(SameCompound)));
                obj.Result{i, 1}.meanTPA = meanTPA;
                obj.Result{i, 1}.sdTPA = sdTPA;
%                 if obj.Result{i, 1}.QuantumYieldUnknown
%                     obj.Result{i, 1}.meanAP = meanTPA;
%                     obj.Result{i, 1}.sdAP = sdTPA;
%                 else
%                     obj.Result{i, 1}.meanTPA = meanTPA;
%                     obj.Result{i, 1}.sdTPA = sdTPA;
%                 end
            end
        end
        function estimateOptimalSampleConcentration(obj)
            TargetIntensity = obj.DetectorIntensityLimit * 0.8;
            Concentrations = cellfun(@(x) x.Concentration, obj.TwoP.Sample);
            MaxIntensities = cellfun(@(x) max(cellfun(@(y) max(y(:,4)), x.Data)), obj.TwoP.Sample);
            ConcentrationChangeFactors = TargetIntensity ./ MaxIntensities;
            obj.AdvisedSampleConcentration = mean(Concentrations .* ConcentrationChangeFactors);
        end
        function fig = plotAbsorptionWavelengthOverlap(obj) % old
            fig = figure;
            hold on
            plot(obj.Results.Reference.Wavelength, obj.Results.Reference.TPA, '.r', 'LineWidth', 2, 'DisplayName', sprintf('Reference (%s)', obj.TwoP.Reference.Compound{1}));
            xlabel('Wavelength [nm]', 'Interpreter', 'latex')
%             if obj.QuantumYield.UnknownForSample == false
%                 plot(obj.Results.Sample.Wavelength, obj.Results.Sample.MeanTPA, '.b', 'LineWidth', 2, 'DisplayName', sprintf('Sample (%s)', obj.TwoP.Sample.Compound{1}));
%                 MinIntensity = min([min(obj.Results.Reference.TPA), min(obj.Results.Sample.MeanTPA)]);
%                 MaxIntensity = max([max(obj.Results.Reference.TPA), max(obj.Results.Sample.MeanTPA)]);
%                 plot([obj.WavelengthOverlapRange.Absorption.Low(1), obj.WavelengthOverlapRange.Absorption.Low(1)], [MinIntensity, MaxIntensity], '--k', 'DisplayName', '2P Range');
%                 arrayfun(@(x) plot([x, x], [MinIntensity, MaxIntensity], '--k', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Absorption.Low(2:end));
%                 arrayfun(@(x) plot([x, x], [MinIntensity, MaxIntensity], '--k', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Absorption.High);
%                 ylabel('$\sigma_{2P}$ [GM]', 'Interpreter', 'latex');
%                 title('\textbf{2P Absorption}', 'Interpreter', 'latex');
%             else
%                 plot(obj.Results.Sample.Wavelength, obj.Results.Sample.MeanAP, '.b', 'LineWidth', 2, 'DisplayName', 'Sample');
%                 MinIntensity = min([min(obj.Results.Reference.TPA), min(obj.Results.Sample.MeanAP)]);
%                 MaxIntensity = max([max(obj.Results.Reference.TPA), max(obj.Results.Sample.MeanAP)]);
%                 plot([obj.WavelengthOverlapRange.Absorption.Low(1), obj.WavelengthOverlapRange.Absorption.Low(1)], [MinIntensity, MaxIntensity], '--k', 'DisplayName', '2P Range');
%                 arrayfun(@(x) plot([x, x], [MinIntensity, MaxIntensity], '--k', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Absorption.Low(2:end));
%                 arrayfun(@(x) plot([x, x], [MinIntensity, MaxIntensity], '--k', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Absorption.High);
%                 ylabel('$\phi_{Sample} \sigma_{2P}$ [GM]', 'Interpreter', 'latex');
%                 title('\textbf{2P Action Potential}', 'Interpreter', 'latex');
%             end
            plot(obj.Results.Sample.Wavelength, obj.Results.Sample.MeanTPA, '.b', 'LineWidth', 2, 'DisplayName', sprintf('Sample (%s)', obj.TwoP.Sample.Compound{1}));
            MinIntensity = min([min(obj.Results.Reference.TPA), min(obj.Results.Sample.MeanTPA)]);
            MaxIntensity = max([max(obj.Results.Reference.TPA), max(obj.Results.Sample.MeanTPA)]);
            plot([obj.WavelengthOverlapRange.Absorption.Low(1), obj.WavelengthOverlapRange.Absorption.Low(1)], [MinIntensity, MaxIntensity], '--k', 'DisplayName', '2P Range');
            arrayfun(@(x) plot([x, x], [MinIntensity, MaxIntensity], '--k', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Absorption.Low(2:end));
            arrayfun(@(x) plot([x, x], [MinIntensity, MaxIntensity], '--k', 'HandleVisibility', 'off'), obj.WavelengthOverlapRange.Absorption.High);
            ylabel('$\sigma_{2P}$ [GM]', 'Interpreter', 'latex');
            title('\textbf{2P Absorption}', 'Interpreter', 'latex');
            legend({}, 'Interpreter', 'latex');
            hold off
        end
        function fig = plotResults(obj)
            fig = figure;
            hold on
            Color = colormap(parula(length(obj.Result)));
            xlabel('Wavelength [nm]', 'Interpreter', 'latex');
            title(sprintf('%s{2P Absorption of %s in %s}', '\textbf', obj.Compound, obj.Solvent), 'Interpreter', 'latex');
            if ~any(cellfun(@(x) x.QuantumYieldUnknown, obj.Result))
                ylabel('$\sigma_{2P}$ [GM]', 'Interpreter', 'latex');
                %cellfun(@(x) errorbar(x.Wavelength, x.meanTPA, x.sdTPA, 'LineWidth', 2, 'DisplayName', x.Reference), obj.Result)
            else 
                ylabel('$\phi_{Sample} \sigma_{2P}$ [GM]', 'Interpreter', 'latex');
                %cellfun(@(x) errorbar(x.Wavelength, x.meanAP, x.sdAP, 'LineWidth', 2, 'DisplayName', x.Reference), obj.Result)
            end
            cellfun(@(x) errorbar(x.Wavelength, x.meanTPA, x.sdTPA, 'LineWidth', 2, 'DisplayName', x.Reference), obj.Result);
            legend({}, 'Interpreter', 'latex');
            hold off
        end
        function fig = plotIndividualMeasurements(obj) % old
            fig = figure;
            hold on
            if obj.QuantumYield.UnknownForSample == false
                scatter(obj.Results.AllData.Wavelength, obj.Results.AllData.TPA, 'LineWidth', 2);
            else
                scatter(obj.Results.AllData.Wavelength, obj.Results.AllData.AP, 'LineWidth', 2);
            end
            hold off
        end
        function fig = plotReferenceTableValues(obj) % old
            fig = figure;
            hold on
            plot(obj.Results.Reference.Wavelength, obj.Results.Reference.TPA, 'o-', 'LineWidth', 2)
            title(sprintf('%s%s TPA Table Values}', '\textbf{', obj.TwoP.Reference.Compound{1}), 'Interpreter', 'latex')
            xlabel('Wavelength [nm]', 'Interpreter', 'latex')
            ylabel('$\sigma_{2P}$ [GM]', 'Interpreter', 'latex')
            hold off
        end
        function fig = plotIndividualDates(obj) % old
            Dates = unique(obj.TwoP.Sample.Date);
            Data = cellfun(@(x) obj.TwoP.Sample.Measurement(find(strcmp(obj.TwoP.Sample.Date, x))), Dates, 'UniformOutput', false);
            Color = colormap(parula(length(Dates)));
            fig = figure;
            hold on
            ylim([0, 64000]);
            title('Raw Sample Emission Intensity Measurements', 'Interpreter', 'latex');
            xlabel('Wavelength [nm]', 'Interpreter', 'latex');
            ylabel('Intensity [a.u.]', 'Interpreter', 'latex');
            for i = 1:length(Dates)
                plot(Data{i}{1}(:, 1), Data{i}{1}(:, 4), 'LineWidth', 2, 'Color', Color(i, :), 'DisplayName', Dates{i});
                cellfun(@(x) plot(x(:,1), x(:,4), 'LineWidth', 2, 'Color', Color(i, :), 'HandleVisibility', 'off'), Data{i}(2:end), 'UniformOutput', false);
            end
            legend({});
            hold off
        end
    end
end