function BinnedImage = binImage(Image, Bin)
    if isa(Bin, 'char') && strcmp(Bin, 'Full')
        BinnedImage = sum(Image, 'all');
    elseif isa(Bin, 'double')
        Filter = ones(2 * Bin + 1, 2 * Bin + 1, 'uint16');
        BinnedImage = uint16(convn(Image, Filter, 'same'));
    else
        warning('not yet developed for function!');
    end
end