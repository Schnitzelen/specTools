% By Brian Bjarke Jensen 4/1-2019

classdef readMAC < handle
    % Class used for reading and containing molar attenuation
    % coefficient-data
    properties
        AbsoluteFileList
        Compound
        Solvent
        Fit
        Raw
        Results
        Data
    end
    methods
        function obj = readMAC(AbsoluteFileList)
            % Ask for path, if none is provided
            if ~exist('AbsoluteFileList', 'var')
                AbsoluteFileList = uigetfile(pwd(), 'Please Select Molar Attenuation Data to Import', 'MultiSelect', 'on');
            end
            obj.AbsoluteFileList = AbsoluteFileList;
            obj.importData();
            obj.calculateMolarAttenuationCoefficient();
        end
        function importData(obj)
            obj.Data = cellfun(@(x) readAbs(x), obj.AbsoluteFileList, 'UniformOutput', false);
            obj.Compound = obj.Data{1}.Compound;
            obj.Solvent = obj.Data{1}.Solvent;
        end
        function calculateMolarAttenuationCoefficient(obj)
            Solvent = obj.Solvent;
            % Calculate mean wavelength of peak
            PeakWavelengths = cellfun(@(x) x.SpectralRange.Peak, obj.Data);
            Wavelength = round(nanmean(PeakWavelengths));
            % Prepare data to fit
            Concentration = cellfun(@(x) x.Concentration, obj.Data);
            Absorption = cellfun(@(x) x.Data.CorrectedAbsorption(x.Data.Wavelength == Wavelength), obj.Data);
            obj.Raw = table(Concentration, Absorption);
            % Do linear fit
            obj.Fit = polyfit(obj.Raw.Concentration, obj.Raw.Absorption, 1);
            if obj.Fit(1) / abs(obj.Fit(2)) > 0.001
                warning('Fit Deviates Significantly From Orego')
            end
            MAC = round(obj.Fit(1), 5, 'significant');
            obj.Results = table(Solvent, Wavelength, MAC);
        end
        function Fig = plotResults(obj)
            Fig = figure;
            hold on
            %Color = colormap(parula(height(obj.Results)));
            scatter(obj.Raw.Concentration, obj.Raw.Absorption, 'LineWidth', 2, 'HandleVisibility', 'off');
            plot(obj.Raw.Concentration, obj.Fit(1) * obj.Raw.Concentration + obj.Fit(2), 'LineWidth', 2, 'DisplayName', obj.Solvent)
            title(sprintf('%s{Molar Attenuation Coefficient Fit of %s}', '\textbf', obj.Compound), 'Interpreter', 'latex');
            xlabel('concentration (M)', 'Interpreter', 'latex');
            ylabel('absorption (a.u.)', 'Interpreter', 'latex');
            legend({}, 'Interpreter', 'latex', 'Location', 'northwest');
            hold off
        end
    end
end
    