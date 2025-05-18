---@class MutatorEntityVar
---@field appliedMutators {[string]: Mutator}
---@field originalValues {[string]: any}

ABSOLUTES_LABORATORY_MUTATIONS = "Absolutes_Laboratory_Mutations"
Ext.Vars.RegisterUserVariable(ABSOLUTES_LABORATORY_MUTATIONS, {
	Server = true,
	Client = true
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

	if Ext.IsClient() then
		MutationManager:registerMutator(name, instance)
	end
	MutatorInterface.registeredMutators[name] = instance

	return instance
end

---@param parent ExtuiTreeParent
---@param mutator Mutator
function MutatorInterface:renderMutator(parent, mutator) end

---@param parent ExtuiTreeParent
---@param modifiers {[string]: MutationModifier}
function MutatorInterface:renderModifiers(parent, modifiers) end

---@param entity EntityHandle
---@param entityVar MutatorEntityVar
function MutatorInterface:applyMutator(entity, entityVar) end

---@param entity EntityHandle
---@param entityVar MutatorEntityVar
function MutatorInterface:undoMutator(entity, entityVar) end

Ext.Require("Shared/Mutations/Mutators/HealthMutator.lua")
