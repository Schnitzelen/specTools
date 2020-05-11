function [Low, Peak, High] = determineSpectralRange(Wavelength, Intensity, varargin)
    % Default arguments
    Threshold = 0.05;
    PeakExpectedAbove = 350;
    % Prepare returned values
    Low = NaN;
    Peak = NaN;
    High = NaN;
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'Threshold'
                Threshold = varargin{i + 1};
            case 'PeakExpectedAbove'
                PeakExpectedAbove = varargin{i + 1};
            otherwise
                error('Unknown Argument Passed: %s', varargin{i})
        end
    end
    % Cut X
    Idx = PeakExpectedAbove <= Wavelength;
    Wavelength = Wavelength(Idx);
    Intensity = Intensity(Idx);
    % Find max
    [MaxY, MaxYIdx] = max(Intensity);
    Peak = Wavelength(MaxYIdx);
    % Normalize Y
    NormY = Intensity / MaxY;
    % Find peak
    Idx = MaxYIdx;
    while Idx > 0
        if NormY(Idx) <= Threshold
            Low = Wavelength(Idx);
            break
        end
        Idx = Idx - 1;
    end
    Idx = MaxYIdx;
    while Idx <= length(Wavelength)
        if NormY(Idx) <= Threshold
            High = Wavelength(Idx);
            break
        end
        Idx = Idx + 1;
    end
end