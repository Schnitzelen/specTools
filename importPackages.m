function importPackages(PackageNameList)
    if isa(PackageNameList, 'char')
        PackageNameList = {PackageNameList};
    end
    if ismac
        error('Not Yet Available for Mac');
    elseif isunix
        Path = '/home/brian/Documents/MATLAB';
    elseif ispc
        Path = 'C:\Users\brianbj\Documents\MATLAB\';
    end
    for i = 1:length(PackageNameList)
        addpath(fullfile(Path, PackageNameList{i}));
    end
end