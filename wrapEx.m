% By Brian Bjarke Jensen 16/1-2019

classdef wrapEx < handle
    % Class used for containing and organizing multiple emission data-objects
    properties
        AbsoluteFolderPath
        Results
        Raw
        Data
    end
    methods
        function obj = wrapEx(AbsoluteFolderPath)
            % Ask for folder, if none is provided
            if ~exist('AbsoluteFolderPath', 'var')
                AbsoluteFolderPath = uigetdir(getenv('userprofile'), 'Please Select Folder Containing Emission Data to Import');
            end
            obj.AbsoluteFolderPath = AbsoluteFolderPath;
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
        end
        function importData(obj)
            % Get all ex-files in folder
            D = dir(fullfile(obj.AbsoluteFolderPath, '*_ex_*.ifx'));
            % If more of the same measurement, keep only most recent
            Info = regexp({D.name}.', '_', 'split');
            Info = vertcat(Info{:});
            Solvents = Info(:, 3);
            UniqueSolvents = unique(Solvents);
            Dates = str2double(Info(:, 1));
            RemoveIdx = false(length(D), 1);
            for i = 1:length(UniqueSolvents)
                SolventIdx = strcmp(Solvents, UniqueSolvents(i));
                [MostRecentDate, ~] = max(Dates(SolventIdx));
                DateIdx = MostRecentDate == Dates;
                Idx = and(SolventIdx, ~DateIdx);
                RemoveIdx(Idx) = 1;
            end
            D(RemoveIdx, :) = [];
            % Read files
            obj.Data = arrayfun(@(x) readIfx(fullfile(x.folder, x.name)), D, 'UniformOutput', false);
            % If more than one file, sort according to polarity
            if length(obj.Data) > 1
                PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
                [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x.Solvent)), obj.Data), 'descend');
                obj.Data = obj.Data(PolaritySorting);
            end
        end
        function buildRawTable(obj)
            Solvent = cellfun(@(x) x.Solvent, obj.Data, 'UniformOutput', false).';
            Wavelength = cellfun(@(x) x.Data.ExcitationWavelength, obj.Data, 'UniformOutput', false);
            Wavelength = unique(vertcat(Wavelength{:}));
            Raw = table(Wavelength);
            Intensity = cellfun(@(x) x.Data.Intensity, obj.Data, 'UniformOutput', false);
            [~, Index, ~] = cellfun(@(x) intersect(Wavelength, x.Data.ExcitationWavelength), obj.Data, 'UniformOutput', false);
            Data = cellfun(@(x) zeros(length(Wavelength), 1), Solvent, 'UniformOutput', false);
            for i = 1:length(Solvent)
                Data{i}(Index{i}) = Intensity{i};
                Raw = addvars(Raw, Data{i}, 'NewVariableNames', Solvent{i});
            end
            obj.Raw = Raw;
        end
        function buildResultsTable(obj)
            Solvent = cellfun(@(x) x.Solvent, obj.Data, 'UniformOutput', false);
            PeakExpectedAbove = cellfun(@(x) x.PeakExpectedAbove, obj.Data);
            PeakDetectionLimit = cellfun(@(x) x.SpectralRangeRelativeLimit, obj.Data);
            EmissionWavelength = cellfun(@(x) x.SpectralRange.Excitation.EmissionWavelength, obj.Data);
            SpectralRangeMin = cellfun(@(x) x.SpectralRange.Excitation.Min, obj.Data);
            PeakTop = cellfun(@(x) x.SpectralRange.Excitation.Peak, obj.Data);
            SpectralRangeMax = cellfun(@(x) x.SpectralRange.Excitation.Max, obj.Data);
            obj.Results = table(Solvent, PeakExpectedAbove, PeakDetectionLimit, EmissionWavelength, SpectralRangeMin, PeakTop, SpectralRangeMax);
        end
        function fig = plotResults(obj)
            fig = figure;
            hold on
            Color = colormap(parula(length(obj.Data)));
            Color = arrayfun(@(r, g, b) [r g b], Color(:, 1), Color(:, 2), Color(:, 3), 'UniformOutput', false);
            cellfun(@(x, y) plot(x.Data.ExcitationWavelength, x.Data.CorrectedIntensity, 'Color', y, 'LineWidth', 2, 'DisplayName', x.Solvent), obj.Data, Color);
            legend({}, 'Interpreter', 'latex', 'Location', 'northwest');
            title(sprintf('%s{Excitation of %s}', '\textbf', obj.Data{1}.Compound), 'Interpreter', 'latex');
            xlabel('Wavelength [nm]', 'Interpreter', 'latex');
            ylabel('Intensity [a.u.]', 'Interpreter', 'latex');
            YMax = max(cellfun(@(x) max(x.Data.Intensity(x.Data.ExcitationWavelength > x.PeakExpectedAbove)), obj.Data));
            ylim([0, YMax]);
            XMin = min(cellfun(@(x) min(x.Data.ExcitationWavelength), obj.Data));
            XMax = max(cellfun(@(x) max(x.Data.ExcitationWavelength), obj.Data));
            xlim([XMin, XMax]);
            hold off
        end
    end
end