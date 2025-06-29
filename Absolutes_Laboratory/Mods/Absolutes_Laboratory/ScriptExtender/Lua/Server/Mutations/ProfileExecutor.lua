Ext.Vars.RegisterModVariable(ModuleUUID, "ActiveMutationProfile", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

MutationProfileExecutor = {}

function MutationProfileExecutor:ExecuteProfile()
	if next(FileUtils:LoadTableFile(EntityRecorder.trackerFilename)) then
		Logger:BasicInfo("Recorder is currently running - skipping Mutations")
		return
	end

	local activeProfile = MutationConfigurationProxy.profiles[Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile]

	if activeProfile and next(activeProfile.mutationRules) then
		local time = Ext.Timer:MonotonicTime()

		local counter = 0
		---@type {[Guid] : {[Guid]: SelectorPredicate}}
		local cachedSelectors = {}
		for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
			if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] then
				MutatorInterface:undoMutator(entity, entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME])
			end

			if (Osi.IsDead(entity.Uuid.EntityUuid) == 0 or not entity.DeadByDefault) and not entity.PartyMember then
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

				if next(entityVar.appliedMutators) then
					counter = counter + 1
					entityVar = TableUtils:DeeplyCopyTable(entityVar)
					MutatorInterface:applyMutator(entity, entityVar)
				end

				entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = next(entityVar.appliedMutators) and entityVar or nil
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

Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	if levelName == "SYS_CC_I" then return end

	MutationProfileExecutor:ExecuteProfile()
end)
