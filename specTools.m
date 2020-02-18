function specTools(Path)
    % Ask for path, if none is provided
    if ~exist('Path', 'var')
        Path = uigetdir(pwd(), 'Please Select Folder Containing Data to Analyze');
    end
    assert(ischar(Path), 'No Folder Selected!');
    % Absorption
    AbsFiles = dir(fullfile(Path, '/data/*_abs_*'));
    if ~isempty(AbsFiles)
        AbsWrap = wrapAbs(fullfile(Path, '/data/'));
        Fig = AbsWrap.plotResults();
        print(Fig, fullfile(Path, 'abs_plot'), '-dpng');
        writetable(AbsWrap.Results, fullfile(Path, 'abs_results.csv'));
    end
    % Excitation
    ExFiles = dir(fullfile(Path, '/data/*_ex_*'));
    if ~isempty(ExFiles)
        ExWrap = wrapEx(fullfile(Path, '/data/'));
        Fig = ExWrap.plotResults();
        print(Fig, fullfile(Path, 'ex_plot'), '-dpng');
        writetable(ExWrap.Results, fullfile(Path, 'ex_results.csv'));
    end
    % Emission
    EmFiles = dir(fullfile(Path, '/data/*_em_*'));
    if ~isempty(EmFiles)
        EmWrap = wrapEm(fullfile(Path, '/data/'));
        Fig = EmWrap.plotResults();
        print(Fig, fullfile(Path, 'em_plot'), '-dpng');
        writetable(EmWrap.Results, fullfile(Path, 'em_results.csv'));
    end
    % Molar attenuation coefficient
    QyAbsFiles = dir(fullfile(Path, '/data/*_qy_*.TXT'));
    if ~isempty(QyAbsFiles)
        Mac = wrapMAC(fullfile(Path, '/data/'));
        Mac.plotResults();
        writetable(Mac.Results, fullfile(Path, 'mac_results.csv'));
    end
    % Quantum yield
    QyEmFiles = dir(fullfile(Path, '/data/*_qy_*.ifx'));
    if ~isempty(QyAbsFiles) && ~isempty(QyEmFiles)
        try
            Qy = wrapQY(fullfile(Path, '/data/'));
            Qy.plotSpectralOverlap();
            Qy.plotRaw();
            writetable(Qy.Results, fullfile(Path, 'qy_results.csv'));
        end
    end
    % Two-photon excitation
    TPAFiles = dir(fullfile(Path, '/data/*_2pa_*.txt'));
    if ~isempty(TPAFiles)
        TPA = wrap2PEx(Path);
    end
    % Fluorescence lifetime image analysis
    FLIMFiles = dir(fullfile(Path, 'data', '*_FLIM_*'));
    if ~isempty(FLIMFiles)
        FLIM = wrapFLIM(Path);
    end
end