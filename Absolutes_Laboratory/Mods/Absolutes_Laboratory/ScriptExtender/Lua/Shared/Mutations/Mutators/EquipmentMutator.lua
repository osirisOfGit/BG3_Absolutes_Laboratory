EquipmentMutator = MutatorInterface:new("Equipment")

EquipmentMutator.affectedComponents = {
}

function EquipmentMutator:priority()
	return self:recordPriority(1)
end

function EquipmentMutator:canBeAdditive()
	return true
end

function EquipmentMutator:handleDependencies()
	-- NOOP
end

function EquipmentMutator:Transient()
	return false
end

function EquipmentMutator:renderMutator(parent, mutator)
		
end

function EquipmentMutator:undoMutator(entity, entityVar)
	
end

function EquipmentMutator:applyMutator(entity, entityVar)

end

function EquipmentMutator:generateDocs()
	
end

function EquipmentMutator:generateChangelog()
	
end
