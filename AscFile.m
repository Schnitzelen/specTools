function [Data, MetaData] = AscFile(AbsoluteFileName)
    if isa(AbsoluteFileName, 'char')
        AbsoluteFileName = {AbsoluteFileName};
    end
    % Read file(s)
    Files = cellfun(@(x) importdata(x), AbsoluteFileName, 'UniformOutput', false);
    % Sort file(s)
    Expression = '(?:(?!_).)*?(?=\.asc)'; % must end with ".asc", must be as short as possible and not contain "_"
    FLIMVariable = regexp(AbsoluteFileName, Expression, 'match');
    FLIMVariable = vertcat(FLIMVariable{:});
    % Build metadata
    MetaData.FLIMVariable = FLIMVariable;
    % Build data
    DisallowedChars = '[\[%\]]';
    FLIMVariable = regexprep(FLIMVariable, DisallowedChars, '');
    FLIMVariable = regexprep(FLIMVariable, '^\w', '${upper($0)}');
    for i = 1:length(FLIMVariable)
        Data.(FLIMVariable{i}) = Files{i};
    end
end