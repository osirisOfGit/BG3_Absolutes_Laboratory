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
								MonsterLabEncounterManager:ManageEncounterSpanws({
									folderId = encounterRule.folderId,
									encounterId = encounterRule.encounterId,
									encounter = encounter,
									profileId = profileId
								})
							else
								MonsterLabEncounterManager:ManageEncounterSpanws({
									folderId = encounterRule.folderId,
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
						MonsterLabEncounterManager:ManageEncounterSpanws({
							folderId = encounterRule.folderId,
							encounterId = encounterRule.encounterId,
							delete = true,
							profileId = profileId
						})
					end
				end
			end, debug.traceback)

			if not success then
				Logger:BasicError("Monster Lab: Unrecoverable error occurred: %s", error)
				self:ClearEncountersForDisabledProfile()
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
				MonsterLabEncounterManager:ManageEncounterSpanws({
					profileId = "N/A",
					folderId = var.folderId,
					encounterId = var.encounterId,
					delete = true
				})

				table.insert(encounterIds, var.encounterId)
			end
		end
	end
end

local cachedRulesetStates = {}

---@param entity EntityHandle
---@return MonsterLab_RulesetRule?
function MonsterLabProfileExecutor:GetRulesetForEntity(entity)
	if entity.Vars.AbsolutesLaboratory_MonsterLab_Entity then
		return self:GetRulesetForEntityVar(entity.Vars.AbsolutesLaboratory_MonsterLab_Entity)
	end
end

---@param entityVar MonsterLab_EntityVariable
---@return MonsterLab_RulesetRule?
function MonsterLabProfileExecutor:GetRulesetForEntityVar(entityVar)
	Ext.Utils.ProfileBegin("Monster Lab Get Ruleset For  " .. entityVar.mlEntityId:sub(#entityVar.mlEntityId - 5))

	if MonsterLabConfigurationProxy.folders[entityVar.folderId] then
		local rulesetModifiers = TableUtils:DeeplyCopyTable(MonsterLabConfigurationProxy.folders[entityVar.folderId]
			.encounters[entityVar.encounterId]
			.entities[entityVar.mlEntityId]
			.rulesetModifiers)

		local numMatchedRules = 0
		---@type Guid
		local activeRuleset

		for rulesetGuid in pairs(rulesetModifiers) do
			local rulesetDef = MonsterLabConfigurationProxy.rulesets[rulesetGuid]
			if rulesetDef then
				Logger:BasicTrace("Checking ruleset %s for %s", rulesetDef.name, entityVar.mlEntityId)
				local ruleCount = 0
				for modifierId, modiferValue in pairs(rulesetDef.activeModifiers) do
					ruleCount = ruleCount + 1
					if type(modiferValue) == "boolean" then
						if cachedRulesetStates[modifierId] == nil then
							cachedRulesetStates[modifierId] = Osi.CheckRulesetModifierBool(modifierId, modiferValue == true and 1 or 0) == 1
						end

						if not cachedRulesetStates[modifierId] then
							Logger:BasicTrace("Ruleset modifier %s is not set to %s", Lab_RulesetModifiers[modifierId], modiferValue)
							goto next_ruleset
						end
					else
						local matched = false
						for _, acceptableValue in pairs(modiferValue) do
							if not cachedRulesetStates[modifierId] or cachedRulesetStates[modifierId][acceptableValue] == nil then
								cachedRulesetStates[modifierId] = cachedRulesetStates[modifierId] or {}
								cachedRulesetStates[modifierId][acceptableValue] = Osi.CheckRulesetModifierString(modifierId, acceptableValue) == 1
							end

							matched = cachedRulesetStates[modifierId][acceptableValue]
							if matched then
								break
							end
						end
						if not matched then
							Logger:BasicTrace("Ruleset modifier %s is not set to any of %s", Lab_RulesetModifiers[modifierId], modiferValue)

							goto next_ruleset
						end
					end
				end
				if ruleCount > numMatchedRules then
					activeRuleset = rulesetGuid
					numMatchedRules = ruleCount
				end

				::next_ruleset::
			end
		end
		if not activeRuleset then
			activeRuleset = "Base"
		end

		Logger:BasicDebug("Ruleset %s is active, with %d matching rules!", MonsterLabConfigurationProxy.rulesets[activeRuleset].name, numMatchedRules)
		Ext.Utils.ProfileEnd("Monster Lab Get Ruleset For  " .. entityVar.mlEntityId:sub(#entityVar.mlEntityId - 5))

		if not rulesetModifiers[activeRuleset] then
			rulesetModifiers[activeRuleset] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.rulesetModifiers)
		end

		return rulesetModifiers[activeRuleset]._real or rulesetModifiers[activeRuleset]
	end
end
