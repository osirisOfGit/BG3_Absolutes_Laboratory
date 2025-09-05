EncounterManager = {
	mazzleLib = Mods.Mazzle_Lib,
	---@type Mazzle_Orbs
	mazzleOrbs = nil,
	---@type {[Guid]: {[string]: Guid}}
	encounterVisualizations = {}
}

Ext.Events.SessionLoaded:Subscribe(function(e)
	EncounterManager.mazzleLib = Mods.Mazzle_Lib

	if EncounterManager.mazzleLib then
		EncounterManager.mazzleOrbs = EncounterManager.mazzleLib.Mazzle_Orbs --[[@as Mazzle_Orbs]]

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

Channels.SpawnEncounterEntity:SetHandler(function (data, user)
	
end)
