% By Brian Bjarke Jensen 28/2-2019

classdef readSdt < handle
    % Class used for reading and containing FLIM-data
    properties
        AbsoluteFileName
        Title
        Date
        Replicate
        Type
        Solvent
        Concentration
        Compound
        Binning
        Data
        Info
        Results
    end
    methods
        function obj = readSdt(AbsoluteFileName, Binning)
            % Ask for file, if none is provided
            if ~exist('AbsoluteFileName', 'var')
                [File, Path] = uigetfile('*.sdt', 'Please Select Data To Import');
                AbsoluteFileName = fullfile(Path, File);
            end
            obj.AbsoluteFileName = AbsoluteFileName;
            % Ask for binning, if none is provided
            if ~exist('Binning', 'var')
                Binning = input('Please Specify Binning:\n');
            end
            obj.Binning = Binning;
            % Read sample information from file name
            [~, FileName, ~] = fileparts(obj.AbsoluteFileName);
            obj.Title = FileName;
            [obj.Date, obj.Replicate, obj.Type, obj.Solvent, obj.Concentration, obj.Compound] = readInformationFromFileName(obj.Title);
            % Import data
            Data = bfopen(obj.AbsoluteFileName);
            % All data but detector 2, channel 1 is junk
            KeepDetector = 2;
            KeepChannel = 1;
            [Keys, Values] = getKeysAndValuesFromHashTable(Data{KeepDetector, 2});
            obj.Info = compileStructFromKeyValuePairs(Keys, Values);
            % Fetch relevant data
            Info = regexp(Data{KeepDetector}(:, 2), '; ', 'split');
            Channels = cellfun(@(x) strsplit(x{4}, 'C='), Info, 'UniformOutput', false);
            Channels = cellfun(@(x) strsplit(x{2}, '/'), Channels, 'UniformOutput', false);
            Channels = cellfun(@(x) str2double(x{1}), Channels);
            KeepChannelIdx = Channels == KeepChannel;
            TimeBin = cellfun(@(x) strsplit(x{5}, 'T='), Info, 'UniformOutput', false);
            TimeBin = cellfun(@(x) strsplit(x{2}, '/'), TimeBin, 'UniformOutput', false);
            TimeBin = cellfun(@(x) str2double(x{1}), TimeBin);
            TimeBin = TimeBin(KeepChannelIdx);
            Image = Data{KeepDetector}(KeepChannelIdx, 1);
            % Store relevant data
            obj.Data = table(TimeBin, Image);
            % Calculate timesteps
            TimeStep = str2double(obj.Info.SP_TAC_TC);
            obj.Data.Time = obj.Data.TimeBin * TimeStep * 10^9; % Converting seconds to nanoseconds
            % Do initial fit of fully binned image to estimate parameters
            Time = obj.Data.Time;
            Photons = cellfun(@(x) sum(x, 'all'), obj.Data.Image);
            DecayIdx = determineDecayIndex(Photons);
            Time = Time(DecayIdx);
            Photons = Photons(DecayIdx);
            NumberOfDecays = determineNumberOfExponentialDecays(Time, Photons);
            InitialFit = calculateExponentialDecay(Time, Photons, NumberOfDecays);
            InitialStretchFit = calculateExponentialDecayStretch(Time, Photons, InitialFit);
            if isa(obj.Binning, 'char') && strcmp(obj.Binning, 'Full')
                obj.Results.Compound = {obj.Compound};
                obj.Results.Solvent = {obj.Solvent};
                obj.Results.Background = InitialFit.B;
                obj.Results.Amplitude1 = InitialFit.A1;
                obj.Results.Lifetime1 = InitialFit.T1;
                obj.Results.Stretch1 = InitialStretchFit.H1;
                obj.Results.Amplitude2 = InitialFit.A2;
                obj.Results.Lifetime2 = InitialFit.T2;
                obj.Results.Stretch2 = InitialStretchFit.H2;
                obj.Results.Amplitude3 = InitialFit.A3;
                obj.Results.Lifetime3 = InitialFit.T3;
                obj.Results.Stretch3 = InitialStretchFit.H3;
            elseif isa(obj.Binning, 'double')
                [PixelY, PixelX] = size(obj.Data.Image{1});
                % Prepare results variables
                obj.Results.Compound = {obj.Compound};
                obj.Results.Solvent = {obj.Solvent};
                obj.Results.Background = NaN(PixelY, PixelX);
                obj.Results.Amplitude1 = NaN(PixelY, PixelX);
                obj.Results.Lifetime1 = NaN(PixelY, PixelX);
                obj.Results.Stretch1 = NaN(PixelY, PixelX);
                obj.Results.Amplitude2 = NaN(PixelY, PixelX);
                obj.Results.Lifetime2 = NaN(PixelY, PixelX);
                obj.Results.Stretch2 = NaN(PixelY, PixelX);
                obj.Results.Amplitude3 = NaN(PixelY, PixelX);
                obj.Results.Lifetime3 = NaN(PixelY, PixelX);
                obj.Results.Stretch3 = NaN(PixelY, PixelX);
                % Act on each pixel in image
                BinnedImage = cellfun(@(x) binImage(x, obj.Binning), obj.Data.Image, 'UniformOutput', false);
                for Y = 1:PixelY
                    for X = 1:PixelX
                        Time = obj.Data.Time;
                        Photons = cellfun(@(x) x(Y, X), BinnedImage);
                        DecayIdx = determineDecayIndex(Photons);
                        % If decay is observed, do fit
                        if any(DecayIdx)
                            Time = Time(DecayIdx);
                            Photons = Photons(DecayIdx);
                            NumberOfDecays = determineNumberOfExponentialDecays(Time, Photons);
                            Fit = calculateExponentialDecay(Time, Photons, NumberOfDecays);
                            StretchFit = calculateExponentialDecayStretch(Time, Photons, Fit);
                            obj.Results.Background(Y, X) = Fit.B;
                            obj.Results.Amplitude1(Y, X) = Fit.A1;
                            obj.Results.Lifetime1(Y, X) = Fit.T1;
                            obj.Results.Stretch1(Y, X) = StretchFit.H1;
                            obj.Results.Amplitude2(Y, X) = Fit.A2;
                            obj.Results.Lifetime2(Y, X) = Fit.T2;
                            obj.Results.Stretch2(Y, X) = StretchFit.H2;
                            obj.Results.Amplitude3(Y, X) = Fit.A3;
                            obj.Results.Lifetime3(Y, X) = Fit.T3;
                            obj.Results.Stretch2(Y, X) = StretchFit.H2;
                        end
                    end
                end
            end
        end
        function calculateLocalLifetime(obj)
            Detector = 2;
            % Calculate time profile
            RawData = obj.Data{2}; % choosing image from detector 2
            RawData = RawData(1:end/2, 1); % choosing first channel
            RawData = cat(3, RawData{:});
            % Creating time points
            TimeBase = obj.Info{Detector}.timebase; % nanoseconds
            TimeStep = TimeBase / length(RawData);
            TimePoints = (TimeStep : TimeStep : TimeBase).';
            % Convolute image to apply binning
            Filter = ones(2 * obj.Results.Binning + 1, 2 * obj.Results.Binning + 1, 'uint16');
            BinnedData = uint16(convn(RawData, Filter, 'same'));
            % Crop image
            CropImage = sum(RawData, 3, 'native');
            Scaling = 65535 / max(max(CropImage));
            CropImage = CropImage * Scaling;
            [~, CropPos] = imcrop(CropImage);
            CropPos = uint16(round(CropPos));
            CropPos = [CropPos(1), CropPos(2), CropPos(1) + CropPos(3) - 1, CropPos(2) + CropPos(4) - 1];
            Data = BinnedData(CropPos(1):CropPos(3), CropPos(2):CropPos(4), :);
            % Show cropped image
            Image.Sum = sum(Data, 3, 'native');
            Image.Mean = mean2(Image.Sum);
            Image.SD = std2(Image.Sum);
            imshow(Image.Sum, [Image.Mean - Image.SD, Image.Mean + Image.SD]);
            % imshow(Data(:,:,70), [mean2(Data(:,:,70)) - std2(Data(:,:,70)), mean2(Data(:,:,70)) + std2(Data(:,:,70))])
            % plot(squeeze(sum(sum(Data, 1), 2)))
            
            % Locate time planes with zero intensity
            TimeProfile = squeeze(sum(sum(Data, 1), 2));
            ZeroIntensity = TimeProfile == 0;
            % Locate point of excitation
            [~, MaxIndex] = max(TimeProfile);
            % Determine preexcitation background intensity
            PreExcitation = and((1:length(TimeProfile)).' < MaxIndex, ~ZeroIntensity);
            BackgroundIntensity = min(Data(:, :, PreExcitation), [], 3);
            obj.Results.BackgroundIntensity{Detector} = BackgroundIntensity;
            % Locate suitable time planes for fitting
            TimePlanesWithDecay = and((1:length(TimeProfile)).' >= MaxIndex, ~ZeroIntensity);
            TimePoints = TimePoints(TimePlanesWithDecay);
            Data = Data(:, :, TimePlanesWithDecay);
            TimeProfile = squeeze(sum(sum(Data, 1), 2));
            % Show cropped binned image timeprofile
            plot(TimePoints, TimeProfile);
            % Transform data for linear fitting
            [Y, X, Z] = size(Data);
            Data = log(double(minus(Data, repmat(BackgroundIntensity, 1, 1, Z))));
            Data(Data == -Inf) = 0;
            obj.Results.DataPoints{Detector} = {TimePoints, Data};
            % Define fitting model
            FitType = fittype('A - t / T', 'dependent', {'I'}, 'independent', {'t'}, 'coefficients', {'A', 'T'});
            Limit.Init = [1, 1];
            Limit.Low = [0, 0.2];
            Limit.High = [Inf, TimeBase];
            FitOptions = fitoptions('Method', 'NonlinearLeastSquares', 'Lower', Limit.Low, 'Upper', Limit.High, 'StartPoint', Limit.Init);
            % Prepare progressbar
            Iteration = 0;
            Step = 0;
            TotalSteps = Y * X;
            StepSize = 1 / TotalSteps;
            f = waitbar(Step, sprintf('Fitting Data: %d / %d', Iteration, TotalSteps));
            % Do fit
            Fit = cell(Y, X);
            for y = 1:Y
                for x = 1:X
                    plot(TimePoints, squeeze(Data(y, x, :)), 'b', 'LineWidth', 2);
                    Fit{y, x} = fit(TimePoints, squeeze(Data(y, x, :)), FitType, FitOptions);
                    hold on
                    FittedData = Fit{y, x}.A - TimePoints / Fit{y, x}.T;
                    plot(TimePoints, FittedData, 'r');
                    hold off
                    Iteration = Iteration + 1;
                    Step = Step + StepSize;
                    waitbar(Step, f, sprintf('Fitting Data: %d / %d', Iteration, TotalSteps));
                end
            end
            close(f)
            close()
            obj.Results.Fit{Detector} = Fit;
            obj.Results.Amplitude{Detector} = cellfun(@(x) x.A, Fit);
            obj.Results.Lifetime{Detector} = cellfun(@(x) x.T, Fit);
        end
        function calculateOverallLifetimeFull(obj)
            Detector = 2;
            % Calculate time profile
            RawData = obj.Data{2}; % choosing image from detector 2
            RawData = RawData(1:end/2, 1); % choosing first channel
            RawData = cat(3, RawData{:});
            % Creating time points
            TimeBase = obj.Info{Detector}.timebase; % nanoseconds
            TimeStep = TimeBase / length(RawData);
            TimePoints = (TimeStep : TimeStep : TimeBase).';
            % Convolute image to apply binning
            Filter = ones(2 * obj.Results.Binning + 1, 2 * obj.Results.Binning + 1, 'uint16');
            %Filter = double(Filter) / sum(sum(Filter));
            Data = uint16(convn(RawData, Filter, 'same'));
            % Locate time planes with zero intensity
            TimeProfile = squeeze(sum(sum(Data, 1), 2));
            ZeroIntensity = TimeProfile == 0;
            % Locate point of excitation
            [~, MaxIndex] = max(TimeProfile);
            % Determine preexcitation background intensity
            PreExcitation = and((1:length(TimeProfile)).' < MaxIndex, ~ZeroIntensity);
            BackgroundIntensity = min(Data(:, :, PreExcitation), [], 3);
            obj.Results.BackgroundIntensity{Detector} = BackgroundIntensity;
            % Locate suitable time planes for fitting
            TimePlanesWithDecay = and((1:length(TimeProfile)).' >= MaxIndex, ~ZeroIntensity);
            TimePoints = TimePoints(TimePlanesWithDecay);
            Data = Data(:, :, TimePlanesWithDecay);
            TimeProfile = TimeProfile(TimePlanesWithDecay);
            % Show cropped timeprofile
            plot(TimePoints, TimeProfile);
            % Locate background in image
            SumImage = sum(Data, 3);
            Threshold = max(max(SumImage)) * 0.1;
            BackgroundIndex = zeros(size(Data, 1), size(Data, 2));
            BackgroundIndex(SumImage < Threshold) = 1;
            % Transform data for linear fitting
            [Y, X, Z] = size(Data);
            Data = log(double(minus(Data, repmat(BackgroundIntensity, 1, 1, Z))));
            Data(Data == -Inf) = 0;
            obj.Results.DataPoints{Detector} = {TimePoints, Data};
            % Define fitting model
            FitType = fittype('A - t / T', 'dependent', {'I'}, 'independent', {'t'}, 'coefficients', {'A', 'T'});
            Init = [1, 1];
            Low = [0, 0.2];
            High = [Inf, TimeBase];
            FitOptions = fitoptions('Method', 'NonlinearLeastSquares', 'Lower', Low, 'Upper', High, 'StartPoint', Init);
            % Prepare progressbar
            Iteration = 0;
            Step = 0;
            TotalSteps = sum(sum(BackgroundIndex, 1), 2);
            StepSize = 1 / TotalSteps;
            f = waitbar(Step, sprintf('Fitting Data: %d / %d', Iteration, TotalSteps));
            % Do fit
            Fit = cell(Y, X);
            for y = 1:Y
                for x = 1:X
                    if BackgroundIndex(y, x) == 0
                        plot(TimePoints, squeeze(Data(y, x, :)), 'b', 'LineWidth', 2);
                        Fit{y, x} = fit(TimePoints, squeeze(Data(y, x, :)), FitType, FitOptions);
                        hold on
                        FittedData = Fit{y, x}.A - TimePoints / Fit{y, x}.T;
                        plot(TimePoints, FittedData, 'r');
                        hold off
                        Iteration = Iteration + 1;
                        Step = Step + StepSize;
                        waitbar(Step, f, sprintf('Fitting Data: %d / %d', Iteration, TotalSteps));
                    else
                        Fit{y, x}.A = 0;
                        Fit{y, x}.T = 0;
                    end
                end
            end
            close(f)
            obj.Results.Fit{Detector} = Fit;
            obj.Results.Amplitude{Detector} = cellfun(@(x) x.A, Fit);
            obj.Results.Lifetime{Detector} = cellfun(@(x) x.T, Fit);
        end
        function calculateOverallLifetimeFast(obj)
            Detector = 2;
            % Calculate time profile
            TempData = obj.Data{2}; % choosing image from detector 2
            TempData = TempData(1:end/2, 1); % choosing first channel
            TempData = cat(3, TempData{:});
            TimeProfile = squeeze(sum(sum(TempData, 1), 2));
            % Creating time points
            TimeBase = obj.Info{Detector}.timebase; % nanoseconds
            TimeStep = TimeBase / length(TempData);
            TimePoints = (TimeStep : TimeStep : TimeBase).';
            % Locate time planes with zero intensity
            ZeroIntensity = TimeProfile == 0;
            % Locate point of excitation
            [~, MaxIndex] = max(TimeProfile);
            % Determine preexcitation background intensity
            PreExcitation = and((1:length(TimeProfile)).' < MaxIndex, ~ZeroIntensity);
            BackgroundIntensity = min(TimeProfile(PreExcitation));
            % Locate suitable data for fitting
            SuitableData = and((1:length(TimeProfile)).' >= MaxIndex, ~ZeroIntensity);
            % Transform data for linear fitting
            TimePoints = TimePoints(SuitableData);
            TimeProfile = log(TimeProfile(SuitableData) - BackgroundIntensity);
            obj.Results.DataPoints{Detector} = table(TimePoints, TimeProfile);
            obj.Results.BackgroundIntensity{Detector} = BackgroundIntensity;
            % Define fitting model
            FitType = fittype('A - t / T', 'dependent', {'I'}, 'independent', {'t'}, 'coefficients', {'A', 'T'});
            Limit.Low = [0, 0.2];
            Limit.High = [Inf, TimeBase];
            FitOptions = fitoptions('Method', 'LinearLeastSquares', 'Lower', Limit.Low, 'Upper', Limit.High);
            % Do fit
            obj.Results.Fit{Detector} = fit(TimePoints, TimeProfile, FitType, FitOptions);
%             % Define fitting model
%             FitType = fittype('B + A * exp( -t / T )', 'dependent', {'I'}, 'independent', {'t'}, 'coefficients', {'B', 'A', 'T'});
%             Limit.Init = [BackgroundIntensity, 1, 1];
%             Limit.Low = [BackgroundIntensity, 0, 0.2];
%             Limit.High = [BackgroundIntensity, Inf, TimeBase];
%             FitOptions = fitoptions('Method', 'NonlinearLeastSquares', 'Lower', Limit.Low, 'Upper', Limit.High, 'StartPoint', Limit.Init);
%             % Do fit
%             Smoothing = 50;
%             obj.Fit = fit(TimePoints(SuitableData), smooth(TimeProfile(SuitableData), Smoothing), FitType, FitOptions);
        end
        function saveResults(obj)
            Detector = 2;
            FileName = strsplit(obj.AbsoluteFilePath, '.sdt');
            FileName = {FileName{1}, '.csv'};
            Background = obj.Results.BackgroundIntensity{Detector};
            csvwrite(strjoin(FileName, '-background'), Background);
            Amplitude = cellfun(@(x) round(x.A, 3), obj.Results.Fit{Detector});
            csvwrite(strjoin(FileName, '-amplitude'), Amplitude);
            Lifetime = cellfun(@(x) round(x.T, 3), obj.Results.Fit{Detector});
            csvwrite(strjoin(FileName, '-lifetime'), Lifetime);
            Data = obj.Data{2}; % choosing image from detector 2
            Data = Data(1:end/2, 1); % choosing first channel
            ImageTimePlanes = cat(3, Data{:});
            SumImage = sum(ImageTimePlanes, 3, 'native');
            csvwrite(strjoin(FileName, '-sumimage'), SumImage);
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