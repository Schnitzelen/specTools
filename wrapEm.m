classdef wrapEm < handle
    % Class used for containing and organizing multiple emission data-objects
    properties
        AbsoluteFolderPath
        Solvent
        Results
        Raw
        Data
    end
    methods
        function obj = wrapEm(AbsoluteFolderPath, varargin)
            % Ask for folder, if none is provided
            if ~exist('AbsoluteFolderPath', 'var')
                AbsoluteFolderPath = uigetdir(getenv('userprofile'), 'Please Select Folder Containing Emission Data to Import');
            end
            obj.AbsoluteFolderPath = AbsoluteFolderPath;
            % Prepare arguments
            Solvent = '*';
            % Handle varargin
            assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
            for i = 1:2:length(varargin)
                switch varargin{i}
                    case 'Solvent'
                        Solvent = varargin{i + 1};
                        if isa(Solvent, 'char')
                            Solvent = {Solvent};
                        end
                    otherwise
                        error('Unknown Argument Passed: %s', varargin{i})
                end
            end
            % If any arguments are not defined by now, prompt user
            if isempty(Solvent)
                %Solvent = 'MeOH TCM Tol';
                Solvent = input('Please Specify Solvent(s) (separate multiple solvents by space): ', 's');
                if contains(Solvent, ' ')
                    Solvent = strsplit(Solvent, ' ');
                elseif isa(Solvent, 'char')
                    Solvent = {Solvent};
                end
            end
            assert(~isempty(Solvent) && ~isempty(Solvent{1}), 'No Solvent Specified!')
            obj.Solvent = Solvent;
            % Carry on with work
            obj.importData();
            obj.buildRawTable();
            obj.buildResultsTable();
        end
        function importData(obj)
            % Get all em-files in folder
            FileList = listExperimentFilesInDir('AbsoluteFolder', obj.AbsoluteFolderPath, 'ExperimentType', 'em');
            % If more of the same measurement, keep only most recent of
            % relevant solvent
            [~, Info, ~] = cellfun(@(x) fileparts(x), FileList, 'UniformOutput', false);
            Info = regexp(Info, '_', 'split');
            Info = vertcat(Info{:});
            SampleSolvents = Info(:, 3);
            Dates = str2double(Info(:, 1));
            KeepIdx = false(length(FileList), 1);
            if strcmp(obj.Solvent, '*')
                Solvent = unique(SampleSolvents);
            else
                Solvent = obj.Solvent;
            end
            for i = 1:length(Solvent)
                Idx = find(strcmp(SampleSolvents, Solvent{i}));
                if 1 < length(Idx)
                    [~, MaxDateIdx] = max(Dates(Idx));
                    KeepIdx(Idx(MaxDateIdx)) = true;
                else
                    KeepIdx(Idx) = true;
                end
            end
            FileList = FileList(KeepIdx);
            % Read files
            obj.Data = cellfun(@(x) readEm(x), FileList, 'UniformOutput', false);
            % If more than one file, sort according to polarity
            if length(obj.Data) > 1
                PolarityTable = readtable(fullfile(getenv('userprofile'), '\Documents\MATLAB\SpecTools\ref_polarity.csv'));
                [~, PolaritySorting] = sort(cellfun(@(x) PolarityTable.RelativePolarity(strcmp(PolarityTable.Abbreviation, x.Solvent)), obj.Data), 'descend');
                obj.Data = obj.Data(PolaritySorting);
            end
        end
        function buildRawTable(obj)
            Solvent = cellfun(@(x) x.Solvent, obj.Data, 'UniformOutput', false).';
            Wavelength = cellfun(@(x) x.Data.Wavelength, obj.Data, 'UniformOutput', false);
            Wavelength = unique(vertcat(Wavelength{:}));
            Raw = table(Wavelength);
            Intensity = cellfun(@(x) x.Data.Intensity, obj.Data, 'UniformOutput', false);
            [~, Index, ~] = cellfun(@(x) intersect(Wavelength, x.Data.Wavelength), obj.Data, 'UniformOutput', false);
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
            PeakDetectionLimit = cellfun(@(x) x.SpectralRangeThreshold, obj.Data);
            SpectralRangeMin = cellfun(@(x) x.SpectralRange.Min, obj.Data);
            PeakTop = cellfun(@(x) x.SpectralRange.Peak, obj.Data);
            SpectralRangeMax = cellfun(@(x) x.SpectralRange.Max, obj.Data);
            obj.Results = table(Solvent, PeakExpectedAbove, PeakDetectionLimit, SpectralRangeMin, PeakTop, SpectralRangeMax);
        end
        function fig = plotResults(obj)
            fig = figure;
            hold on
            Color = colormap(parula(length(obj.Data)));
            Color = arrayfun(@(r, g, b) [r g b], Color(:, 1), Color(:, 2), Color(:, 3), 'UniformOutput', false);
            cellfun(@(x, y) plot(x.Data.Wavelength, x.Data.Intensity, 'Color', y, 'LineWidth', 2, 'DisplayName', x.Solvent), obj.Data, Color);
            legend({}, 'Interpreter', 'latex', 'Location', 'northeast');
            %title(sprintf('%s{Emission of %s}', '\textbf', obj.Data{1}.Compound), 'Interpreter', 'latex');
            xlabel('wavelength (nm)', 'Interpreter', 'latex');
            ylabel('intensity (a.u.)', 'Interpreter', 'latex');
            YMax = max(cellfun(@(x) max(x.Data.Intensity(x.Data.Wavelength > x.PeakExpectedAbove)), obj.Data));
            ylim([0, YMax * 1.1]);
            XMin = min(cellfun(@(x) min(x.Data.Wavelength), obj.Data));
            XMax = max(cellfun(@(x) max(x.Data.Wavelength), obj.Data));
            xlim([XMin, XMax]);
            hold off
        end
    end
end