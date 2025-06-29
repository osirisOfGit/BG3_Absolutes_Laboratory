---@class MutatorEntityVar
---@field appliedMutators {[string]: Mutator|Mutator[]}
---@field appliedMutatorsPath {[string]: MutationProfileRule|MutationProfileRule[]}
---@field originalValues {[string]: any}

ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME = "Absolutes_Laboratory_Mutations"
Ext.Vars.RegisterUserVariable(ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME, {
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

---@return boolean
function MutatorInterface:canBeAdditive()
	return false
end

function MutatorInterface:priority()
	return 9999
end

---@param export MutationsConfig
---@param mutator Mutator
---@param removeMissingDependencies boolean?
function MutatorInterface:handleDependencies(export, mutator, removeMissingDependencies)
	self.registeredMutators[mutator.targetProperty]:handleDependencies(export, mutator, removeMissingDependencies)
end

---@param entity EntityHandle
---@param entityVar MutatorEntityVar
function MutatorInterface:applyMutator(entity, entityVar)
	local time = Ext.Timer:MonotonicTime()
	Logger:BasicDebug("=========================== STARTING MUTATION OF %s_%s ===========================",
		entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
		entity.Uuid.EntityUuid)

	for mutatorName in TableUtils:OrderedPairs(entityVar.appliedMutators, function(key)
		return self.registeredMutators[key]:priority()
	end) do
		local mTime = Ext.Timer:MonotonicTime()
		Logger:BasicDebug("==== Starting mutator %s (priority %s) ====", mutatorName, self.registeredMutators[mutatorName]:priority())
		local success, error = xpcall(function(...)
			self.registeredMutators[mutatorName]:applyMutator(entity, entityVar)
		end, debug.traceback)

		if not success then
			Logger:BasicError("Failed to apply mutator %s to %s - %s", mutatorName, entity.Uuid.EntityUuid, error)
		else
			Logger:BasicDebug("==== Finished mutator %s in %dms ====", mutatorName, Ext.Timer:MonotonicTime() - mTime)
		end
	end

	Logger:BasicDebug("=========================== FINISHED %s_%s in %dms ===========================",
		entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
		entity.Uuid.EntityUuid,
		Ext.Timer:MonotonicTime() - time)
end

---@param entity EntityHandle
---@param entityVar MutatorEntityVar
function MutatorInterface:undoMutator(entity, entityVar)
	if entityVar then
		local time = Ext.Timer:MonotonicTime()

		Logger:BasicDebug("=========================== STARTING UNDO FOR %s_%s ===========================",
			entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
			entity.Uuid.EntityUuid)

		for mutatorName in TableUtils:OrderedPairs(entityVar.appliedMutators, function(key)
			return self.registeredMutators[key]:priority()
		end) do
			local mTime = Ext.Timer:MonotonicTime()
			Logger:BasicDebug("==== Starting mutator %s ====", mutatorName)

			local success, error = xpcall(function(...)
				self.registeredMutators[mutatorName]:undoMutator(entity, entityVar)
			end, debug.traceback)

			if not success then
				Logger:BasicError("Failed to undo mutator %s to %s - %s", mutatorName, entity.Uuid.EntityUuid, error)
			else
				Logger:BasicDebug("==== Finished mutator %s in %dms ====", mutatorName, Ext.Timer:MonotonicTime() - mTime)
			end
		end
		Logger:BasicDebug("=========================== FINISHED UNDO FOR %s_%s in %dms ===========================",
			entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
			entity.Uuid.EntityUuid,
			Ext.Timer:MonotonicTime() - time)
	end
	entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = nil
end

Ext.Require("Shared/Mutations/Mutators/HealthMutator.lua")
Ext.Require("Shared/Mutations/Mutators/ClassesAndSubclassesMutator.lua")
Ext.Require("Shared/Mutations/Mutators/ProgressionsMutator.lua")
Ext.Require("Shared/Mutations/Mutators/SpellList/SpellListMutator.lua")
