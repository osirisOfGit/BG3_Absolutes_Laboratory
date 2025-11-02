Ext.Vars.RegisterModVariable(ModuleUUID, "MonsterLab_SpawnedEntities", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

Ext.Vars.RegisterUserVariable("AbsolutesLaboratory_MonsterLab_Entity", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

MonsterLabEncounterManager = {
	mazzleLib = Mods.Mazzle_Lib,
	---@type Mazzle_Orbs
	mazzleOrbs = nil,
	---@type Map
	mazzleMap = nil,
	---@type {[Guid]: {[string]: Guid}}
	encounterVisualizations = {},
	config = MonsterLabConfigurationProxy
}

Ext.Events.SessionLoaded:Subscribe(function(e)
	MonsterLabEncounterManager.mazzleLib = Mods.Mazzle_Lib

	if MonsterLabEncounterManager.mazzleLib then
		MonsterLabEncounterManager.mazzleOrbs = MonsterLabEncounterManager.mazzleLib.Mazzle_Orbs --[[@as Mazzle_Orbs]]
		MonsterLabEncounterManager.mazzleMap = MonsterLabEncounterManager.mazzleLib.Map
		-- ---@type MLT_Collection_Metadata
		-- local collection_parameters = {
		-- 	allow_clear_removal = false,
		-- 	allow_manual_removal = false,
		-- 	allow_level_unload = true,
		-- 	allow_thinning = false,
		-- }

		-- mazzleObjectManager:Register_Collection("MonsterLab_EncounterVisualizations", "orb", collection_parameters)
	end
end)

---@class ManageDesignerModeRequest
---@field playersCanFight boolean
---@field playersCanDialogue boolean
Channels.ManageDesignerMode:SetHandler(
---@param request ManageDesignerModeRequest
	function(request)
		for _, playerTable in pairs(Osi.DB_Players:Get(nil)) do
			for _, summmonTable in pairs(Osi.DB_PlayerSummons:Get(playerTable[1])) do
				Osi.SetCanFight(summmonTable[1], request.playersCanFight and 1 or 0)
				Osi.SetCanJoinCombat(summmonTable[1], request.playersCanFight and 1 or 0)

				if request.playersCanDialogue then
					Osi.RemoveBoosts(summmonTable[1], "DialogueBlock();", 0, summmonTable[1], summmonTable[1])
				else
					Osi.AddBoosts(summmonTable[1], "DialogueBlock();", summmonTable[1], summmonTable[1])
				end
			end

			Osi.SetCanFight(playerTable[1], request.playersCanFight and 1 or 0)
			Osi.SetCanJoinCombat(playerTable[1], request.playersCanFight and 1 or 0)

			if request.playersCanDialogue then
				Osi.RemoveBoosts(playerTable[1], "DialogueBlock();", 0, playerTable[1], playerTable[1])
			else
				Osi.AddBoosts(playerTable[1], "DialogueBlock();", playerTable[1], playerTable[1])
			end
		end
	end)

---@class VisualizationRequest
---@field encounterId Guid
---@field coords number[]?
---@field context string?
---@field cleanup boolean?
---@field cleanupEncounter boolean?
---@field moonbeam number?

Channels.OrbAtPosition:SetHandler(
---@param data VisualizationRequest
	function(data)
		local self = MonsterLabEncounterManager
		if not self.mazzleLib then
			Logger:BasicWarning("MazzleLib isn't loaded?")
			return
		end

		self.encounterVisualizations[data.encounterId] = self.encounterVisualizations[data.encounterId] or {}
		local encounterVis = self.encounterVisualizations[data.encounterId]

		if data.cleanup then
			Osi.RequestDelete(encounterVis[data.context])
			encounterVis[data.context] = nil
		elseif data.cleanupEncounter then
			for _, vis in pairs(encounterVis) do
				Osi.RequestDelete(vis)
			end
			self.encounterVisualizations[data.encounterId] = nil
		else
			if not encounterVis[data.context] then
				encounterVis[data.context] = self.mazzleOrbs:Create_Debug_Orb(data.coords[1], data.coords[2], data.coords[3])
			else
				Osi.TeleportToPosition(encounterVis[data.context], data.coords[1], data.coords[2], data.coords[3])
			end

			if data.moonbeam then
				self.mazzleOrbs:Add_VFX_to_Object(encounterVis[data.context], "moonbeam", data.moonbeam)
			end
		end
	end)


---@class MonsterLab_EntityVariable
---@field profileId Guid?
---@field folderId Guid
---@field encounterId Guid
---@field mlEntityId Guid

---@class MonsterLabEntity_Spawned : MonsterLabEntity
---@field realEntityId Guid

---@class MonsterLabEncounter_Spawned : MonsterLabEncounter
---@field entities {[Guid]: MonsterLabEntity_Spawned}

---@alias MonsterLab_SpawnedEntities {[Guid]: MonsterLabEncounter_Spawned}

---@class ManageEncounterRequest
---@field folderId Guid
---@field encounterId Guid
---@field encounter MonsterLabEncounter? not present if delete is true
---@field profileId Guid?
---@field delete boolean?

---@type MonsterLab_SpawnedEntities
local allSpawnedEntities

---@param request ManageEncounterRequest
function MonsterLabEncounterManager:ManageEncounterSpanws(request)
	Ext.Utils.ProfileBegin("Monster Lab Encounter Execution - " .. request.encounterId:sub(#request.encounterId - 5))

	if not allSpawnedEntities then
		allSpawnedEntities = Ext.Vars.GetModVariables(ModuleUUID).MonsterLab_SpawnedEntities or {}
	else
		for encounterId, entities in pairs(allSpawnedEntities) do
			local deleteEntities = false
			for folderId, folder in pairs(MonsterLabConfigurationProxy.folders) do
				if folder.encounters[encounterId] then
					deleteEntities = true
					break
				end
			end

			if not deleteEntities then
				Logger:BasicDebug("Deleting all entities from encounter %s as it no longer exists", encounterId)
				for _, entity in pairs(entities) do
					Osi.RequestDeleteTemporary(entity.realEntityId)
				end
				allSpawnedEntities[encounterId] = nil
			end
		end
	end

	allSpawnedEntities[request.encounterId] = allSpawnedEntities[request.encounterId] or {}

	local encounterEntities = allSpawnedEntities[request.encounterId]
	encounterEntities.entities = encounterEntities.entities or {}

	local success, error = xpcall(function()
		if request.encounter and request.profileId then
			for mlEntityId, spawnedEntity in pairs(encounterEntities.entities) do
				if not request.encounter.entities[mlEntityId] and spawnedEntity.realEntityId then
					Osi.RequestDeleteTemporary(spawnedEntity.realEntityId)
					Logger:BasicDebug("Deleted %s (%s) due to no longer being in the encounter", spawnedEntity.displayName, mlEntityId:sub(#mlEntityId - 5))
					encounterEntities.entities[mlEntityId] = nil
				end
			end
		end

		if request.delete then
			for index, entity in pairs(encounterEntities.entities) do
				if entity.realEntityId then
					if (request.profileId or not Ext.Entity.Get(entity.realEntityId).Vars.AbsolutesLaboratory_MonsterLab_Entity.profileId) then
						encounterEntities.entities[index] = nil
						Osi.RequestDeleteTemporary(entity.realEntityId)
					else
						Osi.SetCanFight(entity.realEntityId, 1)
						Osi.SetCanJoinCombat(entity.realEntityId, 1)
					end
				end
			end
			Logger:BasicDebug("Deleted all members of encounter %s", request.encounterId)
			if not next(encounterEntities.entities) then
				allSpawnedEntities[request.encounterId] = nil
			end
		else
			for mlEntityId, mlEntity in pairs(request.encounter.entities) do
				Ext.Utils.ProfileBegin("Monster Lab Entity Execution - " .. mlEntityId:sub(#mlEntityId - 5))
				Logger:BasicDebug("===== Starting Entity %s (%s) =====", mlEntity.displayName, mlEntityId:sub(#mlEntityId - 5))

				local shouldSpawn = true
				if request.profileId then
					local ruleset = MonsterLabProfileExecutor:GetRulesetForEntityVar({
						encounterId = request.encounterId,
						folderId = request.folderId,
						mlEntityId = mlEntityId,
						profileId = request.profileId
					})

					shouldSpawn = ruleset and ruleset.shouldSpawn
				end

				if shouldSpawn then
					if encounterEntities.entities[mlEntityId]
						and encounterEntities.entities[mlEntityId].realEntityId
						and encounterEntities.entities[mlEntityId].template == mlEntity.template
					then
						Logger:BasicDebug("Already exists - checking if it needs updates")

						local spawnedEntity = encounterEntities.entities[mlEntityId]

						Osi.SetStoryDisplayName(spawnedEntity.realEntityId, mlEntity.displayName)

						if mlEntity.title and mlEntity.title ~= "" then
							Osi.ObjectSetTitle(spawnedEntity.realEntityId, mlEntity.title)
						end

						if Osi.IsInCombat(spawnedEntity.realEntityId) == 0 then
							if not TableUtils:CompareLists(mlEntity.coordinates, spawnedEntity.coordinates) then
								Logger:BasicDebug("Updating coordinates from %s to %s", spawnedEntity.coordinates, mlEntity.coordinates)

								Osi.TeleportToPosition(spawnedEntity.realEntityId, mlEntity.coordinates[1], mlEntity.coordinates[2], mlEntity.coordinates[3])
								spawnedEntity.coordinates = mlEntity.coordinates
							end

							if mlEntity.rotation ~= spawnedEntity.rotation then
								Logger:BasicDebug("Updating rotation from %s to %s", spawnedEntity.rotation, mlEntity.rotation)
								self.mazzleMap:Turn_To_Angle(spawnedEntity.realEntityId, mlEntity.rotation)
								spawnedEntity.rotation = mlEntity.rotation
							end

							if mlEntity.animation.simple then
								if mlEntity.animation.simple ~= spawnedEntity.animation.simple then
									Logger:BasicDebug("Updating simple animation from %s to %s", spawnedEntity.animation.simple, mlEntity.animation.simple)
									Osi.PlayAnimation(spawnedEntity.realEntityId, mlEntity.animation.simple)
								end
							else
								if not TableUtils:CompareLists(mlEntity.animation.looping, spawnedEntity.animation.looping) then
									Logger:BasicDebug("Updating looping animation from %s to %s", spawnedEntity.animation.looping, mlEntity.animation.looping)

									local looping = mlEntity.animation.looping
									Osi.PlayLoopingAnimation(spawnedEntity.realEntityId,
										looping.startAnimation,
										looping.loopAnimation,
										looping.endAnimation,
										looping.loopVariation1,
										looping.loopVariation2,
										looping.loopVariation3,
										looping.loopVariation4
									)
								end
							end
							spawnedEntity.animation = mlEntity.animation
						else
							Logger:BasicDebug("Is in combat - skipping coordinates, rotation, and animation updates")
						end

						if request.encounter.faction and request.encounter.faction ~= Osi.GetFaction(spawnedEntity.realEntityId) then
							if Logger:IsLogLevelEnabled(Logger.PrintTypes.DEBUG) then
								Logger:BasicDebug("Updated faction from %s to %s", Osi.GetFaction(spawnedEntity.realEntityId), request.encounter.faction)
							end

							Osi.SetFaction(spawnedEntity.realEntityId, request.encounter.faction)
						end

						if request.encounter.combatGroupId and request.encounter.combatGroupId ~= Osi.GetCombatGroupID(spawnedEntity.realEntityId) then
							if Logger:IsLogLevelEnabled(Logger.PrintTypes.DEBUG) then
								Logger:BasicDebug("Updating combatGroupId from %s to %s", Osi.GetCombatGroupID(spawnedEntity.realEntityId), request.encounter.combatGroupId)
							end

							Osi.SetCombatGroupID(spawnedEntity.realEntityId, request.encounter.combatGroupId)
						end

						if not request.profileId then
							Osi.SetCanFight(spawnedEntity.realEntityId, 0)
							Osi.SetCanJoinCombat(spawnedEntity.realEntityId, 0)
						end
					elseif not TableUtils:CompareLists(mlEntity.coordinates, { 0, 0, 0 }) then
						Logger:BasicDebug("Does not exist yet - setting properties")

						if encounterEntities.entities[mlEntityId]
							and encounterEntities.entities[mlEntityId].realEntityId
							and encounterEntities.entities[mlEntityId].template ~= mlEntity.template
						then
							Logger:BasicDebug("Deleting entity to change their template")
							Osi.RequestDeleteTemporary(encounterEntities.entities[mlEntityId].realEntityId)
						end

						encounterEntities.entities[mlEntityId] = mlEntity

						encounterEntities.entities[mlEntityId].realEntityId = Osi.CreateAt(mlEntity.template,
							mlEntity.coordinates[1],
							mlEntity.coordinates[2],
							mlEntity.coordinates[3],
							1,
							1,
							"")

						Logger:BasicDebug("Created template %s at %s, setting: %s",
							mlEntity.template,
							mlEntity.coordinates,
							{
								combatGroupId = request.encounter.combatGroupId,
								faction = request.encounter.faction,
								displayName = mlEntity.displayName,
								title = mlEntity.title,
								passive = "ABSOLUTES_LAB_MONSTER_LAB_ENTITY_MARKER",
							})

						Ext.Timer.WaitFor(100, function()
							---@type EntityHandle
							local entity = Ext.Entity.Get(encounterEntities.entities[mlEntityId].realEntityId)
							if entity then
								entity.Vars.AbsolutesLaboratory_MonsterLab_Entity = {
									profileId = request.profileId,
									folderId = request.folderId,
									encounterId = request.encounterId,
									mlEntityId = mlEntityId,
								} --[[@as MonsterLab_EntityVariable]]

								if not request.profileId then
									Osi.SetCanFight(entity.Uuid.EntityUuid, 0)
									Osi.SetCanJoinCombat(entity.Uuid.EntityUuid, 0)
								end

								Osi.SetCombatGroupID(entity.Uuid.EntityUuid, request.encounter.combatGroupId)
								Osi.SetFaction(entity.Uuid.EntityUuid, request.encounter.faction)
								Osi.SetStoryDisplayName(entity.Uuid.EntityUuid, mlEntity.displayName)

								if mlEntity.title and mlEntity.title ~= "" then
									Osi.ObjectSetTitle(entity.Uuid.EntityUuid, mlEntity.title)
								end

								if self.mazzleLib then
									self.mazzleMap:Turn_To_Angle(entity.Uuid.EntityUuid, mlEntity.rotation)
								end

								Osi.AddPassive(entity.Uuid.EntityUuid, "ABSOLUTES_LAB_MONSTER_LAB_ENTITY_MARKER")

								if mlEntity.animation.simple then
									if mlEntity.animation.simple ~= "" then
										Osi.PlayAnimation(entity.Uuid.EntityUuid, mlEntity.animation.simple)
									end
								else
									if not TableUtils:IndexOf(mlEntity.animation.looping, "") then
										local looping = mlEntity.animation.looping
										Osi.PlayLoopingAnimation(entity.Uuid.EntityUuid,
											looping.startAnimation,
											looping.loopAnimation,
											looping.endAnimation,
											looping.loopVariation1,
											looping.loopVariation2,
											looping.loopVariation3,
											looping.loopVariation4
										)
									end
								end
							end
						end)
					end
				else
					Logger:BasicDebug("Not eligible for spawning due to active ruleset!")
				end
				Logger:BasicDebug("===== Finished Entity %s (%s) =====", mlEntity.displayName, mlEntityId:sub(#mlEntityId - 5))
				Ext.Utils.ProfileEnd("Monster Lab Entity Execution - " .. mlEntityId:sub(#mlEntityId - 5))
			end
		end
	end, debug.traceback)

	if not success then
		Logger:BasicError("Fatal error occured while processing %s - %s", request.encounterId, error)
	end

	Ext.Vars.GetModVariables(ModuleUUID).MonsterLab_SpawnedEntities = allSpawnedEntities
	Ext.Utils.ProfileEnd("Monster Lab Encounter Execution - " .. request.encounterId)
end

Channels.ManageEncounterSpawns:SetHandler(
---@param request ManageEncounterRequest
	function(request)
		MonsterLabEncounterManager:ManageEncounterSpanws(request)
	end)

function MonsterLabEncounterManager:MutateAllEncounters()
	Ext.Utils.ProfileBegin("Monster Lab Mutate All Entities")
	Logger:BasicDebug("=========== Starting Mutation Of All Encounters ===========")
	local success, error = xpcall(function(...)
		for encounterId, encounter in pairs(allSpawnedEntities or {}) do
			Logger:BasicDebug("======= Starting Mutation Of Encounter %s =======", encounter.name or encounterId)
			for mlEntityId, entity in pairs(encounter.entities) do
				---@type MutatorEntityVar
				local entityVar = {
					appliedMutators = {},
					appliedMutatorsPath = {},
					originalValues = {}
				}

				---@type EntityHandle
				local entityHandle = Ext.Entity.Get(entity.realEntityId)
				local rulesetRules = MonsterLabProfileExecutor:GetRulesetForEntity(entityHandle)

				MutationProfileExecutor:compileMutatorsForEntity(entityVar, rulesetRules.mutators, rulesetRules, 9999)

				if entityHandle.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] then
					MutatorInterface:undoMutator(entityHandle, entityVar)

					Ext.Timer.WaitFor(100, function()
						MutatorInterface:applyMutator(entityHandle, entityVar)
					end)
				else
					MutatorInterface:applyMutator(entityHandle, entityVar)
				end
			end
			Logger:BasicDebug("======= Finished Mutation Of Encounter %s =======", encounter.name or encounterId)
		end
	end, debug.traceback)

	if not success then
		Logger:BasicError("Unrecoverable error: %s", error)
	end

	Logger:BasicDebug("=========== Finished Mutation Of All Encounters ===========")
	Ext.Utils.ProfileEnd("Monster Lab Mutate All Entities")
end
