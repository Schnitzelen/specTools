function [Keys, Values] = getKeysAndValuesFromHashTable(HashTable)
    Keys = arrayfun(@char, HashTable.keySet.toArray, 'UniformOutput', false);
    Values = cellfun(@(x) HashTable.get(x), Keys, 'UniformOutput', false);
    Keys = regexp(Keys, 'Global', 'split');
    Keys = cellfun(@(x) x{2}, Keys, 'UniformOutput', false);
end