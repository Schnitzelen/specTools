function planQuantumYieldExperiment(varargin)    
    % Prepare arguments
    SampleFolder = {};
    Solvent = {};
    ReferenceFolder = {};
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'SampleFolder'
                SampleFolder = varargin{i + 1};
                if isa(SampleFolder, 'char')
                    SampleFolder = {SampleFolder};
                end
            case 'Solvent'
                Solvent = varargin{i + 1};
                if isa(Solvent, 'char')
                    Solvent = {Solvent};
                end
            case 'ReferenceFolder'
                ReferenceFolder = varargin{i + 1};
                ReferenceFolder = {ReferenceFolder};
            otherwise
                error('Unknown Argument Passed: %s', varargin{i})
        end
    end
    % If any arguments are not defined by now, prompt user
    if isempty(SampleFolder)
        SampleFolder{1} = uigetdir(pwd(), 'Please Choose Sample Folder');
%         SampleFolder = cell(0);
%         Folder = uigetdir(pwd(), 'Please Choose First Sample Folder');
%         while isa(Folder, 'char')
%             SampleFolder = vertcat(SampleFolder, Folder);
%             Folder = uigetdir(pwd(), 'Please Choose Next Sample Folder');
%         end
    end
    assert(~isempty(SampleFolder) && ~isempty(SampleFolder{1}), 'No Sample Selected!')
    if isempty(ReferenceFolder)
        %ReferenceFolder{1} = 'C:\Users\schni\OneDrive - Syddansk Universitet\Samples\NR';
        ReferenceFolder{1} = uigetdir(pwd(), 'Please Choose Reference Folder');
    end
    assert(~isempty(ReferenceFolder) && ~isempty(ReferenceFolder{1}), 'No Reference Selected!')
    if isempty(Solvent)
        Solvent = 'MeOH TCM Tol';
        %Solvent = input('Please Specify Solvent(s) (separate multiple solvents by space): ', 's');
        if contains(Solvent, ' ')
            Solvent = strsplit(Solvent, ' ');
        elseif isa(Solvent, 'char')
            Solvent = {Solvent};
        end
    end
    assert(~isempty(Solvent) && ~isempty(Solvent{1}), 'No Solvent Specified!')
    % Build report text
    [AbsReport, AbsFig] = estimateOptimalAbsorptionOverlap('SampleFolder', SampleFolder, 'SampleSolvent', Solvent, 'ReferenceFolder', ReferenceFolder);
    print(AbsFig, fullfile(SampleFolder{1}, 'QY_absorption.jpg'), '-djpeg')
    [EmReport, EmFig] = estimateOptimalEmissionOverlap('SampleFolder', SampleFolder, 'SampleSolvent', Solvent, 'ReferenceFolder', ReferenceFolder);
    print(EmFig, fullfile(SampleFolder{1}, 'QY_emission.jpg'), '-djpeg')
    Report = horzcat(AbsReport, EmReport);
    disp(Report)
    FID = fopen(fullfile(SampleFolder{1}, 'QY_plan.txt'), 'w');
    fprintf(FID, Report);
    fclose(FID);
    % Show and save report
    
end