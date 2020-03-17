% By Brian Bjarke Jensen 28/2-2019

classdef readSdt < handle
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
        function obj = readSdt(AbsoluteFileName, Binning, NumberOfDecays, ForceFitOnAllPixels)
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
            % Second row of data comes from the detector with the correct
            % filter settings
            UsefulDetector = 2;
            %Data = Data(UsefulDetector, :);
            % Get information from hashtable
            [Keys, Values] = getKeysAndValuesFromHashTable(Data{UsefulDetector, 2});
            obj.Info = compileStructFromKeyValuePairs(Keys, Values);
            % Fetch images
            NumOfDataPoints = size(Data{UsefulDetector, 1},1);
            DuplicateIdx = (1 : NumOfDataPoints) > NumOfDataPoints / 2;
            Image = Data{UsefulDetector, 1}(~DuplicateIdx, 1);
            % Store intensity image
            obj.IntensityImage = sum(cat(3, Image{:}), 3);
            % Fetch timebin numbers
            Info = regexp(Data{UsefulDetector, 1}(~DuplicateIdx, 2), '; ', 'split');
            TimeBin = cellfun(@(x) strsplit(x{5}, 'T='), Info, 'UniformOutput', false);
            TimeBin = cellfun(@(x) strsplit(x{2}, '/'), TimeBin, 'UniformOutput', false);
            TimeBin = cellfun(@(x) str2double(x{1}), TimeBin);
            % Calculate timebin time
            TimeStep = str2double(obj.Info.GlobalSP_TAC_TC);
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
%             % Drop data at timesteps that do not contain decay
%             Time = obj.Data.Time(DecayIdx);
%             Photons = Photons(DecayIdx);
%             % Do binned fit
%             NumberOfDecays = determineNumberOfExponentialDecays(Time, Photons);
%             InitialGuess = NaN;
%             InitialFit = calculateExponentialDecay(Time, Photons, NumberOfDecays, InitialGuess);
%             if isa(obj.Binning, 'char') && strcmp(obj.Binning, 'Full')
%                 obj.Results.Background = InitialFit.B;
%                 obj.Results.Amplitude1 = InitialFit.A1;
%                 obj.Results.Lifetime1 = InitialFit.T1;
%                 obj.Results.Stretch1 = InitialStretchFit.H1;
%                 obj.Results.Amplitude2 = InitialFit.A2;
%                 obj.Results.Lifetime2 = InitialFit.T2;
%                 obj.Results.Stretch2 = InitialStretchFit.H2;
%                 obj.Results.Amplitude3 = InitialFit.A3;
%                 obj.Results.Lifetime3 = InitialFit.T3;
%                 obj.Results.Stretch3 = InitialStretchFit.H3;
%             elseif isa(obj.Binning, 'double')
%                 [PixelY, PixelX] = size(obj.Data.Image{1});
%                 % Prepare results variables
%                 obj.Results.Compound = {obj.Compound};
%                 obj.Results.Solvent = {obj.Solvent};
%                 obj.Results.Background = NaN(PixelY, PixelX);
%                 obj.Results.Amplitude1 = NaN(PixelY, PixelX);
%                 obj.Results.Lifetime1 = NaN(PixelY, PixelX);
%                 obj.Results.Stretch1 = NaN(PixelY, PixelX);
%                 obj.Results.Amplitude2 = NaN(PixelY, PixelX);
%                 obj.Results.Lifetime2 = NaN(PixelY, PixelX);
%                 obj.Results.Stretch2 = NaN(PixelY, PixelX);
%                 obj.Results.Amplitude3 = NaN(PixelY, PixelX);
%                 obj.Results.Lifetime3 = NaN(PixelY, PixelX);
%                 obj.Results.Stretch3 = NaN(PixelY, PixelX);
%                 % Act on each pixel in image
%                 BinnedImage = cellfun(@(x) binImage(x, obj.Binning), obj.Data.Image, 'UniformOutput', false);
%                 for Y = 1:PixelY
%                     for X = 1:PixelX
%                         % Get fitting variables and determine decay
%                         % timesteps
%                         Time = obj.Data.Time;
%                         Photons = cellfun(@(x) x(Y, X), BinnedImage);
%                         DecayIdx = determineDecayIndex(Photons);
%                         % If decay is observed, do fit
%                         if any(DecayIdx)
%                             % Drop data at timesteps that do not contain
%                             % decay
%                             Time = Time(DecayIdx);
%                             Photons = Photons(DecayIdx);
%                             % Do fit
%                             NumberOfDecays = determineNumberOfExponentialDecays(Time, Photons);
%                             Fit = calculateExponentialDecay(Time, Photons, NumberOfDecays, InitialFit);
%                             StretchFit = calculateExponentialDecayStretch(Time, Photons, Fit);
%                             % Store results
%                             obj.Results.Background(Y, X) = Fit.B;
%                             obj.Results.Amplitude1(Y, X) = Fit.A1;
%                             obj.Results.Lifetime1(Y, X) = Fit.T1;
%                             obj.Results.Stretch1(Y, X) = StretchFit.H1;
%                             obj.Results.Amplitude2(Y, X) = Fit.A2;
%                             obj.Results.Lifetime2(Y, X) = Fit.T2;
%                             obj.Results.Stretch2(Y, X) = StretchFit.H2;
%                             obj.Results.Amplitude3(Y, X) = Fit.A3;
%                             obj.Results.Lifetime3(Y, X) = Fit.T3;
%                             obj.Results.Stretch2(Y, X) = StretchFit.H2;
%                         end
%                     end
%                 end
%             end
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
        function fig = showColorCodedLifetimeImage(obj)
            Detector = 2;
            % Prepare figure
            fig = figure;
            % Create colormap baased on lifetime
            Color.Values = parula(2);
            Lifetime.Values = obj.Results.Lifetime{Detector};
            Lifetime.Min = min(min(Lifetime.Values));
            Lifetime.Max = max(max(Lifetime.Values));
            Color.Fit.R = polyfit([Lifetime.Min; Lifetime.Max], Color.Values(:, 1), 1);
            Color.Fit.G = polyfit([Lifetime.Min; Lifetime.Max], Color.Values(:, 2), 1);
            Color.Fit.B = polyfit([Lifetime.Min; Lifetime.Max], Color.Values(:, 3), 1);
            % Create color channels
            Image.R = Lifetime.Values * Color.Fit.R(1) + Color.Fit.R(2);
            Image.G = Lifetime.Values * Color.Fit.G(1) + Color.Fit.G(2);
            Image.B = Lifetime.Values * Color.Fit.B(1) + Color.Fit.B(2);
            % Create brightness scale
            Amplitude.Values = obj.Results.Amplitude{Detector};
            Amplitude.Mean = mean2(Amplitude.Values);
            Amplitude.SD = std2(Amplitude.Values);
            Amplitude.Min = min(min(Amplitude.Values));
            Amplitude.Max = max(max(Amplitude.Values));
            Amplitude.Fit = polyfit([Amplitude.Min, Amplitude.Max], [0, 1], 1);
            % Adjust brightness
            Image.R = Image.R .* ( Amplitude.Values * Amplitude.Fit(1) + Amplitude.Fit(2) );
            Image.G = Image.G .* ( Amplitude.Values * Amplitude.Fit(1) + Amplitude.Fit(2) );
            Image.B = Image.B .* ( Amplitude.Values * Amplitude.Fit(1) + Amplitude.Fit(2) );
            % Combine images
            Image.Combined = cat(3, Image.R, Image.G, Image.B);
            % Show image
            imshow(Image.Combined, [Amplitude.Mean - Amplitude.SD, Amplitude.Mean + Amplitude.SD]);
            colorbar()
        end
        function fig = showRawImage(obj)
            fig = figure;
            Data = obj.Data{2}; % choosing image from detector 2
            Data = Data(1:end/2, 1); % choosing first channel
            ImageTimePlanes = cat(3, Data{:});
            SumImage.Intensity = sum(ImageTimePlanes, 3, 'native');
            SumImage.Low = mean2(SumImage.Intensity) - 3 * std2(SumImage.Intensity);
            SumImage.High = mean2(SumImage.Intensity) + 3 * std2(SumImage.Intensity);
            imshow(SumImage.Intensity, [SumImage.Low, SumImage.High]);
        end
        function fig = plotAverageLinearTimeProfile(obj)
            % Create figure
            fig = figure;
            hold on
            xlabel('time (ns)');
            ylabel('intensity (a.u.)');
            % Plot
            Detector = 2;
            X = obj.Results.DataPoints{Detector}{1};
            Y = squeeze(mean(mean(obj.Results.DataPoints{Detector}{2}, 1), 2));
            plot(X, Y, 'b', 'LineWidth', 2, 'DisplayName', 'data');
            Fit = obj.Results.Fit{Detector};
            MeanA = mean2(cellfun(@(x) x.A, Fit));
            MeanT = mean2(cellfun(@(x) x.T, Fit));
            Y = MeanA - X / MeanT;
            plot(X, Y, 'r', 'DisplayName', 'fitted curve');
            legend();
        end
        function fig = plotAverageNonlinearTimeProfile(obj)
            % Create figure
            fig = figure;
            hold on
            xlabel('time (ns)');
            ylabel('intensity (a.u.)');
            % Plot
            Detector = 2;
            X = obj.Results.DataPoints{Detector}{1};
            Y = squeeze(mean(mean(obj.Results.DataPoints{Detector}{2}, 1), 2));
            Y = exp(Y) + mean2(obj.Results.BackgroundIntensity{Detector});
            plot(X, Y, 'b', 'LineWidth', 2, 'DisplayName', 'data');
            Fit = obj.Results.Fit{Detector};
            MeanA = mean2(cellfun(@(x) x.A, Fit));
            MeanT = mean2(cellfun(@(x) x.T, Fit));
            Y = exp(MeanA - X / MeanT) + mean2(obj.Results.BackgroundIntensity{Detector});
            plot(X, Y, 'r', 'DisplayName', 'fitted curve');
            legend();
        end
    end
end