classdef TPExExperiment < handle
    properties
        Title
        Date
        Type
        Solvent
        Concentration
        Compound
        SampleFiles
        ReferenceFolder
        TableValuePath
        TableValueFound
        TableValue
        Sample
        Reference
        Data
    end
    methods 
        function obj = TPExExperiment(varargin)
            % Prepare arguments
            obj.TableValuePath = fullfile(getenv('userprofile'), '\Documents\Matlab\SpecTools\');
            obj.SampleFiles = {};
            obj.ReferenceFolder = '';
            % Handle varargin
            assert(rem(length(varargin), 2) == 0, 'Arguments Cannot Be Parsed');
            for i = 1:2:length(varargin)
                switch varargin{i}
                    case 'SampleFiles'
                        obj.SampleFiles = varargin{i + 1};
                    case 'ReferenceFolder'
                        obj.ReferenceFolder = varargin{i + 1};
                    case 'TableValuePath'
                        obj.TableValuePath = varargin{i + 1};
                    otherwise
                        error('Unknown Argument Passed: %s', varargin{i})
                end
            end
            % If any arguments are not defined by now, prompt user
            if isempty(obj.SampleFiles)
                [File, Path] = uigetfile('*_2pa_*.txt', 'Please Select 2P Data to Import', 'MultiSelect', 'on');
                assert(isa(Path, 'char') & ~isempty(File), 'No File Selected!')
                obj.SampleFiles = fullfile(Path, File);
            end
            if isempty(obj.ReferenceFolder)
                obj.ReferenceFolder = uigetdir(pwd(), 'Please Choose 2PEx Reference Folder');
            end
            assert(isa(obj.ReferenceFolder, 'char'), 'No Sample Selected!')
            % Import and handle data
            obj.readInfoFromFileName()
            obj.importSampleData()
            obj.importReferenceData()
            obj.lookUpReferenceTableValueTPA()
            if obj.TableValueFound
                obj.buildDataTable()
            end
        end
        function readInfoFromFileName(obj)
            [~, FileNames, ~] = cellfun(@(x) fileparts(x), obj.SampleFiles, 'UniformOutput', false);
            FileNames = regexp(FileNames, '_', 'split');
            Date = unique(cellfun(@(x) x{1}, FileNames, 'UniformOutput', false));
            assert(length(Date) == 1, 'Multiple Sample Dates Detected!')
            obj.Date = Date{:};
            Type = unique(cellfun(@(x) x{2}, FileNames, 'UniformOutput', false));
            assert(length(Type) == 1, 'Multiple Sample Types Detected!')
            obj.Type = Type{:};
            Solvent = unique(cellfun(@(x) x{3}, FileNames, 'UniformOutput', false));
            assert(length(Solvent) == 1, 'Multiple Sample Solvents Detected!')
            obj.Solvent = Solvent{:};
            Concentration = unique(cellfun(@(x) x{4}, FileNames, 'UniformOutput', false));
            assert(length(Concentration) == 1, 'Multiple Sample Concentrations Detected!')
            [obj.Concentration.Value, obj.Concentration.Unit] = splitStringIntoValueAndUnit(Concentration{:});
            Compound = unique(cellfun(@(x) x{5}, FileNames, 'UniformOutput', false));
            assert(length(Compound) == 1, 'Multiple Sample Compounds Detected!')
            obj.Compound = Compound{:};
            obj.Title = strjoin(FileNames{1}(1:5), '_');
        end
        function importSampleData(obj)
            obj.Sample = read2PEx('SampleFiles', obj.SampleFiles);
        end
        function importReferenceData(obj)
            DataFolder = fullfile(obj.ReferenceFolder, 'data');
            ReferenceFiles = listExperimentFilesInDir('AbsoluteFolder', DataFolder, 'ExperimentType', '2pa');
            ReferenceDate = regexp(ReferenceFiles, '(?<=data\\)[\d,\-]+?(?=_)', 'match');
            ReferenceDate = vertcat(ReferenceDate{:});
            Idx = strcmp(ReferenceDate, obj.Date);
            assert(any(Idx), 'No Reference Data Located For %s', obj.Title)
            obj.Reference = read2PEx('SampleFiles', ReferenceFiles(Idx));
        end
        function lookUpReferenceTableValueTPA(obj)
            FileName = fullfile(obj.TableValuePath, ['tpa_reference_', obj.Reference.Solvent, '_', obj.Reference.Compound, '.csv']);
            IsFile = isfile(FileName);
            if IsFile
                obj.TableValueFound = true;
                obj.TableValue = readtable(FileName);
            else
                obj.TableValueFound = false;
                warning('No 2PA Table Value For %s in %s', obj.Reference.Compound, obj.Reference.Solvent)
            end
        end
        function buildDataTable(obj)
            % Determine excitation wavelength overlap
            MeasuredWavelength = obj.Sample.Data.Wavelength;
            TableWavelength = obj.TableValue.Wavelength;
            Idx = arrayfun(@(w) any(MeasuredWavelength == w), TableWavelength);
            % Build data table
            obj.Data = cell2table(cell(length(TableWavelength(Idx)), 3), 'VariableNames', {'Wavelength', 'MeanActionPotential', 'SDActionPotential'});
            obj.Data.Wavelength = TableWavelength(Idx);
            % Fetch concentrations
            Factor = [10^0, 10^-3, 10^-6, 10^-9];
            Unit = {'M', 'mM', 'uM', 'nM'};
            ReferenceConcentration = obj.Reference.Concentration.Value * Factor(strcmp(Unit, obj.Reference.Concentration.Unit));
            SampleConcentration = obj.Sample.Concentration.Value * Factor(strcmp(Unit, obj.Sample.Concentration.Unit));
            % Calculate action potential
            ReferenceTableValue = arrayfun(@(w) obj.TableValue.TPA(obj.TableValue.Wavelength == w), obj.Data.Wavelength);
            ReferenceContribution = arrayfun(@(w) obj.Reference.Data.MeanCorrectedIntensity(obj.Reference.Data.Wavelength == w) / ReferenceConcentration, obj.Data.Wavelength);
            SampleContribution = arrayfun(@(w) obj.Sample.Data.MeanCorrectedIntensity(obj.Sample.Data.Wavelength == w) / SampleConcentration, obj.Data.Wavelength);
            obj.Data.MeanActionPotential = round(SampleContribution ./ ReferenceContribution .* ReferenceTableValue, 4, 'significant');
            ReferenceContribution = arrayfun(@(w) obj.Reference.Data.SDCorrectedIntensity(obj.Reference.Data.Wavelength == w) / ReferenceConcentration, obj.Data.Wavelength);
            SampleContribution = arrayfun(@(w) obj.Sample.Data.SDCorrectedIntensity(obj.Sample.Data.Wavelength == w) / SampleConcentration, obj.Data.Wavelength);
            obj.Data.SDActionPotential = round(SampleContribution ./ ReferenceContribution .* ReferenceTableValue, 4, 'significant');
        end
    end
end

        
        