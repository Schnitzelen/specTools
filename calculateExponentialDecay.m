function S = calculateExponentialDecay(X, Y, Order, GuessFit)
    % Make sure that data type is double;
    X = double(X);
    Y = double(Y);
    Order = double(Order);
    % Set up fitting parameters based on provided arguments
    switch class(GuessFit)
        case 'struct'
            Start.B = GuessFit.B;
            Start.A1 = GuessFit.A1;
            Start.T1 = GuessFit.T1;
            Start.A2 = GuessFit.A2;
            Start.T2 = GuessFit.T2;
            Start.A3 = GuessFit.A3;
            Start.T3 = GuessFit.T3;
        case 'double'
            Start.B = min(Y);
            Start.A1 = max(Y);
            Start.T1 = max(X) / 2;
            Start.A2 = max(Y);
            Start.T2 = max(X) / 2;
            Start.A3 = max(Y);
            Start.T3 = max(X) / 2;
    end
    % Setup fit
    Min.B = 0;
    Min.A = mean(Y);
    Min.T = 10 * min(diff(X));
    Max.B = mean(Y);
    Max.A = Inf;
    Max.T = max(X);
    switch Order
        case 1
            FitType = fittype('B + A1 * exp( -x / T1)', 'Coefficients', {'B', 'A1', 'T1'});
            LowerLimit = [Min.B, Min.A, Min.T]; % [B, A, T]
            UpperLimit = [Max.B, Max.A, Max.T];
            StartGuess = [Start.B, Start.A1, Start.T1];
        case 2
            FitType = fittype('B + A1 * exp( -x / T1 ) + A2 * exp( -x / T2 )', 'Coefficients', {'B', 'A1', 'T1', 'A2', 'T2'});
            LowerLimit = [Min.B, Min.A, Min.T, Min.A, Min.T]; % [B, A1, T1, A2, T2]
            UpperLimit = [Max.B, Max.A, Max.T, Max.A, Max.T];
            StartGuess = [Start.B, Start.A1, Start.T1, Start.A2, Start.T2];
        case 3
            FitType = fittype('B + A1 * exp( -x / T1 ) + A2 * exp( -x / T2 ) + A3 * exp( -x / T3 )', 'Coefficients', {'B', 'A1', 'T1', 'A2', 'T2', 'A3', 'T3'});
            LowerLimit = [Min.B, Min.A, Min.T, Min.A, Min.T, Min.A, Min.T]; % [B, A1, T1, A2, T2, A3, T3]
            UpperLimit = [Max.B, Max.A, Max.T, Max.A, Max.T, Max.A, Max.T];
            StartGuess = [Start.B, Start.A1, Start.T1, Start.A2, Start.T2, Start.A3, Start.T3];
    end
    % Do fit
    Fit = fit(X, Y, FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess);
    % Prepare variables to return
    S.B = Fit.B;
    S.A1 = Fit.A1;
    S.T1 = Fit.T1;
    if Order > 1
        S.A2 = Fit.A2;
        S.T2 = Fit.T2;
    else
        S.A2 = NaN;
        S.T2 = NaN;
    end
    if Order > 2
        S.A3 = Fit.A3;
        S.T3 = Fit.T3;
    else
        S.A3 = NaN;
        S.T3 = NaN;
    end
end