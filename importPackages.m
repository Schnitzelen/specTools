function importPackages(PackageNameList)
    if isa(PackageNameList, 'char')
        PackageNameList = {PackageNameList};
    end
    Path = char(java.lang.System.getProperty('user.home'));
    Path = fullfile(Path, 'Documents', 'MATLAB');
    for i = 1:length(PackageNameList)
        PackageFolder = fullfile(Path, PackageNameList{i});
        if isfolder(PackageFolder)
            addpath(fullfile(Path, PackageNameList{i}));
        else
            error('Could Not Locate Package: \n%s', PackageFolder);
        end
    end
end