% By Brian Bjarke Jensen 21/1-2019

classdef wrap2Pabs < handle
    % Class used for containing and organizing multiple solvent analysis of
    % calc2Pabs data-objects
    properties
        AbsoluteFolderPath
        Results
        Raw
        Data
    end
    methods
        function obj = wrap2Pabs(AbsoluteFolderPath)
            % Ask for folder, if none is provided
            if ~exist('AbsoluteFolderPath', 'var')
                AbsoluteFolderPath = uigetdir(getenv('userprofile'), 'Please Select Folder Containing 2P Absorption Data to Import');
            end
            obj.AbsoluteFolderPath = AbsoluteFolderPath;
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
        end
        function importData(obj)
            D = dir(fullfile(obj.AbsoluteFolderPath, 'data\*_2pa_*.txt'));
            Solvents = regexp({D.name}.', '_', 'split');
            Solvents = unique(cellfun(@(x) x{3}, Solvents, 'UniformOutput', false));
            Index = cellfun(@(x) contains({D.name}.', x), Solvents, 'UniformOutput', false);
            FileList = cellfun(@(x) arrayfun(@(y) fullfile(y.folder, y.name), D(x), 'UniformOutput', false), Index, 'UniformOutput', false);
            obj.Data = cellfun(@(x) calc2Pabs(x), FileList, 'UniformOutput', false);
            PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
            [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x.Solvent)), obj.Data), 'descend');
            obj.Data = obj.Data(PolaritySorting);
        end
        function buildRawTable(obj)
            SampleSolvent = cellfun(@(x) cellfun(@(y) arrayfun(@(z) repmat(x.Solvent, length(z), 1), y.Wavelength, 'UniformOutput', false), x.AllResults, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            SampleSolvent = vertcat(SampleSolvent{:});
            SampleSolvent = vertcat(SampleSolvent{:});
            ReferenceCompound = cellfun(@(x) cellfun(@(y) arrayfun(@(z) y.Reference, y.Wavelength, 'UniformOutput', false), x.AllResults, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            ReferenceCompound = vertcat(ReferenceCompound{:});
            ReferenceCompound = vertcat(ReferenceCompound{:});
            QuantumYieldUnknown = cellfun(@(x) cellfun(@(y) arrayfun(@(z) y.QuantumYieldUnknown, y.Wavelength), x.AllResults, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            QuantumYieldUnknown = vertcat(QuantumYieldUnknown{:});
            QuantumYieldUnknown = vertcat(QuantumYieldUnknown{:});
            Wavelength = cellfun(@(x) cellfun(@(y) arrayfun(@(z) z, y.Wavelength), x.AllResults, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            Wavelength = vertcat(Wavelength{:});
            Wavelength = vertcat(Wavelength{:});
            TPA = cellfun(@(x) cellfun(@(y) arrayfun(@(z) round(z, 4, 'significant'), y.TPA), x.AllResults, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            TPA = vertcat(TPA{:});
            TPA = vertcat(TPA{:});
            obj.Raw = table(SampleSolvent, ReferenceCompound, QuantumYieldUnknown, Wavelength, TPA);
        end
        function buildResultsTable(obj)
            SampleSolvent = cellfun(@(x) cellfun(@(y) arrayfun(@(z) repmat(x.Solvent, length(z), 1), y.Wavelength, 'UniformOutput', false), x.Result, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            SampleSolvent = vertcat(SampleSolvent{:});
            SampleSolvent = vertcat(SampleSolvent{:});
            ReferenceCompound = cellfun(@(x) cellfun(@(y) arrayfun(@(z) y.Reference, y.Wavelength, 'UniformOutput', false), x.Result, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            ReferenceCompound = vertcat(ReferenceCompound{:});
            ReferenceCompound = vertcat(ReferenceCompound{:});
            QuantumYieldUnknown = cellfun(@(x) cellfun(@(y) arrayfun(@(z) y.QuantumYieldUnknown, y.Wavelength), x.Result, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            QuantumYieldUnknown = vertcat(QuantumYieldUnknown{:});
            QuantumYieldUnknown = vertcat(QuantumYieldUnknown{:});
            Wavelength = cellfun(@(x) cellfun(@(y) arrayfun(@(z) z, y.Wavelength), x.Result, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            Wavelength = vertcat(Wavelength{:});
            Wavelength = vertcat(Wavelength{:});
            meanTPA = cellfun(@(x) cellfun(@(y) arrayfun(@(z) round(z, 4, 'significant'), y.meanTPA), x.Result, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            meanTPA = vertcat(meanTPA{:});
            meanTPA = vertcat(meanTPA{:});
            sdTPA = cellfun(@(x) cellfun(@(y) arrayfun(@(z) round(z, 4, 'significant'), y.sdTPA), x.Result, 'UniformOutput', false), obj.Data, 'UniformOutput', false);
            sdTPA = vertcat(sdTPA{:});
            sdTPA = vertcat(sdTPA{:});
            obj.Results = table(SampleSolvent, ReferenceCompound, QuantumYieldUnknown, Wavelength, meanTPA, sdTPA);
        end
        function fig = plot(obj)
            fig = figure;
            hold on
            [U, Index] = unique(strcat(obj.Results.SampleSolvent, obj.Results.ReferenceCompound));
            Solvent = obj.Results.SampleSolvent(Index);
            PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
            [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x)), Solvent), 'descend');
            Solvent = Solvent(PolaritySorting);
            Color = colormap(parula(length(U)));
            Color = arrayfun(@(r, g, b) [r g b], Color(:, 1), Color(:, 2), Color(:, 3), 'UniformOutput', false);
            Reference = obj.Results.ReferenceCompound(Index(PolaritySorting));
            Index = cellfun(@(x, y) and(strcmp(obj.Results.SampleSolvent, x), strcmp(obj.Results.ReferenceCompound, y)), obj.Results.SampleSolvent(Index(PolaritySorting)), obj.Results.ReferenceCompound(Index(PolaritySorting)), 'UniformOutput', false);
            X = cellfun(@(x) obj.Results.Wavelength(x), Index, 'UniformOutput', false);
            Y = cellfun(@(x) obj.Results.meanTPA(x), Index, 'UniformOutput', false);
            Err = cellfun(@(x) obj.Results.sdTPA(x), Index, 'UniformOutput', false);
            xlabel('Wavelength [nm]', 'Interpreter', 'latex');
            title(sprintf('%s{2P Absorption of %s}', '\textbf', obj.Data{1}.Compound), 'Interpreter', 'latex');
            if ~any(obj.Results.QuantumYieldUnknown)
                ylabel('$\sigma_{2P}$ [GM]', 'Interpreter', 'latex');
            else
                ylabel('$\phi_{Sample} \sigma_{2P}$ [GM]', 'Interpreter', 'latex');
            end
            cellfun(@(x, y, e, s, r, c) errorbar(x, y, e, 'Color', c, 'LineWidth', 2, 'DisplayName', sprintf('%s(%s)', s, r)), X, Y, Err, Solvent, Reference, Color);
            legend({}, 'Interpreter', 'latex');
            %ylim([0, 200])
            hold off
        end
    end
end