Ext.Vars.RegisterModVariable(ModuleUUID, "ActiveMonsterLabProfile", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

Ext.Vars.RegisterModVariable(ModuleUUID, "HasDisabledMonsterLabProfiles", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

MonsterLabProfileExecutor = {
	config = MonsterLabConfigurationProxy
}

function MonsterLabProfileExecutor:ExecuteProfile()
	Ext.Utils.ProfileBegin("Monster Lab Profile Execution")
	local profileId = Ext.Vars.GetModVariables(ModuleUUID).ActiveMonsterLabProfile

	if not profileId and not Ext.Vars.GetModVariables(ModuleUUID).HasDisabledMonsterLabProfiles and self.config.settings.defaultActiveProfile then
		profileId = self.config.settings.defaultActiveProfile
	end

	if profileId then
		local profile = self.config.profiles[profileId]
		if profile then
			local success, error = xpcall(function(...)
				Logger:BasicDebug("Running profile %s (%s)", profile.name, profileId)

				local currentLevel = Ext.Entity.Get(Osi.GetHostCharacter()).ServerCharacter.Level

				for _, encounterRule in TableUtils:OrderedPairs(profile.encounters) do
					if self.config.folders[encounterRule.folderId] and self.config.folders[encounterRule.folderId].encounters[encounterRule.encounterId] then
						local encounter = self.config.folders[encounterRule.folderId].encounters[encounterRule.encounterId]

						local encounterName = ("%s%s"):format(
							encounter.name,
							encounter.modId and (" - Mod: " .. Ext.Mod.GetMod(encounter.modId).Info.Name) or "")

						Logger:BasicDebug("============ Starting Encounter %s ============", encounterName)

						local success, error = xpcall(function(...)
							if encounter.gameLevel == currentLevel then
								EncounterManager:ManageEncounterSpanws({
									encounterId = encounterRule.encounterId,
									encounter = encounter,
									profileId = profileId
								})
							else
								EncounterManager:ManageEncounterSpanws({
									encounterId = encounterRule.encounterId,
									delete = true,
									profileId = profileId
								})
							end
						end, debug.traceback)

						if not success then
							Logger:BasicError("Couldn't process Encounter %s due to %s", encounterName, error)
						end

						Logger:BasicDebug("============ Finished Encounter %s ============", encounterName)
					else
						Logger:BasicError("Couldn't locate the specified encounter: %s", encounterRule)
						EncounterManager:ManageEncounterSpanws({
							encounterId = encounterRule.encounterId,
							delete = true,
							profileId = profileId
						})
					end
				end
			end, debug.traceback)

			if not success then
				Logger:BasicError("Monster Lab: Unrecoverable error occured: %s", error)
			end
		else
			Logger:BasicError("Monster Lab: Could not locate a profile with id of %s", profileId)
			self:ClearEncountersForDisabledProfile()
		end
	else
		Logger:BasicDebug("No Active Monster Lab Profile found - skipping")
		self:ClearEncountersForDisabledProfile()
	end
	Ext.Utils.ProfileEnd("Monster Lab Profile Execution")
end

function MonsterLabProfileExecutor:ClearEncountersForDisabledProfile()
	local encounterIds = {}
	for _, entityId in pairs(Ext.Vars.GetEntitiesWithVariable("AbsolutesLaboratory_MonsterLab_Entity")) do
		---@type EntityHandle
		local entity = Ext.Entity.Get(entityId)

		if entity then
			---@type MonsterLab_EntityVariable
			local var = entity.Vars.AbsolutesLaboratory_MonsterLab_Entity
			if not TableUtils:IndexOf(encounterIds, var.encounterId) then
				EncounterManager:ManageEncounterSpanws({
					encounterId = var.encounterId,
					delete = true
				})

				table.insert(encounterIds, var.encounterId)
			end
		end
	end
end
