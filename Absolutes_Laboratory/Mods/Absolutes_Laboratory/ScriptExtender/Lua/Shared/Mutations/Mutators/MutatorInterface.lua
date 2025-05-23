---@class MutatorEntityVar
---@field appliedMutators {[string]: Mutator|Mutator[]}
---@field appliedMutatorsPath {[string]: MutationProfileRule|MutationProfileRule[]}
---@field originalValues {[string]: any}

ABSOLUTES_LABORATORY_MUTATIONS = "Absolutes_Laboratory_Mutations"
Ext.Vars.RegisterUserVariable(ABSOLUTES_LABORATORY_MUTATIONS, {
	Server = true,
	Client = true,
	SyncToClient = true
})

---@class MutatorInterface
MutatorInterface = {
	name = "",
	---@type {[string]: MutatorInterface}
	registeredMutators = {}
}

---@param name string
---@return MutatorInterface
function MutatorInterface:new(name)
	local instance = { name = name }

	setmetatable(instance, self)
	self.__index = self

	MutatorInterface.registeredMutators[name] = instance

	return instance
end

---@param parent ExtuiTreeParent
---@param mutator Mutator
function MutatorInterface:renderMutator(parent, mutator) end

---@param parent ExtuiTreeParent
---@param modifiers {[string]: MutationModifier}
function MutatorInterface:renderModifiers(parent, modifiers) end

---@param mutator Mutator
---@return boolean
function MutatorInterface:canBeAdditive(mutator)
	return false
end

---@param entity EntityHandle
---@param entityVar MutatorEntityVar
function MutatorInterface:applyMutator(entity, entityVar)
	for mutatorName in pairs(entityVar.appliedMutators) do
		local success, error = xpcall(function(...)
			self.registeredMutators[mutatorName]:applyMutator(entity, entityVar)
		end, debug.traceback)

		if not success then
			Logger:BasicError("Failed to apply mutator %s to %s - %s", mutatorName, entity.Uuid.EntityUuid, error)
		end
	end
end

---@param entity EntityHandle
---@param entityVar MutatorEntityVar
function MutatorInterface:undoMutator(entity, entityVar)
	for mutatorName in pairs(entityVar.appliedMutators) do
		local success, error = xpcall(function(...)
			self.registeredMutators[mutatorName]:undoMutator(entity, entityVar)
		end, debug.traceback)

		if not success then
			Logger:BasicError("Failed to undo mutator %s to %s - %s", mutatorName, entity.Uuid.EntityUuid, error)
		end
	end
	entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS] = nil
end

Ext.Require("Shared/Mutations/Mutators/HealthMutator.lua")
