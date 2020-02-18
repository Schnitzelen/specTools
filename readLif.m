% By Brian Bjarke Jensen 3/9-2019

classdef readLif < handle
    % Class used for reading and containing Leica Image Files-data
    % Dependent on the bioformats-package
    properties
        AbsoluteFilePath
        Title
        Date
        Type
        Compound
        Solvent
        Concentration
        Data
        Info
        Results
    end
    methods
        function obj = readLif(AbsoluteFilePath)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFilePath', 'var')
                [File, Path] = uigetfile('*.lif', 'Please Select Data To Import');
                AbsoluteFilePath = fullfile(Path, File);
            end
            obj.AbsoluteFilePath = AbsoluteFilePath;
            obj.readSampleInformation()
            obj.importData()
            
        end
        function readSampleInformation(obj)
            Info = strsplit(obj.AbsoluteFilePath, '\');
            obj.Title = Info{end};
            try
                Info = strsplit(obj.Title, '_');
                obj.Date = Info{1}(1:6);
                obj.Type = Info{2};
                obj.Solvent = Info{3};
                if contains(Info{4}, {'mM', 'uM', 'nM', 'pM'})
                    Unit = {'mM', 'uM', 'nM', 'pM'};
                    Factor = [10^-3, 10^-6, 10^-9, 10^-12];
                    obj.Concentration.Value = str2double(strrep(Info{4}(1:end-2), ',', '.')) * Factor(strcmp(Info{4}(end-1:end), Unit));
                    obj.Concentration.Unit = 'M';
                elseif contains(Info{4}, {'%mol'})
                    Value = strsplit(Info{4}, '%mol');
                    obj.Concentration.Value = Value{1};
                    obj.Concentration.Unit = '%mol';
                elseif contains(Info{4}, {'mol'})
                    Unit = {'mM', 'uM', 'nM', 'pM'};
                    Factor = [10^-3, 10^-6, 10^-9, 10^-12];
                    obj.Concentration.Value = str2double(strrep(Info{4}(1:end-4), ',', '.')) * Factor(strcmp(Info{4}(end-3:end), Unit));
                    obj.Concentration.Unit = 'mol';
                end
                Compound = strsplit(Info{5}, '.');
                obj.Compound = Compound{1};
            catch
                warning('All sample information could not be read from filename');
            end
        end
        function importData(obj)
            Data = bfopen(obj.AbsoluteFilePath);
            for Image = 1:size(Data, 1)
                % Grab metadata
                Keys = arrayfun(@char, Data{Image,2}.keySet.toArray, 'UniformOutput', false);
                Values = cellfun(@(x) Data{Image,2}.get(x), Keys, 'UniformOutput', false);
                % Shape key-names
                Keys = cellfun(@(x) x(8:end), Keys, 'UniformOutput', false);
                Keys = strrep(Keys, ' ', '');
                Keys = strrep(Keys, '#', '');
                Keys = strrep(Keys, '*', '');
                % Split keys to create substructs
                Keys = regexp(Keys, '\|', 'split');
                % Create substructs in Info
                for i = 1:length(Keys)
                    switch length(Keys{i})
                        case 1
                            obj.Info{Image, 1}.(Keys{i}{1}) = Values{i};
                        case 2
                            obj.Info{Image, 1}.(Keys{i}{1}).(Keys{i}{2}) = Values{i};
                        case 3
                            obj.Info{Image, 1}.(Keys{i}{1}).(Keys{i}{2}).(Keys{i}{3}) = Values{i};
                        case 4
                            obj.Info{Image, 1}.(Keys{i}{1}).(Keys{i}{2}).(Keys{i}{3}).(Keys{i}{4}) = Values{i};
                        case 5
                            obj.Info{Image, 1}.(Keys{i}{1}).(Keys{i}{2}).(Keys{i}{3}).(Keys{i}{4}).(Keys{i}{5}) = Values{i};
                        case 6
                            obj.Info{Image, 1}.(Keys{i}{1}).(Keys{i}{2}).(Keys{i}{3}).(Keys{i}{4}).(Keys{i}{5}).(Keys{i}{6}) = Values{i};
                    end
                end
                % Grab images and info
                Info = cellfun(@(x) strsplit(x, '#'), Data{Image, 1}(:, 2), 'UniformOutput', false);
                Info = vertcat(Info{:});
                Info = regexp(Info, '; ', 'split');
                %Info = Info{:};
                Channels = Data{Image, 1}(:, 1);
                obj.Data{Image, 1} = cellfun(@(x, y) {x, y(2), y(3), y(4)}, Channels, Info, 'UniformOutput', false);
                obj.Data{Image, 1} = vertcat(obj.Data{Image}{:});
            end
        end
    end
end
            
            
            
            
            