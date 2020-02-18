function S = calculateExponentialDecay(X, Y, Order)
    X = double(X);
    Y = double(Y);
    Order = double(Order);
    % Setup fit
    switch Order
        case 1
            FitType = fittype('B + A1 * exp( -x / T1)', 'Coefficients', {'B', 'A1', 'T1'});
            LowerLimit = [0, mean(Y), 10 * min(diff(X))]; % [B, A, T]
            UpperLimit = [mean(Y), Inf, max(X)];
            StartGuess = [min(Y), max(Y), max(X) / 2];
        case 2
            FitType = fittype('B + A1 * exp( -x / T1 ) + A2 * exp( -x / T2 )', 'Coefficients', {'B', 'A1', 'T1', 'A2', 'T2'});
            LowerLimit = [0, mean(Y), 10 * min(diff(X)), mean(Y), 10 * min(diff(X))]; % [B, A1, T1, A2, T2]
            UpperLimit = [mean(Y), Inf, max(X), Inf, max(X)];
            StartGuess = [min(Y), max(Y), max(X) / 2, max(Y), max(X) / 2];
        case 3
            FitType = fittype('B + A1 * exp( -x / T1 ) + A2 * exp( -x / T2 ) + A3 * exp( -x / T3 )', 'Coefficients', {'B', 'A1', 'T1', 'A2', 'T2', 'A3', 'T3'});
            LowerLimit = [0, mean(Y), 10 * min(diff(X)), mean(Y), 10 * min(diff(X)), mean(Y), 10 * min(diff(X))]; % [B, A1, T1, A2, T2, A3, T3]
            UpperLimit = [mean(Y), Inf, max(X), Inf, max(X), Inf, max(X)];
            StartGuess = [min(Y), max(Y), max(X) / 2, max(Y), max(X) / 2, max(Y), max(X) / 2];
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