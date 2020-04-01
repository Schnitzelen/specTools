function D = listExperimentFilesInDir(AbsolutePath, ExperimentType, FileExtension)
    % If not AbsolutePath is set, set default
    if ~exist('AbsolutePath', 'var')
        AbsolutePath = pwd();
    end
    % If not ExperimentType is set, ask for it
    if ~exist('ExperimentType', 'var')
        ExperimentType = input('Please Input Experiment Type:\n', 's');
    end
    % If not FileExtension is set, set default
    if ~exist('FileExtension', 'var')
        FileExtension = '*';
    elseif strcmp(FileExtension(1), '.')
        FileExtension = FileExtension(2:end);
    end
    FileNameTemplate = strcat('*_', ExperimentType, '_*', '.', FileExtension);
    D = dir(fullfile(AbsolutePath, FileNameTemplate));
    D = arrayfun(@(x) fullfile(x.folder, x.name), D, 'UniformOutput', false);
end