function quantumYieldComparison(varargin)
    % Confirm that all arguments come in pairs
    assert(rem(length(varargin), 2) == 0, 'Wrong number of arguments');
    % Set provided arguments
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'SampleFolders'
                SampleFolders = varargin{i + 1};
            case 'Solvent'
                Solvent = varargin{i + 1};
            case 'ReferenceFolder'
                ReferenceFolder = varargin{i + 1};
        end
    end
    % If any arguments are not defined by now, prompt the user
    if ~exist('SampleFolders')
        SampleFolders = cell(0);
        SampleFolders{1} = uigetdir('C:\Users\brianbj\OneDrive - Syddansk Universitet\Samples', 'Please Choose First Sample Folder');
        Stop = false;
        while ~Stop
            SampleFolder = uigetdir('C:\Users\brianbj\OneDrive - Syddansk Universitet\Samples', 'Please Choose Next Sample Folder');
            if SampleFolder == 0
                Stop = true;
            else
                SampleFolders = vertcat(SampleFolders, SampleFolder);
            end
        end
    end
    if ~exist('ReferenceFolder')
        ReferenceFolder = uigetdir('C:\Users\brianbj\OneDrive - Syddansk Universitet\Samples', 'Please Choose Reference Folder');
    end
    if ~exist('Solvent')
        Solvent = input('Please Specify Solvent(s) (separate multiple solvents by blank space): ', 's');
    end
    if contains(Solvent, ' ')
        Solvent = strsplit(Solvent, ' ');
    else
        Solvent = {Solvent};
    end
    for i = 1:length(Solvent)
        % Determine wavelength with optimal absorption overlap
        estimateOptimalAbsorptionOverlap('SampleFolders', SampleFolders, 'Solvent', Solvent{i}, 'ReferenceFolder', ReferenceFolder);
        % Determine wavelength with optimal emission overlap
        estimateOptimalEmissionOverlap('SampleFolders', SampleFolders, 'Solvent', Solvent{i}, 'ReferenceFolder', ReferenceFolder);
    end
end