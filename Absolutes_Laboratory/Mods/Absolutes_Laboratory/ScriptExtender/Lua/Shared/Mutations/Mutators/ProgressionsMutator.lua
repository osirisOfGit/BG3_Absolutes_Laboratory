ProgressionsMutator = MutatorInterface:new("Progressions")

function ProgressionsMutator:priority()
	return SpellListMutator:priority() + 1
end

function ProgressionsMutator:canBeAdditive()
	return true
end
