% By Brian Bjarke Jensen (schnitzelen@gmail.com) 22/8-2018

classdef QuantumYield < handle
    events
        PropertyUpdatedEvent
    end
    properties
        DataFolderPath
        SavePath
        FluorescenceData
        EmissionData
        AbsorptionData
        ProbeNameList
        DataTable
        GradientTable
        QuantumYieldReferenceTable
        RefractiveIndexReferenceTable
        QuantumYieldResultsTable
    end
    properties (SetObservable, AbortSet)
        AbsorptionReferenceList
    end
    methods (Static)
        function obj = QuantumYield(DataFolderPath)
            % Ask for path if none is provided
            if ~exist('DataFolderPath', 'var')
                DataFolderPath = uigetdir(getenv('USERPROFILE'), 'Select data folder');
            end
            obj.DataFolderPath = DataFolderPath;
            SavePath = strsplit(DataFolderPath, '\');
            SavePath = strjoin({SavePath{1:end-2}}, '\');
            obj.SavePath = strcat(SavePath, '\');
            obj.ImportReferenceData()
            obj.ImportFluorescenceData()
            if ~isempty(obj.FluorescenceData)
                %obj.PlotFluorescenceData()
            end
            obj.ImportEmissionData()
            if ~isempty(obj.EmissionData)
                %obj.PlotEmissionData()
            end
            obj.ImportAbsorptionData()
            obj.BuildProbeNameList()
            obj.CalculateCorrectedAbsorption()
            %obj.PlotCorrectedAbsorption()
            %obj.BuildAbsorptionReferenceList()
            obj.BuildDataTable()
            obj.CalculateGradients()
            obj.CalculateQuantumYield()
            addlistener(obj, 'AbsorptionReferenceList', 'PostSet', @obj.PropertyUpdated);
        end
        function PropertyUpdated(src, evnt)
            switch src.Name
                case 'AbsorptionReferenceList'
                    evnt.AffectedObject.CalculateCorrectedAbsorption()
                    evnt.AffectedObject.PlotCorrectedAbsorption()
                    evnt.AffectedObject.BuildDataTable()
                    evnt.AffectedObject.CalculateGradients()
                    evnt.AffectedObject.PlotGradients()
            end
        end
    end
    methods
        function ImportReferenceData(obj) % works
            ImportPath = strcat(getenv('USERPROFILE'), '\Documents\MATLAB\quantumyield\');
            obj.QuantumYieldReferenceTable = readtable(strcat(ImportPath, 'ref_quantum_yield.csv'), 'Delimiter', ',');
            obj.RefractiveIndexReferenceTable = readtable(strcat(ImportPath, 'ref_refractive_index.csv'), 'Delimiter', ',');
        end
        function ImportFluorescenceData(obj) % works
            D = dir(strcat(obj.DataFolderPath, '\*_fluo_*.ifx'));
            if isempty(D)
                disp('No fluorescence data located.');
            else
                List = {D(:).name}.';
                for i = 1:length(List)
                    Name = strsplit(List{i}, '_fluo_');
                    List{i} = Name{end};
                end
                [~, SortingIndex] = sortrows(List);
                D = strcat({D.folder}.', repmat('\', length(D), 1), {D.name}.');
                D = D(SortingIndex);
                for i = 1:length(D)
                    obj.FluorescenceData{i} = ReadIfx(D{i});
                end
            end
        end
        function ImportEmissionData(obj) % works
            D = dir(strcat(obj.DataFolderPath, '\*em*.ifx'));
            if isempty(D)
                disp('No emission data could be found in folder, please make sure that filenames contain "em".');
                return
            end
            List = {D(:).name}.';
            for i = 1:length(List)
                Name = strsplit(List{i}, '_em_');
                List{i} = Name{end};
            end
            [~, SortingIndex] = sortrows(List);
            D = strcat({D.folder}.', repmat('\', length(D), 1), {D.name}.');
            D = D(SortingIndex);
            for i = 1:length(D)
                obj.EmissionData{i} = ReadIfx(D{i});
            end
        end
        function ImportAbsorptionData(obj) % works
            D = dir(strcat(obj.DataFolderPath, '\*abs*.TXT'));
            if isempty(D)
                disp('No absorption data could be found in folder, please make sure that filenames contain "abs".');
            end
            List = {D(:).name}.';
            for i = 1:length(List)
                Name = strsplit(List{i}, '_abs_');
                List{i} = Name{end};
            end
            [~, SortingIndex] = sortrows(List);
            D = strcat({D.folder}.', repmat('\', length(D), 1), {D.name}.');
            D = D(SortingIndex);
            for i = 1:length(D)
                obj.AbsorptionData{i} = ReadAbs(D{i});
            end
        end
        function BuildProbeNameList(obj) % works
            ProbeNameList = {obj.EmissionData{1}.ProbeName};
            if obj.EmissionData{1}.ProbeConcentration == 0
                ProbeNameList{1, 2} = 1;
            end
            a = 2;
            for i = 2:length(obj.EmissionData)
                NameNotInList = ~any(strcmp({ProbeNameList{:, 1}}, obj.EmissionData{i}.ProbeName));
                ProbeConcentrationIsZero = obj.EmissionData{i}.ProbeConcentration == 0;
                if NameNotInList && ProbeConcentrationIsZero
                    ProbeNameList{a, 1} = obj.EmissionData{i}.ProbeName;
                    ProbeNameList{a, 2} = i;
                    a = a + 1;
                end
            end
            obj.ProbeNameList = cell2table(ProbeNameList, 'VariableNames', {'ProbeName', 'EmissionReferenceIndex'});
            Indices = cell(height(obj.ProbeNameList), 1);
            for i = 1:length(obj.AbsorptionData)
                if obj.AbsorptionData{i}.ProbeConcentration == 0
                    ProbeNameIndex = find(contains(obj.ProbeNameList.ProbeName, obj.AbsorptionData{i}.ProbeName));
                    for Index = 1:length(ProbeNameIndex)
                        Indices{ProbeNameIndex(Index)} = i;
                    end
                end
            end
            obj.ProbeNameList.AbsorptionReferenceIndex = Indices;
        end
        function PlotFluorescenceData(obj) % works
            for i = 1:length(obj.FluorescenceData)
                obj.FluorescenceData{i}.PlotEmission()
            end
        end
        function PlotEmissionData(obj) % works
            fig = figure;
            hold on
            title('Normalized Emission Spectra', 'interpreter', 'latex');
            xlabel('Wavelength [nm]', 'interpreter', 'latex');
            ylabel('Intensity [a.u.]', 'interpreter', 'latex');
            a = 1;
            for i = 1:length(obj.EmissionData)
                SampleName = strsplit(obj.EmissionData{i}.Title, '_em_');
                SampleName = strrep(SampleName{end}, '_', ' ');
                if obj.EmissionData{i}.ProbeConcentration ~= 0
                    plot(obj.EmissionData{i}.Data.EmissionWavelength, obj.EmissionData{i}.Data.Intensity, '-', 'LineWidth', 2);
                    LegendText{a} = strrep(SampleName, 'uM', '$\mu$M');
                    a = a + 1;
                end
            end
            colormap(parula(a));
            legend(LegendText, 'interpreter', 'latex');
            set(fig, 'PaperOrientation', 'landscape');
            print(fig, strcat(obj.SavePath, 'em_spectra'), '-dpdf', '-bestfit');
            print(fig, strcat(obj.SavePath, 'em_spectra'), '-dpng');
            hold off
        end
        function CalculateCorrectedAbsorption(obj) % works
            for i = 1:length(obj.AbsorptionData)
                ReferenceIndex = contains(obj.ProbeNameList.ProbeName, obj.AbsorptionData{i}.ProbeName);
                ReferenceIndex = obj.ProbeNameList.AbsorptionReferenceIndex(ReferenceIndex);
                ReferenceIndex = ReferenceIndex{1};
                obj.AbsorptionData{i}.CalculateCorrectedAbsorption(obj.AbsorptionData{ReferenceIndex}.Data.Absorption);
            end
        end
        function PlotCorrectedAbsorption(obj) % works
            fig = figure;
            hold on
            title('Absorption Spectra', 'interpreter', 'latex');
            xlabel('Wavelength [nm]', 'interpreter', 'latex');
            ylabel('Absorption [a.u.]', 'interpreter', 'latex');
            Color = colormap(parula(length(obj.AbsorptionData)));
            WavelengthLimitHigh = max(obj.AbsorptionData{1}.Data.Wavelength);
            WavelengthLimitLow = min(obj.AbsorptionData{1}.Data.Wavelength);
            for i = 1:length(obj.AbsorptionData)
                plot(obj.AbsorptionData{i}.Data.Wavelength, obj.AbsorptionData{i}.Data.CorrectedAbsorption, '-', 'Color', Color(i, :), 'LineWidth', 2);
                SampleName = strsplit(obj.AbsorptionData{i}.Sample, '_abs_');
                SampleName = strsplit(SampleName{end}, '.TXT');
                SampleName = strrep(SampleName{1}, '_', ' ');
                SampleName = strrep(SampleName, ',', '.');
                LegendText{i} = strrep(SampleName, 'uM', ' $\mu$M');
                WavelengthPadHigh = obj.AbsorptionData{i}.SpectralRange.High + (obj.AbsorptionData{i}.SpectralRange.High - obj.AbsorptionData{i}.SpectralRange.Low) * 0.05;
                WavelengthPadLow = obj.AbsorptionData{i}.SpectralRange.High - (obj.AbsorptionData{i}.SpectralRange.High - obj.AbsorptionData{i}.SpectralRange.Low) * 0.05;
                if WavelengthLimitHigh < WavelengthPadHigh
                    WavelengthLimitHigh = WavelengthPadHigh;
                end
                if WavelengthLimitLow > WavelengthPadLow
                    WavelengthLimitLow = WavelengthPadLow;
                end
            end
            xlim([WavelengthLimitLow, WavelengthLimitHigh]);
            legend(LegendText, 'Location', 'NorthWest', 'interpreter', 'latex');
            set(fig, 'PaperOrientation', 'landscape');
            print(fig, strcat(obj.SavePath, 'abs_spectra'), '-dpdf', '-bestfit');
            print(fig, strcat(obj.SavePath, 'abs_spectra'), '-dpng');
            hold off
        end
        function BuildDataTable(obj) % works
            DataTable = cell2table(cell(0, 4), 'VariableNames', {'Compound', 'Solvent', 'Absorption', 'IntegratedEmission'});
            for i = 1:length(obj.EmissionData)
                Compound = obj.EmissionData{i}.ProbeName;
                Solvent = obj.EmissionData{i}.Solvent;
                IntegratedEmission = obj.EmissionData{i}.IntegratedEmission.IntegratedEmission;
                ExcitationWavelength = obj.EmissionData{i}.IntegratedEmission.ExcitationWavelength;
                ProbeConcentration = obj.EmissionData{i}.ProbeConcentration;
                for j = 1:length(obj.AbsorptionData)
                    IsSameProbe = contains(Compound, obj.AbsorptionData{j}.ProbeName);
                    IsSameSolvent = strcmp(Solvent, obj.AbsorptionData{j}.Solvent);
                    IsSameConcentration = ProbeConcentration == obj.AbsorptionData{j}.ProbeConcentration;
                    if IsSameProbe && IsSameSolvent && IsSameConcentration
                        Index = find(obj.AbsorptionData{j}.Data.Wavelength == ExcitationWavelength);
                        Absorption = obj.AbsorptionData{j}.Data.Absorption(Index);
                        DataTable = [DataTable; {Compound, Solvent, Absorption, IntegratedEmission}];
                    end
                end
            end
            obj.DataTable = sortrows(DataTable, [1, 2, 3]);
        end
        function CalculateGradients(obj) % works
            GradientTable = cell2table(cell(0, 3), 'VariableNames', {'ProbeName', 'Solvent', 'Gradient'});
            fig = figure;
            hold on
            set(fig, 'PaperOrientation', 'landscape');
            title('Gradient Plot', 'interpreter', 'latex');
            xlabel('Absorption [a.u.]', 'interpreter', 'latex');
            ylabel('Integrated Emission [a.u.]', 'interpreter', 'latex');
            Color = colormap(parula(length(obj.ProbeNameList.ProbeName)));
            for i = 1:length(obj.ProbeNameList.ProbeName)
                ProbeName = obj.ProbeNameList.ProbeName(i);
                Index = find(strcmp(obj.DataTable.Compound, ProbeName));
                Solvent = obj.DataTable.Solvent(Index);
                Solvent = Solvent(1);
                X = obj.DataTable.Absorption(Index);
                Y = obj.DataTable.IntegratedEmission(Index);
                Fit = fit([0; X], [0; Y], fittype({'x'}));
                GradientTable = [GradientTable; {ProbeName, Solvent, Fit.a}];
                scatter(X, Y, 'LineWidth', 2);
                plot(X, [Fit.a * X], 'LineWidth', 2, 'Color', Color(i, :), 'DisplayName', ProbeName{1});
                %plot(Fit, X, Y)%, '-', 'LineWidth', 2, 'Color', Color(i, :));
            end
            legend('show');
            print(fig, strcat(obj.SavePath, 'gradient_plot'), '-dpdf', '-bestfit');
            print(fig, strcat(obj.SavePath, 'gradient_plot'), '-dpng');
            hold off
            obj.GradientTable = GradientTable;
        end
        function CalculateQuantumYield(obj) % works
            % Determine references
            References = cell2table(cell(0, 4), 'VariableNames', {'Name', 'Solvent', 'QY', 'Gradient'});
            for i = 1:length(obj.GradientTable.ProbeName)
                IsSameName = contains(obj.QuantumYieldReferenceTable.Abbreviation, obj.GradientTable.ProbeName(i));
                IsSameSolvent = contains(obj.QuantumYieldReferenceTable.Solvent, obj.GradientTable.Solvent(i));
                if any(IsSameName) && any(IsSameSolvent)
                    Index = and(IsSameName, IsSameSolvent);
                    Name = obj.QuantumYieldReferenceTable.Abbreviation(Index);
                    Solvent = obj.QuantumYieldReferenceTable.Solvent(Index);
                    QY = obj.QuantumYieldReferenceTable.QuantumYield(Index);
                    Gradient = obj.GradientTable.Gradient(Index);
                    References = [References; {Name, Solvent, QY, Gradient}];
                end
            end
            if isempty(References)
                disp('No reference measurements could be identified');
                return
            end
            % If more than one reference -> cross compare
            if height(References) > 1
                disp('cross compare references: script needs to be written!');
            end
            % Calculate QY for all samples based on each reference
            ResultsTable = cell2table(cell(0, 3), 'VariableNames', {'Reference', 'Sample', 'QY'});
            for i = 1:height(References)
                for j = 1:height(obj.GradientTable)
                    % If sample is not the same as reference
                    if ~strcmp(obj.GradientTable.ProbeName(j), References.Name(i))
                        % Determine refractive index fraction - works
                        ReferenceSolvent = References.Solvent(i);
                        SampleSolvent = obj.GradientTable.Solvent(j);
                        if strcmp(ReferenceSolvent, SampleSolvent)
                            RefractiveIndexFraction = 1;
                        else
                            ReferenceRefractiveIndex = obj.RefractiveIndexReferenceTable.RefractiveIndex(find(obj.RefractiveIndexReferenceTable.Abbreviation == ReferenceSolvent));
                            SampleRefractiveIndex = obj.RefractiveIndexReferenceTable.RefractiveIndex(find(obj.RefractiveIndexReferenceTable.Abbreviation == SampleSolvent));
                            RefractiveIndexFraction = SampleRefractiveIndex^2 / ReferenceRefractiveIndex^2;
                        end
                        % Determine gradient fraction
                        ReferenceGradient = References.Gradient(i);
                        SampleGradient = obj.GradientTable.Gradient(j);
                        GradientFraction = SampleGradient / ReferenceGradient;
                        % Calculate QY
                        QY = References.QY(i) * GradientFraction * RefractiveIndexFraction;
                        ResultsTable = [ResultsTable; {References.Name(i), obj.GradientTable.ProbeName(j), QY}];
                    end
                end
            end
            obj.QuantumYieldResultsTable = ResultsTable;
        end
    end      
end