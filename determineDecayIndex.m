function DecayIndex = determineDecayIndex(Y)
    SizeY = size(Y);
    [MaxY, MaxIdx] = max(Y);
    % Confirm that decay is prevalent
    if MaxY < max(SizeY)
        DecayIndex = false(SizeY);
        return
    else
        DecayIndex = true(SizeY);
    end
    % Locate flat part before excitation
    PreDecayIdx = 1 : ( MaxIdx - 1 );
    DecayIndex(PreDecayIdx) = false;
    % Locate flat part after tail
    Idx = max(SizeY);
    while Idx > 0 && Y(Idx) == 0
        Idx = Idx - 1;
    end
    PostDecayIdx = ( Idx + 1 ) : max(SizeY);
    DecayIndex(PostDecayIdx) = false;
end