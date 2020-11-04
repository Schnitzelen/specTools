function SubFolders = getSubFolders(Path)
    % If Path is not provided, use pwd
    if ~exist('Path', 'var')
        Path = pwd();
    end
    D = dir(Path);
    SubFolders = arrayfun(@(x) fullfile(x.folder, x.name), D, 'UniformOutput', false);
    IsFile = arrayfun(@(x) contains(x.name, '.'), D);
    IsFolder = cellfun(@(x) isfolder(x), SubFolders);
    KeepIdx = ~IsFile & IsFolder;
    SubFolders = SubFolders(KeepIdx);
end
    