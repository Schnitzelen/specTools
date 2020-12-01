function generateLatexReport(varargin)
    % Default arguments
    SampleFolder = {};
    % Handle varargin
    assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'SampleFolder'
                SampleFolder = varargin{i + 1};
            otherwise
                error('Unknown Argument Passed: %s', varargin{i})
        end
    end
    % If any arguments are not defined by now, prompt user
    if isempty(SampleFolder)
        SampleFolder = uigetdir(pwd(), 'Please Select Folder Containing Data to Import');
        assert(isa(SampleFolder, 'char'), 'No Folder Selected!');
    end
    [~, SampleName, ~] = fileparts(SampleFolder);
    % Prepare report text
    Report = cell(0, 1);
    % If present, include image of structure
    FileName = fullfile(SampleFolder, 'structure.png');
    if isfile(FileName)
        Report{end+1, 1} = ['The chemical structure of ', SampleName, ' is shown below.'];
        Report{end+1, 1} = '\begin{figure}';
        Report{end+1, 1} = '\centering';
        FileName = strsplit(FileName, filesep);
        FileName = strjoin([{'..'}, FileName(end-2:end)], '/');
        Report{end+1, 1} = ['\includegraphics[width=0.5\textwidth]{', FileName, '}'];
        Report{end+1, 1} = ['\caption{Chemical structure of ', SampleName, '.}'];
        Report{end+1, 1} = '\end{figure}';
    end
    % If present, include image of spectra
    FileName = fullfile(SampleFolder, 'spectra.png');
    if isfile(FileName)
        Report{end+1, 1} = ['The spectra of ', SampleName, ' are shown below.'];
        Report{end+1, 1} = '\begin{figure}';
        Report{end+1, 1} = '\centering';
        FileName = strsplit(FileName, filesep);
        FileName = strjoin([{'..'}, FileName(end-2:end)], '/');
        Report{end+1, 1} = ['\includegraphics[width=\textwidth]{', FileName, '}'];
        Report{end+1, 1} = ['\caption{Excitation (dotted line), absorption (dashed line) and emission (full line) spectra of ', SampleName, '.}'];
        Report{end+1, 1} = '\end{figure}';
    end
    % If present, include table of spectral results
    FileName = fullfile(SampleFolder, 'spectral_peaks.csv');
    if isfile(FileName)
        Report{end+1, 1} = ['The wavelength of the spectral peaks of ', SampleName, ' are presented in the table below.'];
        Report{end+1, 1} = '\begin{table}';
        Report{end+1, 1} = '\centering';
        Report{end+1, 1} = '\begin{tabular}{c | c c c c c c c c}';
        Report{end+1, 1} = 'solvent & rel. pol. & $\lambda_{ex}$ & $\Delta \lambda_{ex}$ & $\lambda_{abs}$ & $\Delta \lambda_{abs}$ & $\lambda_{em}$ & $\Delta \lambda_{em}$ & Stokes shift \\ \hline';
        T = readtable(FileName);
        NumCols = width(T);
        NumRows = height(T);
        for r = 1:NumRows
            Row = sprintf('%s\t', string(T{r, 1}));
            for c = 2:(NumCols - 1)
                Row = [Row, sprintf('& %s\t', string(T{r, c}))];
            end
            Row = [Row, sprintf('& %s', string(T{r, NumCols}))];
            if r < NumRows
                Row = [Row, ' \\'];
            end
            Report{end+1, 1} = Row;
        end
        Report{end+1, 1} = '\end{tabular}';
        Report{end+1, 1} = ['\caption{Peak wavelengths of ', SampleName, ' in units of \textit{nanometer}.}'];
        Report{end+1, 1} = '\end{table}';
    end
    % If present, include plot of spectral results
    FileName = fullfile(SampleFolder, 'spectral_results.png');
    if isfile(FileName)
        Report{end+1, 1} = ['A normalized plot of the peak wavelengths of ', SampleName, ' relative to the polarity of the solvent is shown below.'];
        Report{end+1, 1} = '\begin{figure}';
        Report{end+1, 1} = '\centering';
        FileName = strsplit(FileName, filesep);
        FileName = strjoin([{'..'}, FileName(end-2:end)], '/');
        Report{end+1, 1} = ['\includegraphics[width=\textwidth]{', FileName, '}'];
        Report{end+1, 1} = ['\caption{Normalized peak wavelengths of ', SampleName, ' relative to solvent polarity.}'];
        Report{end+1, 1} = '\end{figure}';
    end
    % If present, include table of physical properties
    FileName = fullfile(SampleFolder, 'physical_properties.csv');
    if isfile(FileName)
        Report{end+1, 1} = ['Some physical properties of ', SampleName, ' are presented in the table below.'];
        Report{end+1, 1} = '\begin{table}';
        Report{end+1, 1} = '\centering';
        Report{end+1, 1} = '\begin{tabular}{c | c c c }';
        Report{end+1, 1} = 'solvent & $\tau_{f}$ (ps) & $\phi_{f}$ & $\epsilon$ $\unit{(M^{-1} cm^{-1})}$ \\ \hline';
        T = readtable(FileName);
        NumCols = width(T);
        NumRows = height(T);
        for r = 1:NumRows
            Row = sprintf('%s\t', string(T{r, 1}));
            c = 2;
            if strcmp('NA', string(T{r, c}))
                Row = [Row, sprintf('& %s\t', string(T{r, c}))];
            else
                Val = string(T{r, c});
                SD = string(T{r, c+1});
                if strcmp(SD, '0')
                    Row = [Row, sprintf('& %s\t', Val)];
                else
                    Row = [Row, sprintf('& $%s %s %s$\t', Val, '\pm', SD)];
                end
            end
            c = 4;
            if strcmp('NA', string(T{r, c}))
                Row = [Row, sprintf('& %s\t', string(T{r, c}))];
            else
                Val = str2double(T{r, c});
                SD = str2double(T{r, c+1});
                if SD == 0
                    Row = [Row, sprintf('& %0.4f\t', Val)];
                else
                    Row = [Row, sprintf('& $%0.4f %s %0.4f$\t', Val, '\pm', SD)];
                end
            end
            Row = [Row, sprintf('& $%s %s %s$', string(T{r, NumCols-1}), '\pm', string(T{r, NumCols}))];
            if r < NumRows
                Row = [Row, ' \\'];
            end
            Report{end+1, 1} = Row;
        end
        Report{end+1, 1} = '\end{tabular}';
        Report{end+1, 1} = ['\caption{Some physical properties of ', SampleName, '. Where possible, standard deviation is indicated by $\pm$.}'];
        Report{end+1, 1} = '\end{table}';
    end
    % If present, include plot of 2P excitation
    FileName = fullfile(SampleFolder, '2PEx.png');
    if isfile(FileName)
        Report{end+1, 1} = ['The two-photon excitation spectra of ', SampleName, ' are shown below.'];
        Report{end+1, 1} = '\begin{figure}';
        Report{end+1, 1} = '\centering';
        Report{end+1, 1} = ['\includegraphics[width=\textwidth]{', strrep(FileName, '\', '/'), '}'];
        Report{end+1, 1} = ['\caption{Two-photon excitation spectra of ', SampleName, '.}'];
        Report{end+1, 1} = '\end{figure}';
    end
    % Save report
    Report = regexprep(Report, '\\', '\\\\'); % Convert single backslash
    Report = join(Report, '\n'); % Add newline characters
    FileName = fullfile(SampleFolder, 'spectroscopic_report.tex');
    FID = fopen(FileName, 'w');
    fprintf(FID, Report{1});
    fclose(FID);
end