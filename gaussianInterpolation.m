function gaussianInterpolation(X, Y, NormalizeEndpoints)
    % Function assumes equally spaced x- and y-values with NaNs to be
    % replaced by the interpolation. If normalizeEndpoints is true,
    % function attempts to estimate a baseline to subtract from data before
    % fitting
    % Convert values to double to avoid problems with calculations later on
    X = double(X);
    Y = double(Y);
    % Smooth data
    %Y = smooth(Y);
    scatter(X, Y)
    if NormalizeEndpoints
        % Calculate baseline and normalize data
        
    end
    %scatter(
end