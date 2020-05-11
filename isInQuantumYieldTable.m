function Bool = isInQuantumYieldTable(Compound, Solvent)
    % Import quantum yield reference table
    QuantumYieldTable = readtable(fullfile(getenv('userprofile'), 'Documents/Matlab/SpecTools', 'ref_quantum_yield.csv'));
    % Check if solvent compound-combination in table
    SolventPresent = strcmp(QuantumYieldTable.Solvent, Solvent);
    CompoundPresent = strcmp(QuantumYieldTable.Abbreviation, Compound);
    Bool = any( SolventPresent & CompoundPresent );
end