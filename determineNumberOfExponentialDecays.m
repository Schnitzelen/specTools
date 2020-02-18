function NumberOfDecays = determineNumberOfExponentialDecays(X, Y)
    % Preprocess data
    if min(X) < 10^-6
        LinX = X * 10^9; % fits seem to terminate early due to very small x
    else
        LinX = X;
    end
    LinY = log(double(Y));
    % Do linear fit expecting one decay
    FitType = fittype('B1 - A1 * x', 'Coefficients', {'B1', 'A1'}, 'Independent', {'x'}, 'Dependent', {'y'});
    LowerLimit = [0, 0]; % [B1, A1]
    UpperLimit = [Inf, Inf];
    LinFit = polyfit(X, LinY, 1);
    StartGuess = [LinFit(2), LinFit(1)];
    [Fit{1}, GOF{1}] = fit(LinX, LinY, FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess);
    % Do linear fit expecting two decays
    FitType = fittype('B1 - A1 * x + B2 - A2 * x', 'Coefficients', {'B1', 'A1', 'B2', 'A2'}, 'Independent', {'x'}, 'Dependent', {'y'});
    LowerLimit = [0, 0, 0, 0]; % [B1, A1, B2, A2]
    UpperLimit = [Inf, Inf, Inf, Inf];
    StartGuess = [max(LinY), 1, max(LinY), 1];
    [Fit{2}, GOF{2}] = fit(LinX, LinY, FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess);
    % Do linear fit expecting three decays
    FitType = fittype('B1 - A1 * x + B2 - A2 * x + B3 - A3 * x', 'Coefficients', {'B1', 'A1', 'B2', 'A2', 'B3', 'A3'}, 'Independent', {'x'}, 'Dependent', {'y'});
    LowerLimit = [0, 0, 0, 0, 0, 0]; % [B1, A1, B2, A2, B3, A3]
    UpperLimit = [Inf, Inf, Inf, Inf, Inf, Inf];
    StartGuess = [max(LinY), 1, max(LinY), 1, max(LinY), 1];
    [Fit{3}, GOF{3}] = fit(LinX, LinY, FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess);
    % Choose best fit
    SummedSquaresError = cellfun(@(x) x.sse, GOF);
    ExtraParameterPunishment = 1.1; % a fit with an extra parameter should have at least 10% smaller sse
    if SummedSquaresError(1) < SummedSquaresError(2) * ExtraParameterPunishment
        NumberOfDecays = 1;
    elseif SummedSquaresError(2) < SummedSquaresError(3) * ExtraParameterPunishment
        NumberOfDecays = 2;
    else
        NumberOfDecays = 3;
    end
end