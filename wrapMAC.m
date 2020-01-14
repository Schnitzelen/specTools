% By Brian Bjarke Jensen 17/1-2019

classdef wrapMAC < handle
    % Class used for containing and organizing multiple readMAC data-objects
    properties
        AbsoluteFolderPath
        Results
        Raw
        Data
    end
    methods
        function obj = wrapMAC(AbsoluteFolderPath)
            % Ask for folder, if none is provided
            if ~exist('AbsoluteFolderPath', 'var')
                AbsoluteFolderPath = uigetdir(getenv('userprofile'), 'Please Select Folder Containing Molar Attenuation Data Data to Import');
            end
            obj.AbsoluteFolderPath = AbsoluteFolderPath;
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
        end
        function importData(obj)
            % Determine filenames
            D = dir(fullfile(obj.AbsoluteFolderPath, '*_qy_*.TXT'));
            % Split files by solvent and date
            Info = regexp({D.name}.', '_', 'split');
            Info = vertcat(Info{:});
            Dates = Info(:, 1);
            Solvents = Info(:, 3);
            [~, Idx, ~] = unique(cellfun(@(x, y) strcat(x, y), Dates, Solvents, 'UniformOutput', false));
            UniqueDates = Dates(Idx);
            UniqueSolvents = Solvents(Idx);
            FileList = cell(length(UniqueDates), 1);
            for i = 1:length(Dates)
                IsSameDate = strcmp(UniqueDates, Dates{i});
                IsSameSolvent = strcmp(UniqueSolvents, Solvents{i});
                Idx = IsSameDate & IsSameSolvent;
                FileList{Idx}{end + 1, 1} = fullfile(D(i).folder, D(i).name);
            end
            % Import data and calculate results
            obj.Data = cellfun(@(x) readMAC(x), FileList, 'UniformOutput', false);
            % Sort results according to polarity
            if length(obj.Data) > 1
                PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
                [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x.Solvent)), obj.Data), 'descend');
                obj.Data = obj.Data(PolaritySorting);
            end
        end
        function buildRawTable(obj)
            Concentration = cellfun(@(x) x.Raw.Concentration, obj.Data, 'UniformOutput', false);
            Absorption = cellfun(@(x) x.Raw.Absorption, obj.Data, 'UniformOutput', false);
            Solvent = cellfun(@(x) cellfun(@(y) y.Solvent, x.Data, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            Concentration = vertcat(Concentration{:});
            Absorption = vertcat(Absorption{:});
            Solvent = vertcat(Solvent{:});
            obj.Raw = table(Solvent, Concentration, Absorption);
        end
        function buildResultsTable(obj)
            Solvent = cellfun(@(x) x.Results.Solvent, obj.Data, 'UniformOutput', false);
            Wavelength = cellfun(@(x) x.Results.Wavelength, obj.Data);
            MAC = cellfun(@(x) x.Results.MAC, obj.Data);
            obj.Results = table(Solvent, Wavelength, MAC);
        end
        function Fig = plotResults(obj)
            Fig = figure;
            hold on
            Color = colormap(parula(length(obj.Data)));
            Color = arrayfun(@(r, g, b) [r g b], Color(:, 1), Color(:, 2), Color(:, 3), 'UniformOutput', false);
            cellfun(@(x, y) scatter(x.Raw.Concentration, x.Raw.Absorption, 'MarkerEdgeColor', y, 'HandleVisibility', 'off'), obj.Data, Color);
            cellfun(@(x, y) plot(x.Raw.Concentration, x.Fit(1) * x.Raw.Concentration + x.Fit(2), 'Color', y, 'LineWidth', 2, 'DisplayName', x.Solvent), obj.Data, Color);
            legend({}, 'Location', 'NorthWest', 'Interpreter', 'latex');
            title(sprintf('%s{Molar Attenuation of %s}', '\textbf', obj.Data{1}.Compound), 'Interpreter', 'latex');
            xlabel('concentration (M)', 'Interpreter', 'latex');
            ylabel('absorption (a.u.)', 'Interpreter', 'latex');
            hold off
        end
    end
end