function Fit = calculateExponentialDecayStretch(X, Y, Fit)
    X = double(X);
    Y = double(Y);
    % Determine order of fit
    if ~isnan(Fit.A3)
        Order = 3;
    elseif ~isnan(Fit.A2)
        Order = 2;
    else
        Order = 1;
    end
    % Setup fit
    switch Order
        case 1
            FitType = fittype('B + A1 * exp( - ( x / T1 )^( 1 / H1 ) )', 'Coefficients', {'H1'}, 'Problem', {'B', 'A1', 'T1'});
            LowerLimit = [0]; % [H1]
            UpperLimit = [Inf];
            StartGuess = [1];
            Problem = {Fit.B, Fit.A1, Fit.T1}; % [B, A1, T1]
        case 2
            FitType = fittype('B + A1 * exp( - ( x / T1 )^( 1 / H1 ) ) + A2 * exp( - ( x / T2 )^( 1 / H2 ) )', 'Coefficients', {'H1', 'H2'}, 'Problem', {'B', 'A1', 'T1', 'A2', 'T2'});
            LowerLimit = [0, 0]; % [H1, H2]
            UpperLimit = [Inf, Inf];
            StartGuess = [1, 1];
            Problem = {Fit.B, Fit.A1, Fit.T1, Fit.A2, Fit.T2}; % [B, A1, T1, A2, T2]
        case 3
            FitType = fittype('B + A1 * exp( - ( x / T1 )^( 1 / H1 ) ) + A2 * exp( - ( x / T2 )^( 1 / H2 ) ) + A3 * exp( - ( x / T3 )^( 1 / H3 ) )', 'Coefficients', {'H1', 'H2', 'H3'}, 'Problem', {'B', 'A1', 'T1', 'A2', 'T2', 'A3', 'T3'});
            LowerLimit = [0, 0, 0]; % [H1, H2, H3]
            UpperLimit = [Inf, Inf, Inf];
            StartGuess = [1, 1, 1];
            Problem = {Fit.B, Fit.A1, Fit.T1, Fit.A2, Fit.T2, Fit.A3, Fit.T3}; % [B, A1, T1, A2, T2, A3, T3]
    end
    % Do fit
    StretchFit = fit(X, Y, FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess, 'problem', Problem);
    % Prepare variables to return
    Fit.H1 = StretchFit.H1;
    if Order > 1
        Fit.H2 = StretchFit.H2;
    else
        Fit.H2 = NaN;
    end
    if Order > 2
        Fit.H3 = StretchFit.H3;
    else
        Fit.H3 = NaN;
    end
end