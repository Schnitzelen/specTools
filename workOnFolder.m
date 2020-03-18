function workOnFolder(FolderPath, FileType, FunctionName, FunctionArguments)
    % Locate files in folder
    D = dir(fullfile(FolderPath, strcat('*_', FileType, '_*')));
    D = arrayfun(@(x) fullfile(x.folder, x.name), D, 'UniformOutput', false);
    % Run function on each file
    FunctionHandle = str2func(FunctionName);
    for i = 1:length(D)
        FunctionHandle(FunctionArguments)
    end
end