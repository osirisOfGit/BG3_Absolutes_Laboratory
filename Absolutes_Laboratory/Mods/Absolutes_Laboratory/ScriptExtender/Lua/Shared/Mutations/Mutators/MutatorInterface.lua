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
	registeredMutators = {},
	Topic = "Mutations",
	SubTopic = "Mutators",
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

---@type MazzleDocsDocumentation
local changelogs = {}

---@param existingSlides MazzleDocsSlide[]?
---@return MazzleDocsSlide[]?
function MutatorInterface:generateDocs(existingSlides)
	if not existingSlides then
		return
	end

	table.insert(existingSlides, {
		Topic = self.Topic,
		SubTopic = self.SubTopic,
		content = {
			{
				type = "Heading",
				text = "Mutators"
			},
			{
				type = "Section",
				text = "Mutators are responsible for changing, or mutating, the entities that have been selected by the Selectors."
			},
			{
				type = "CallOut",
				prefix = "Philosophies",
				prefix_color = "Green",
				text = {
					"1. All entities can be mutated in a safe manner - users should not have to account for any individual entity's weirdness to avoid breaking other entities",
					"2. All mutators should be completely reversable without the user having to reload to save before the mutations were applied",
					"3. All mutator results should be visible and understandable in the Inspector, under the `Mutations` tab"
				}
			} --[[@as MazzleDocsCallOut]],
			{
				type = "Separator"
			},
			{
				type = "SubHeading",
				text = "Mutator Behavior During Profile Execution"
			},
			{
				type = "Content",
				text =
				"Mutators are pooled together after every Selector has run, overridng Mutators from Mutations higher in the Profile list if the 'Additive' checkbox is unchecked, or behaving as defined by their Additive section in their respective slide if applicable"
			},
			{
				type = "Separator"
			},
			{
				type = "SubHeading",
				text = "Mutator Dependencies"
			},
			{
				type = "Content",
				text = [[
Some mutators are also designed to be dependent on other mutators - these dependencies are listed in their respectives slides, but users don't have to concern themselves with this much, as each mutator is assigned an internal priority that ensures correct application order (and that order is reflected in the Mutators section of the sidebar).
Just know that the UI will render the mutators in this assigned order (if multiple mutators share the same priority, order is not guaranteed between sessions), and this priority is documented in the DEBUG logs:]]
			},
			{
				type = "Code",
				text = "==== Starting mutator Classes And Subclasses (priority 8) ===="
			},
			{
				type = "Separator"
			},
			{
				type = "SubHeading",
				text = "Transient Mutators"
			},
			{
				type = "Content",
				text = [[
Mutators can also be Transient - this property is set for mutators that mutate the entity in a way that is wiped on game reload, forcing a reapplication.
As of this writing, end users don't have to really care about this, as it's accounted for to prevent inconsistencies where necessary, but the solutions aren't perfect - they'll be detailed where relevant.]]
			}
		}
	} --[[@as MazzleDocsSlide]])

	for _, mutator in TableUtils:OrderedPairs(self.registeredMutators, function(key, value)
		return value:priority()
	end) do
		local docs = mutator:generateDocs()
		if docs then
			for _, slide in ipairs(docs) do
				table.insert(existingSlides, slide)
			end
		end

		local changelog = mutator:generateChangelog()
		if changelog and next(changelog) then
			for _, slide in ipairs(changelog) do
				table.insert(existingSlides, slide)
			end
		end
	end

	for _, changelog in ipairs(changelogs) do
		table.insert(existingSlides, changelog)
	end

	return existingSlides
end

---@return MazzleDocsSlide[]
function MutatorInterface:generateChangelog()
	return {}
end
