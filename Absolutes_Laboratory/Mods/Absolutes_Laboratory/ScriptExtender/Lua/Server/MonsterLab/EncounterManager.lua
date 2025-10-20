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

EncounterManager = {
	mazzleLib = Mods.Mazzle_Lib,
	---@type Mazzle_Orbs
	mazzleOrbs = nil,
	---@type Map
	mazzleMap = nil,
	---@type {[Guid]: {[string]: Guid}}
	encounterVisualizations = {}
}

Ext.Events.SessionLoaded:Subscribe(function(e)
	EncounterManager.mazzleLib = Mods.Mazzle_Lib

	if EncounterManager.mazzleLib then
		EncounterManager.mazzleOrbs = EncounterManager.mazzleLib.Mazzle_Orbs --[[@as Mazzle_Orbs]]
		EncounterManager.mazzleMap = EncounterManager.mazzleLib.Map
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
		local self = EncounterManager
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
---@field encounterId Guid
---@field mlEntityId Guid

---@class MonsterLabEntity_Spawned : MonsterLabEntity
---@field realEntityId Guid

---@class MonsterLabEncounter_Spawned : MonsterLabEncounter
---@field entities {[Guid]: MonsterLabEntity_Spawned}

---@alias MonsterLab_SpawnedEntities {[Guid]: MonsterLabEncounter_Spawned}

---@class ManageEncounterRequest
---@field encounterId Guid
---@field encounter MonsterLabEncounter? not present if delete is true
---@field profileId Guid?
---@field delete boolean?

---@type MonsterLab_SpawnedEntities
local allSpawnedEntities

Channels.ManageEncounterSpawns:SetHandler(
---@param request ManageEncounterRequest
	function(request)
		if not allSpawnedEntities then
			allSpawnedEntities = Ext.Vars.GetModVariables(ModuleUUID).MonsterLab_SpawnedEntities or {}
		end

		allSpawnedEntities[request.encounterId] = allSpawnedEntities[request.encounterId] or {}

		local encounterEntities = allSpawnedEntities[request.encounterId]
		encounterEntities.entities = encounterEntities.entities or {}

		if request.delete then
			for _, entity in pairs(encounterEntities.entities) do
				if entity.realEntityId then
					Osi.RequestDeleteTemporary(entity.realEntityId)
				end
			end
			allSpawnedEntities[request.encounterId] = nil
		else
			for mlEntityId, mlEntity in pairs(request.encounter.entities) do
				if encounterEntities.entities[mlEntityId] and encounterEntities.entities[mlEntityId].realEntityId and encounterEntities.entities[mlEntityId].template == mlEntity.template then
					local spawnedEntity = encounterEntities.entities[mlEntityId]
					if not TableUtils:CompareLists(mlEntity.coordinates, spawnedEntity.coordinates) then
						Osi.TeleportToPosition(spawnedEntity.realEntityId, mlEntity.coordinates[1], mlEntity.coordinates[2], mlEntity.coordinates[3])
						spawnedEntity.coordinates = mlEntity.coordinates
					end

					if mlEntity.rotation ~= spawnedEntity.rotation then
						EncounterManager.mazzleMap:Turn_To_Angle(spawnedEntity.realEntityId, mlEntity.rotation)
						spawnedEntity.rotation = mlEntity.rotation
					end

					if mlEntity.animation.simple then
						if mlEntity.animation.simple ~= spawnedEntity.animation.simple then
							Osi.PlayAnimation(spawnedEntity.realEntityId, mlEntity.animation.simple)
						end
					else
						if not TableUtils:CompareLists(mlEntity.animation.looping, spawnedEntity.animation.looping) then
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

					if request.encounter.faction and request.encounter.faction ~= Osi.GetFaction(spawnedEntity.realEntityId) then
						Osi.SetFaction(spawnedEntity.realEntityId, request.encounter.faction)
					end

					if request.encounter.combatGroupId and request.encounter.combatGroupId ~= Osi.GetCombatGroupID(spawnedEntity.realEntityId) then
						Osi.SetCombatGroupID(spawnedEntity.realEntityId, request.encounter.combatGroupId)
					end
				elseif not TableUtils:CompareLists(mlEntity.coordinates, { 0, 0, 0 }) then
					if encounterEntities.entities[mlEntityId] and encounterEntities.entities[mlEntityId].realEntityId then
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

					Ext.Timer.WaitFor(100, function()
						---@type EntityHandle
						local entity = Ext.Entity.Get(encounterEntities.entities[mlEntityId].realEntityId)
						entity.Vars.AbsolutesLaboratory_MonsterLab_Entity = {
							profileId = request.profileId,
							encounterId = request.encounterId,
							mlEntityId = mlEntityId,
						} --[[@as MonsterLab_EntityVariable]]

						Osi.SetCombatGroupID(entity.Uuid.EntityUuid, request.encounter.combatGroupId)
						Osi.SetFaction(entity.Uuid.EntityUuid, request.encounter.faction)

						Osi.SetStoryDisplayName(entity.Uuid.EntityUuid, mlEntity.displayName)

						if mlEntity.title and mlEntity.title ~= "" then
							Osi.ObjectSetTitle(entity.Uuid.EntityUuid, mlEntity.title)
						end

						if EncounterManager.mazzleLib then
							EncounterManager.mazzleMap:Turn_To_Angle(entity.Uuid.EntityUuid, mlEntity.rotation)
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
					end)
				end
			end
		end

		Ext.Vars.GetModVariables(ModuleUUID).MonsterLab_SpawnedEntities = allSpawnedEntities
	end)
