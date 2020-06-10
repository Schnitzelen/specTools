function [Data, MetaData] = TxtFile(AbsoluteFileName)
    [~, ~, Type, ~, ~, ~] = readInformationFromFileName(AbsoluteFileName);
    switch Type
        case {'abs', 'qy'}
            % Read file
            FID = fopen(AbsoluteFileName);
            RawText = '';
            while ~feof(FID)
                RawText = horzcat(RawText, fgets(FID));
            end
            fclose(FID);
            % Determine interpreter
            Interpreter = '';
            if contains(RawText, 'U-2010 Spectrophotometer')
                Interpreter = 'U-2010 Spectrophotometer';
            end
            switch Interpreter
                case 'U-2010 Spectrophotometer'
                    % Read info from filename
                    [~, FileName, ~] = fileparts(AbsoluteFileName);
                    [Date, Replicate, Type, Solvent, Concentration, Compound] = readInformationFromFileName(FileName);
                    % Get all text in file
                    Text = fileread(AbsoluteFileName);
                    Text = strsplit(Text, '\r\n').';
                    % Separate information
                    Replicates = sum(strcmp(Text, 'Data Points'));
                    Header = cell(Replicates, 1);
                    Peaks = cell(Replicates, 1);
                    Data = cell(Replicates, 1);
                    i = 1;
                    for r = 1:Replicates
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
                    MetaData = cell(Replicates, 1);
                    for r = 1:Replicates
                        MetaData{r} = regexp(Header{r}, ':\t', 'split');
                        Idx = cellfun(@(x) 1 < length(x), MetaData{r});
                        MetaData{r} = MetaData{r}(Idx);
                        MetaData{r} = vertcat(MetaData{r}{:});
                        MetaData{r} = compileStructFromKeyValuePairs(MetaData{r}(:, 1), MetaData{r}(:, 2));
                    end
                    % Create peak-data array
                    for r = 1:Replicates
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
                        MetaData{r}.Peaks = array2table(Values, 'VariableNames', Columns);
                    end
                    % Create data array
                    for r = 1:Replicates
                        RawData = Data{r}(3:end);
                        RawData = regexp(RawData, '\t', 'split');
                        RawData = vertcat(RawData{:});
                        RawData = str2double(RawData);
                        MetaData{r}.RawData = array2table(RawData, 'VariableNames', {'Wavelength', 'Absorption'});
                    end
                    Wavelength = MetaData{1}.RawData.Wavelength;
                    Absorption = cellfun(@(x) x.RawData.Absorption, MetaData.', 'UniformOutput', false);
                    Absorption = horzcat(Absorption{:});
                    AbsorptionSD = std(Absorption, [], 2);
                    Absorption = mean(Absorption, 2);
                    Data = table(Wavelength, Absorption, AbsorptionSD);
                    Data = sortrows(Data);
                    assert(~isempty(Data), 'No data could be located within file');
                otherwise
                    error('No Interpreter For This Filetype: %s', AbsoluteFileName)
            end
        case '2pa'
            error('No Interpreter For This Filetype: %s', AbsoluteFileName)
        otherwise
            error('No Interpreter For This Filetype: %s', AbsoluteFileName)
    end
end