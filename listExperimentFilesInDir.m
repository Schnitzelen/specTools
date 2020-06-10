function FileList = listExperimentFilesInDir(varargin)
    % Default arguments
    AbsoluteFolder = pwd();
    ExperimentType = '*';
    FileExtension = '*';
    IncludeSubfolders = false;
    OnlyNewestUniqueSolvents = false;
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'AbsoluteFolder'
                AbsoluteFolder = varargin{i + 1};
            case 'ExperimentType'
                ExperimentType = varargin{i + 1};
            case 'FileExtension'
                FileExtension = varargin{i + 1};
            case 'IncludeSubfolders'
                IncludeSubfolders = varargin{i + 1};
            case 'OnlyNewestUniqueSolvents'
                OnlyNewestUniqueSolvents = varargin{i + 1};
            otherwise
                error('Unknown Argument Passed: %s', varargin{i})
        end
    end
    FileNameTemplate = strcat('*_', ExperimentType, '_*', '.', FileExtension);
    if IncludeSubfolders
        FileNameTemplate = fullfile(AbsoluteFolder, '**', FileNameTemplate);
    else
        FileNameTemplate = fullfile(AbsoluteFolder, FileNameTemplate);
    end
    FileList = dir(FileNameTemplate);
    if OnlyNewestUniqueSolvents
        [~, FileNames, ~] = cellfun(@(x) fileparts(x), {FileList.name}', 'UniformOutput', false);
        [Date, ~, ~, Solvents, ~, ~] = cellfun(@(x) readInformationFromFileName(x), FileNames, 'UniformOutput', false);
        UniqueSolvents = unique(Solvents);
        SolventIdx = cellfun(@(x) find(strcmp(Solvents, x)), UniqueSolvents, 'UniformOutput', false);
        [~, NewestDateIdx] = cellfun(@(x) max(str2double(Date(x))), SolventIdx);
        Idx = cellfun(@(s, d) s(d), SolventIdx, num2cell(NewestDateIdx));
        FileList = FileList(Idx);
    end
    FileList = arrayfun(@(x) fullfile(x.folder, x.name), FileList, 'UniformOutput', false);
end