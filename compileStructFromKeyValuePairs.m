function S = compileStructFromKeyValuePairs(Keys, Values)
    % Remove characters that are illegal in variable names
    RemoveList = '[ #*]';
    Keys = regexprep(Keys, RemoveList, '');
    % Split keys in sub-indices
    Keys = regexp(Keys, '\.', 'split');
    % Build struct
    for i = 1:length(Keys)
        Key = Keys{i};
        Value = Values{i};
        switch length(Key)
            case 1
                S.(Key{1}) = Value;
            case 2
                S.(Key{1}).(Key{2}) = Value;
            case 3
                S.(Key{1}).(Key{2}).(Key{3}) = Value;
            case 4
                S.(Key{1}).(Key{2}).(Key{3}).(Key{4}) = Value;
        end
    end
end