% By Brian Bjarke Jensen 11/2-2019

classdef readMsr < handle
    % Class used for reading and containing FLIM-data
    properties
        DependentPackages
        AbsoluteFileName
        Title
        Date
        Replicate
        Type
        Solvent
        Concentration
        Compound
        Binning
        NumberOfDecays
        ForceFitOnAllPixels
        Data
        Info
        IntensityImage
        Results
    end
    methods
        function obj = readMsr(AbsoluteFileName, Binning, NumberOfDecays, ForceFitOnAllPixels)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.msr', 'Please Select Data To Import');
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            % Ask for binning, if none is provided
            if ~exist('Binning', 'var')
                Binning = input('Please Specify Binning:\n');
            end
            obj.Binning = Binning;
            % If no number of decays is provided
            if ~exist('NumberOfDecays', 'var')
                NumberOfDecays = NaN;
            end
            obj.NumberOfDecays = NumberOfDecays;
            % If no number of decays is provided
            if ~exist('ForceFitOnAllPixels', 'var')
                ForceFitOnAllPixels = false;
            end
            obj.ForceFitOnAllPixels = ForceFitOnAllPixels;
            % Begin work
            obj.importDependentPackages()
            obj.readSampleInformationFromFileName()
            obj.importData()
            obj.calculateLifetime()
            %obj.saveResults()
        end
        function importDependentPackages(obj)
            obj.DependentPackages = {'bfmatlab'};
            importPackages(obj.DependentPackages);
        end
        function readSampleInformationFromFileName(obj)
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            [obj.Date, obj.Replicate, obj.Type, obj.Solvent, obj.Concentration, obj.Compound] = readInformationFromFileName(obj.Title);
        end
        function importData(obj)
            % Import data
            Data = bfopen(obj.AbsoluteFileName);
            % First row of data is the raw data
            Data = Data(1, :);
            % Get information from hashtable
            [Keys, Values] = getKeysAndValuesFromHashTable(Data{1, 2});
            obj.Info = compileStructFromKeyValuePairs(Keys, Values);
            % Fetch images
            Image = Data{1}(:, 1);
            % Store intensity image
            obj.IntensityImage = sum(cat(3, Image{:}), 3);
            % Fetch timebin numbers
            Info = regexp(Data{1}(:, 2), '; ', 'split');
            TimeBin = cellfun(@(x) strsplit(x{4}, 'Z='), Info, 'UniformOutput', false);
            TimeBin = cellfun(@(x) strsplit(x{2}, '/'), TimeBin, 'UniformOutput', false);
            TimeBin = cellfun(@(x) str2double(x{1}), TimeBin);
            % Calculate timebin time
            TotalTimeBinDuration = obj.Info.Lengths.toArray;
            TotalTimeBinDuration = TotalTimeBinDuration(1); % Seconds
            TimeStep = TotalTimeBinDuration / ( length(TimeBin) - 1 );
            Time = (TimeBin - 1) * TimeStep * 10^9; % Converting to nanoseconds
            % Fetch all photons from each timebin
            Photons = cellfun(@(x) sum(x, 'all'), Image);
            % Store relevant data
            obj.Data = table(TimeBin, Image, Time, Photons);
        end
        function calculateLifetime(obj)
            % Setup variables
            if isa(obj.Binning, 'char') && strcmp(obj.Binning, 'Full')
                Results{1, 1} = NaN;
            elseif isa(obj.Binning, 'double')
                Size = size(obj.Data.Image{1});
                Background = NaN(Size);
                Amplitude1 = NaN(Size);
                Lifetime1 = NaN(Size);
                Stretch1 = NaN(Size);
                Amplitude2 = NaN(Size);
                Lifetime2 = NaN(Size);
                Stretch2 = NaN(Size);
                Amplitude3 = NaN(Size);
                Lifetime3 = NaN(Size);
                Stretch3 = NaN(Size);
            end
            % Setup for initial fit
            DecayIdx = determineDecayIndex(obj.Data.Photons);
            if sum(DecayIdx) < 3
                warning('No Decay Detected in Image %s', obj.Title);
                obj.Results = NaN;
                return
            end
            T = obj.Data.Time(DecayIdx);
            P = obj.Data.Photons(DecayIdx);
            if isnan(obj.NumberOfDecays)
                NOD = determineNumberOfExponentialDecays(T, P);
            else
                NOD = obj.NumberOfDecays;
            end
            % Do initial (binned) fit
            InitialGuess = NaN;
            InitialFit = calculateExponentialDecay(T, P, NOD, InitialGuess);
            if isa(obj.Binning, 'char') && strcmp(obj.Binning, 'Full')
                % If full binning, results are already calculated
                Fit = calculateExponentialDecayStretch(T, P, InitialFit);
                Results{1, 1} = Fit;
            elseif isa(obj.Binning, 'double')
                % Prepare variables for fitting with parallel loop
                [PixelY, PixelX] = size(obj.Data.Image{1});
                %CoordinateX = repmat([1:PixelX]', PixelY, 1);
                %CoordinateY = arrayfun(@(x) repmat(x, PixelX, 1), [1:PixelY]', 'UniformOutput', false);
                %CoordinateY = vertcat(CoordinateY{:});
                BinnedImage = cellfun(@(x) binImage(x, obj.Binning), obj.Data.Image, 'UniformOutput', false);
                BinnedImage = cat(3, BinnedImage{:});
                Photons = squeeze(sum(BinnedImage, [1, 2]));
                DecayIdx = determineDecayIndex(Photons);
                Time = obj.Data.Time;
                Results = cell(PixelY, PixelX);
                if isnan(obj.NumberOfDecays)
                    NOD = determineNumberOfExponentialDecays(Time(DecayIdx), Photons(DecayIdx));
                else
                    NOD = obj.NumberOfDecays;
                end
                % Do fitting on each pixel
                parfor Y = 1:PixelY
                    RawLine = BinnedImage(Y, :, :);
                    FitLine = cell(1, PixelX);
                    for X = 1:PixelX
                        %Y = CoordinateY(j);
                        %X = CoordinateX(j);
                        Photons = squeeze(RawLine(1, X, :));
                        DecayIdx = determineDecayIndex(Photons);
                        if sum(DecayIdx) > 3
                            Fit = calculateExponentialDecay(Time(DecayIdx), Photons(DecayIdx), NOD, InitialFit);
                            Fit = calculateExponentialDecayStretch(Time(DecayIdx), Photons(DecayIdx), Fit);
                            FitLine{X} = Fit;
                        else
                            FitLine{X} = NaN;
                        end
                    end
                    Results(Y, :) = FitLine;
                end
                % Reshape results
                Results = reshape(Results, PixelY, PixelX)'; % filled out column-wise -> transmute output
            end
            
            % Distribute results
            for Y = 1:size(Results, 1)
                for X = 1:size(Results, 2)
                    if isa(Results{Y, X}, 'struct')
                        Background(Y, X) = Results{Y, X}.B;
                        Amplitude1(Y, X) = Results{Y, X}.A1;
                        Lifetime1(Y, X) = Results{Y, X}.T1;
                        Stretch1(Y, X) = Results{Y, X}.H1;
                        Amplitude2(Y, X) = Results{Y, X}.A2;
                        Lifetime2(Y, X) = Results{Y, X}.T2;
                        Stretch2(Y, X) = Results{Y, X}.H2;
                        Amplitude3(Y, X) = Results{Y, X}.A3;
                        Lifetime3(Y, X) = Results{Y, X}.T3;
                        Stretch3(Y, X) = Results{Y, X}.H3;
                    end
                end
            end
            % Store results
            obj.Results.Background = round(Background, 5, 'significant');
            obj.Results.Amplitude1 = round(Amplitude1, 5, 'significant');
            obj.Results.Lifetime1 = round(Lifetime1, 5, 'significant');
            obj.Results.Stretch1 = round(Stretch1, 5, 'significant');
            obj.Results.Amplitude2 = round(Amplitude2, 5, 'significant');
            obj.Results.Lifetime2 = round(Lifetime2, 5, 'significant');
            obj.Results.Stretch2 = round(Stretch2, 5, 'significant');
            obj.Results.Amplitude3 = round(Amplitude3, 5, 'significant');
            obj.Results.Lifetime3 = round(Lifetime3, 5, 'significant');
            obj.Results.Stretch3 = round(Stretch3, 5, 'significant');
        end
        function saveResults(obj)
            FileName = strsplit(obj.AbsoluteFileName, '.msr');
            FileName = FileName{1};
            writematrix(obj.IntensityImage, strcat(FileName, '-intensity.csv'))
            writematrix(obj.Results.Background, strcat(FileName, '-background.csv'))
            writematrix(obj.Results.Amplitude1, strcat(FileName, '-amplitude1.csv'))
            writematrix(obj.Results.Lifetime1, strcat(FileName, '-lifetime1.csv'))
            writematrix(obj.Results.Stretch1, strcat(FileName, '-stretch1.csv'))
            writematrix(obj.Results.Amplitude2, strcat(FileName, '-amplitude2.csv'))
            writematrix(obj.Results.Lifetime2, strcat(FileName, '-lifetime2.csv'))
            writematrix(obj.Results.Stretch2, strcat(FileName, '-stretch2.csv'))
            writematrix(obj.Results.Amplitude3, strcat(FileName, '-amplitude3.csv'))
            writematrix(obj.Results.Lifetime3, strcat(FileName, '-lifetime3.csv'))
            writematrix(obj.Results.Stretch3, strcat(FileName, '-stretch3.csv'))
        end
    end
end