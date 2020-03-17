function Obj = readFLIM(AbsoluteFileName, Binning, NumberOfDecays, ForceFitOnAllPixels)
    % Ask for file, if none is provided
    if ~exist('AbsoluteFileName', 'var')
        [File, Path] = uigetfile('*_FLIM_*', 'Please Select Data To Import');
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
    % Determine and use reader
    [~, ~, Ext] = fileparts(AbsoluteFileName);
    switch Ext
        case '.sdt'
            Obj = readSdt(AbsoluteFileName, Binning, NumberOfDecays, ForceFitOnAllPixels);
        case '.msr'
            Obj = readMsd(AbsoluteFileName, Binning, NumberOfDecays, ForceFitOnAllPixels);
        otherwise
            error('Cannot Handle File Type %s', Ext)
    end
end