function [Date, Replicate, Type, Solvent, Concentration, Compound] = readInformationFromFileName(FileName)
    Info = strsplit(FileName, '_');
    if length(Info) == 5
        if contains(Info{1}, '-')
            SplitDate = strsplit(Info{1}, '-');
            Date = SplitDate{1};
            Replicate = str2double(SplitDate{2});
        else
            Date = Info{1};
            Replicate = NaN;
        end
        Type = Info{2};
        Solvent = Info{3};
        [Value, Unit] = splitStringIntoValueAndUnit(Info{4});
        Concentration.Value = Value;
        Concentration.Unit = Unit;
        Compound = strrep(Info{5}, ',', '.');
    else
        Date = NaN;
        Replicate = NaN;
        Type = NaN;
        Solvent = NaN;
        Concentration = NaN;
        Compound = NaN;
        warning('File name format can not be interpreted: %s', FileName);
    end
end