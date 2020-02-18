function [Value, Unit] = splitStringIntoValueAndUnit(String)
    if contains(String, ',')
        String = strrep(String, ',', '.');
    end
    Idx = length(String);
    while Idx > 0
        if ~isnan(str2double(String(Idx - 1)))
            break
        end
        Idx = Idx - 1;
    end
    Value = str2double(String(1:Idx - 1));
    Unit = String(Idx:end);
end