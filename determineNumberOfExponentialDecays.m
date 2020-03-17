function NumberOfDecays = determineNumberOfExponentialDecays(X, Y)
    % Preprocess data
    if min(X) < 10^-6
        LinX = X * 10^9; % fits seem to terminate early due to very small x
    else
        LinX = X;
    end
    LinY = log(double(Y));
    % Set up fitting parameters
    Start.B1 = max(LinY);
    Start.A1 = (max(LinY) - min(LinY)) / (max(LinX) - min(LinX)) * 100;
    Start.B2 = Start.B1 / 2;
    Start.A2 = Start.A1 / 10;
    Start.B3 = Start.B2 / 2;
    Start.A3 = Start.A2 / 10;
    Min.B = 0;
    Min.A = 0;
    Max.B = Inf;
    Max.A = Inf;
    % Do linear fit expecting one decay
    FitType = fittype('B1 - A1 * x', 'Coefficients', {'B1', 'A1'}, 'Independent', {'x'}, 'Dependent', {'y'});
    LowerLimit = [Min.B, Min.A]; % [B1, A1]
    UpperLimit = [Max.B, Max.A];
    StartGuess = [Start.B1, Start.A1];
    [Fit{1}, GOF{1}] = fit(LinX, LinY, FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess);
    % Do linear fit expecting two decays
    FitType = fittype('B1 - A1 * x + B2 - A2 * x', 'Coefficients', {'B1', 'A1', 'B2', 'A2'}, 'Independent', {'x'}, 'Dependent', {'y'});
    LowerLimit = [Min.B, Min.A, Min.B, Min.A]; % [B1, A1, B2, A2]
    UpperLimit = [Max.B, Max.A, Max.B, Max.A];
    StartGuess = [Start.B1, Start.A1, Start.B2, Start.A2];
    [Fit{2}, GOF{2}] = fit(LinX, LinY, FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess);
    % Do linear fit expecting three decays
    FitType = fittype('B1 - A1 * x + B2 - A2 * x + B3 - A3 * x', 'Coefficients', {'B1', 'A1', 'B2', 'A2', 'B3', 'A3'}, 'Independent', {'x'}, 'Dependent', {'y'});
    LowerLimit = [Min.B, Min.A, Min.B, Min.A, Min.B, Min.A]; % [B1, A1, B2, A2, B3, A3]
    UpperLimit = [Max.B, Max.A, Max.B, Max.A, Max.B, Max.A];
    StartGuess = [Start.B1, Start.A1, Start.B2, Start.A2, Start.B3, Start.A3];
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
    % Attempt another way
    
%     % Do linear fit expecting one decay
%     FitType = fittype('B1 - A1 * x', 'Coefficients', {'B1', 'A1'}, 'Independent', {'x'}, 'Dependent', {'y'});
%     LowerLimit = [Min.B, Min.A]; % [B1, A1]
%     UpperLimit = [Max.B, Max.A];
%     StartGuess = [Start.B1, Start.A1];
%     Idx = 5;
%     for i = Idx:length(X)
%     [Fit{i}, GOF{i}] = fit(LinX(1:Idx), LinY(1:Idx), FitType, 'Lower', LowerLimit, 'Upper', UpperLimit, 'StartPoint', StartGuess);
%     end
%     GOF = GOF(5:end);
%     Fit = Fit(5:end);
%     SummedSquaresError = cellfun(@(x) x.A1, Fit);
%     while 
end