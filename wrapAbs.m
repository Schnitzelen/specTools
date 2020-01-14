% By Brian Bjarke Jensen 15/1-2019

classdef wrapAbs < handle
    % Class used for containing and organizing multiple absorption data-objects
    properties
        AbsoluteFolderPath
        Results
        Raw
        Data
    end
    methods
        function obj = wrapAbs(AbsoluteFolderPath)
            % Ask for folder, if none is provided
            if ~exist('AbsoluteFolderPath', 'var')
                AbsoluteFolderPath = uigetdir(pwd(), 'Please Select Folder Containing Absorption Data to Import');
            end
            obj.AbsoluteFolderPath = AbsoluteFolderPath;
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
        end
        function importData(obj)
            % Get all abs-files in folder
            D = dir(fullfile(obj.AbsoluteFolderPath, '**', '*_abs_*.TXT'));
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
            obj.Data = arrayfun(@(x) readAbs(fullfile(x.folder, x.name)), D, 'UniformOutput', false);
            % If more than one file, sort according to polarity
            if length(obj.Data) > 1
                PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
                [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x.Solvent)), obj.Data), 'descend');
                obj.Data = obj.Data(PolaritySorting);
            end
        end
        function buildRawTable(obj)
            Solvent = cellfun(@(x) x.Solvent, obj.Data, 'UniformOutput', false);
            Wavelength = cellfun(@(x) x.Data.Wavelength, obj.Data, 'UniformOutput', false);
            Wavelength = unique(vertcat(Wavelength{:}));
            Raw = table(Wavelength);
            Absorption = cellfun(@(x) x.Data.Absorption, obj.Data, 'UniformOutput', false);
            [~, Index, ~] = cellfun(@(x) intersect(Wavelength, x.Data.Wavelength), obj.Data, 'UniformOutput', false);
            Data = cellfun(@(x) zeros(length(Wavelength), 1), Solvent, 'UniformOutput', false);
            for i = 1:length(Solvent)
                Data{i}(Index{i}) = Absorption{i};
                Raw = addvars(Raw, Data{i}, 'NewVariableNames', Solvent{i});
            end
            obj.Raw = Raw;
        end
        function buildResultsTable(obj)
            Solvent = cellfun(@(x) x.Solvent, obj.Data, 'UniformOutput', false);
            PeakExpectedAbove = cellfun(@(x) x.PeakExpectedAbove, obj.Data);
            PeakDetectionLimit = cellfun(@(x) x.SpectralRangeRelativeLimit, obj.Data);
            SpectralRangeMin = cellfun(@(x) x.SpectralRange.Min, obj.Data);
            PeakTop = cellfun(@(x) x.SpectralRange.Peak, obj.Data);
            SpectralRangeMax = cellfun(@(x) x.SpectralRange.Max, obj.Data);
            obj.Results = table(Solvent, PeakExpectedAbove, PeakDetectionLimit, SpectralRangeMin, PeakTop, SpectralRangeMax);
        end
        function Fig = plotResults(obj)
            Fig = figure;
            hold on
            Color = colormap(parula(length(obj.Data)));
            Color = arrayfun(@(r, g, b) [r g b], Color(:, 1), Color(:, 2), Color(:, 3), 'UniformOutput', false);
            cellfun(@(x, y) plot(x.Data.Wavelength, x.Data.Absorption, 'Color', y, 'LineWidth', 2, 'DisplayName', x.Solvent), obj.Data, Color);
            legend({}, 'Interpreter', 'latex', 'Location', 'northwest');
            title(sprintf('%s{Absorption of %s}', '\textbf', obj.Data{1}.Compound), 'Interpreter', 'latex');
            xlabel('Wavelength [nm]', 'Interpreter', 'latex');
            ylabel('Absorption [a.u.]', 'Interpreter', 'latex');
            YMax = max(cellfun(@(x) max(x.Data.Absorption(x.Data.Wavelength > x.PeakExpectedAbove)), obj.Data));
            ylim([0, YMax * 1.1]);
            XMin = min(cellfun(@(x) min(x.Data.Wavelength), obj.Data));
            XMax = max(cellfun(@(x) max(x.Data.Wavelength), obj.Data));
            xlim([XMin, XMax]);
            colormap(parula);
            hold off
        end
    end
end