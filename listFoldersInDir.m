function D = listFoldersInDir(AbsolutePath)
    % If AbsolutePath is not set, set default
    if ~exist('AbsolutePath', 'var')
        AbsolutePath = pwd();
    end
    D = dir(AbsolutePath);
    % Drop entries that are not directories
    D = D([D.isdir]);
    % Drop entries that are '.' and '..'
    D = D(~strcmp({D.name}, '.'));
    D = D(~strcmp({D.name}, '..'));
    % Convert to absolute folder paths
    D = arrayfun(@(x) fullfile(x.folder, x.name), D, 'UniformOutput', false);
end
    
    
    