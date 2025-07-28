Ext.Vars.RegisterModVariable(ModuleUUID, "ActiveMutationProfile", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

Ext.Vars.RegisterModVariable(ModuleUUID, "HasDisabledProfiles", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

MutationProfileExecutor = {}

local mutatedEntities = {}

function MutationProfileExecutor:ExecuteProfile(rerunTransient, ...)
	local trackerFile = FileUtils:LoadTableFile(EntityRecorder.trackerFilename)
	if trackerFile and next(trackerFile) then
		Logger:BasicInfo("Recorder is currently running - skipping Mutations")
		return
	end

	local activeProfile = MutationConfigurationProxy.profiles[Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile]

	if not activeProfile and not Ext.Vars.GetModVariables(ModuleUUID).HasDisabledProfiles then
		local defaultProfile = ConfigurationStructure.config.mutations.settings.defaultProfile
		if defaultProfile then
			Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = defaultProfile
			activeProfile = MutationConfigurationProxy.profiles[defaultProfile]
			Logger:BasicInfo("Default Profile %s activated", activeProfile.name)
		end
	end

	if activeProfile and next(activeProfile.mutationRules) then
		local time = Ext.Timer:MonotonicTime()

		local counter = 0
		---@type {[Guid] : {[Guid]: SelectorPredicate}}
		local cachedSelectors = {}

		for _, entity in pairs(... and { ... } or Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
			if (Osi.IsDead(entity.Uuid.EntityUuid) == 0 or not entity.DeadByDefault) and not entity.PartyMember then
				mutatedEntities[entity.Uuid.EntityUuid] = true

				---@type MutatorEntityVar
				local entityVar = {
					appliedMutators = {},
					appliedMutatorsPath = {},
					originalValues = {}
				}

				for i, mProfileRule in TableUtils:OrderedPairs(activeProfile.mutationRules) do
					local mutation = MutationConfigurationProxy.folders[mProfileRule.mutationFolderId].mutations[mProfileRule.mutationId]

					if not cachedSelectors[mProfileRule.mutationFolderId] then
						cachedSelectors[mProfileRule.mutationFolderId] = {}
					end
					if not cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId] then
						cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId] = SelectorInterface:createComposedPredicate(mutation.selectors)
					end

					if cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId]:Test(entity) then
						for _, mutator in pairs(mutation.mutators) do
							if entityVar.appliedMutators[mutator.targetProperty]
								and mProfileRule.additive
								and MutatorInterface.registeredMutators[mutator.targetProperty]:canBeAdditive(mutator)
							then
								if type(entityVar.appliedMutators[mutator.targetProperty]) == "table" then
									table.insert(entityVar.appliedMutators[mutator.targetProperty], mutator)
								else
									entityVar.appliedMutators[mutator.targetProperty] = { entityVar.appliedMutators[mutator.targetProperty], mutator }
								end

								entityVar.appliedMutatorsPath[mutator.targetProperty][i] = mProfileRule
							else
								entityVar.appliedMutators[mutator.targetProperty] = mutator
								entityVar.appliedMutatorsPath[mutator.targetProperty] = { [i] = mProfileRule }
							end
						end
					end
				end

				if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] then
					MutatorInterface:undoMutator(entity, entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME], entityVar, rerunTransient)
				end

				if next(entityVar.appliedMutators) then
					counter = counter + 1
					MutatorInterface:applyMutator(entity, entityVar)
				end

				entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = next(entityVar.appliedMutators) and entityVar or nil
			else
				if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] then
					MutatorInterface:undoMutator(entity, entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME], rerunTransient)
				end
			end
		end
		Logger:BasicInfo("======= Mutated %s Entities in %dms under Profile %s =======",
			counter,
			Ext.Timer:MonotonicTime() - time,
			activeProfile.name .. (activeProfile.modId and string.format(" (from mod %s)", Ext.Mod.GetMod(activeProfile.modId).Info.Name) or ""))
	else
		local time = Ext.Timer:MonotonicTime()
		local counter = 0
		for _, entityId in pairs(Ext.Vars.GetEntitiesWithVariable(ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME)) do
			counter = counter + 1
			---@type EntityHandle
			local entity = Ext.Entity.Get(entityId)

			---@type MutatorEntityVar
			local mutatorVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME]

			MutatorInterface:undoMutator(entity, mutatorVar)
		end
		Logger:BasicInfo("======= Cleared Mutations From %s Entities in %dms =======", counter, Ext.Timer:MonotonicTime() - time)
	end
end

Ext.Osiris.RegisterListener("EnteredCombat", 2, "before", function(entityId, combatGuid)
	---@type EntityHandle
	local entity = Ext.Entity.Get(entityId)
	if not mutatedEntities[entity.Uuid.EntityUuid] and entity.ServerCharacter and not entity.PartyMember then
		Logger:BasicInfo("%s entered combat %s and hasn't been mutated - executing profile!", entityId, combatGuid)
		MutationProfileExecutor:ExecuteProfile(false, entity)
	end
end)

Ext.RegisterConsoleCommand("Lab_TraceEntities", function(cmd, ...)
	ECSLogger:ClearLogFile()
	Printer:Start(100, ...)
	MutationProfileExecutor:ExecuteProfile()
end)

Ext.RegisterConsoleCommand("Lab_TestTransient", function(cmd, ...)
	MutationProfileExecutor:ExecuteProfile(true)
end)

Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	if levelName == "SYS_CC_I" then return end

	MutationProfileExecutor:ExecuteProfile()
end)
