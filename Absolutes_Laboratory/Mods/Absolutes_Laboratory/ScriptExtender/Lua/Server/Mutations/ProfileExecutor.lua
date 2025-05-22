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
	local config = ConfigurationStructure:GetRealConfigCopy().mutations
	local activeProfile = config.profiles[Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile]

	if activeProfile then
		---@type {[FolderName] : {[MutationName]: SelectorPredicate}}
		local cachedSelectors = {}
		for _, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
			if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS] then
				MutatorInterface:undoMutator(entity, entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS])
			end

			if not entity.DeadByDefault and not entity.PartyMember then
				---@type MutatorEntityVar
				local entityVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS] or {
					appliedMutators = {},
					appliedMutatorsPath = {},
					originalValues = {}
				} --[[@as MutatorEntityVar]]

				for i, mProfileRule in ipairs(activeProfile.mutationRules) do
					local mutation = config.folders[mProfileRule.mutationFolder].mutations[mProfileRule.mutationName]
					if not cachedSelectors[mProfileRule.mutationFolder] then
						cachedSelectors[mProfileRule.mutationFolder] = {}
					end
					if not cachedSelectors[mProfileRule.mutationFolder][mProfileRule.mutationName] then
						cachedSelectors[mProfileRule.mutationFolder][mProfileRule.mutationName] = SelectorInterface:createComposedPredicate(mutation.selectors)
					end

					if cachedSelectors[mProfileRule.mutationFolder][mProfileRule.mutationName]:Test(entity) then
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
					MutatorInterface:applyMutator(entity, entityVar)
				end

				entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS] = next(entityVar.appliedMutators) and entityVar or nil
			end
		end
	else
		for _, entityId in pairs(Ext.Vars.GetEntitiesWithVariable(ABSOLUTES_LABORATORY_MUTATIONS)) do
			---@type EntityHandle
			local entity = Ext.Entity.Get(entityId)

			---@type MutatorEntityVar
			local mutatorVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS]

			MutatorInterface:undoMutator(entity, mutatorVar)
		end
	end
end

Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	if levelName == "SYS_CC_I" then return end

	MutationProfileExecutor:ExecuteProfile()
end)
