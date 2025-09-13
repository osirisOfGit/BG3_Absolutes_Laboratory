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

---@param mutator Mutator
---@param existingMutator Mutator?
---@return boolean
function MutatorInterface:canBeAdditive(mutator, existingMutator)
	return false
end

local prioritySet = {}
function MutatorInterface:recordPriority(priority)
	if not prioritySet[self.name] then
		local function findNextPriority(priorityIndex)
			if not prioritySet[priorityIndex] then
				prioritySet[priorityIndex] = self.name
				prioritySet[self.name] = priorityIndex
				return priorityIndex
			elseif prioritySet[priorityIndex] == self.name then
				return priorityIndex
			else
				return findNextPriority(priorityIndex + 1)
			end
		end

		return findNextPriority(priority)
	else
		return prioritySet[self.name]
	end
end

function MutatorInterface:priority()
	return self:recordPriority(999)
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
			self.registeredMutators[mutatorName]:FinalizeMutator(entity)

			Logger:BasicDebug("==== Finished mutator %s in %dms ====", mutatorName, Ext.Timer:MonotonicTime() - mTime)
		end
	end

	Logger:BasicDebug("=========================== FINISHED %s_%s in %dms ===========================",
		entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
		entity.Uuid.EntityUuid,
		Ext.Timer:MonotonicTime() - time)
end

---@param entity EntityHandle
---@param entityVar MutatorEntityVar var already on the entity, before application logic is run
---@param primedEntityVar MutatorEntityVar? changes that are queued up to be applied
---@param reprocessTransient boolean? will be true if the profile is re-executed in a single session, i.e. when the player level ups while a level mutator is in play
function MutatorInterface:undoMutator(entity, entityVar, primedEntityVar, reprocessTransient)
	if entityVar then
		local time = Ext.Timer:MonotonicTime()

		Logger:BasicDebug("=========================== STARTING UNDO FOR %s_%s ===========================",
			entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
			entity.Uuid.EntityUuid)

		for mutatorName in TableUtils:OrderedPairs(entityVar.appliedMutators, function(key)
			return self.registeredMutators[key]:priority()
		end) do
			local mut = self.registeredMutators[mutatorName]

			if not mut:Transient() or reprocessTransient then
				local mTime = Ext.Timer:MonotonicTime()
				Logger:BasicDebug("==== Starting mutator %s ====", mutatorName)

				local success, error = xpcall(function(...)
					self.registeredMutators[mutatorName]:undoMutator(entity, entityVar, primedEntityVar, reprocessTransient)
				end, debug.traceback)

				if not success then
					Logger:BasicError("Failed to undo %s - %s", mutatorName, error)
				else
					if not primedEntityVar or not primedEntityVar.appliedMutators[mutatorName] then
						Logger:BasicTrace("Finalized undo as it's not queued up to be applied")

						mut:FinalizeMutator(entity)
					end
					Logger:BasicDebug("==== Finished mutator %s in %dms ====", mutatorName, Ext.Timer:MonotonicTime() - mTime)
				end
			else
				Logger:BasicDebug("Skipping Mutator %s as it's Transient, so there's nothing to undo", mutatorName)
			end
		end
		Logger:BasicDebug("=========================== FINISHED UNDO FOR %s_%s in %dms ===========================",
			entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
			entity.Uuid.EntityUuid,
			Ext.Timer:MonotonicTime() - time)
	end
	entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = nil
end

---@return boolean isTransient if the mutator requires reapplication on game restart - i.e. health because it directly modifies the entity component
function MutatorInterface:Transient()
	return false
end

--- Should fire things like replication, system calls, etc in case an undo and apply need to run consecutively, so they don't fight one another
---@param entity EntityHandle
function MutatorInterface:FinalizeMutator(entity) end

Ext.Require("Shared/Mutations/Mutators/PrepPhaseMarkerMutator.lua")

Ext.Require("Shared/Mutations/Mutators/LevelMutator.lua")
Ext.Require("Shared/Mutations/Mutators/SpellList/SpellListMutator.lua")
Ext.Require("Shared/Mutations/Mutators/PassiveList/PassiveListMutator.lua")
Ext.Require("Shared/Mutations/Mutators/StatusList/StatusListMutator.lua")
Ext.Require("Shared/Mutations/Mutators/ClassesAndSubclassesMutator.lua")
Ext.Require("Shared/Mutations/Mutators/ActionResourcesMutator.lua")
Ext.Require("Shared/Mutations/Mutators/HealthMutator.lua")
Ext.Require("Shared/Mutations/Mutators/AbilitiesMutator.lua")
Ext.Require("Shared/Mutations/Mutators/BoostsMutator.lua")
Ext.Require("Shared/Mutations/Mutators/ProgressionsMutator.lua")
