Ext.Vars.RegisterModVariable(ModuleUUID, "RecorderTracker", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

Channels.InitiateRecording = Ext.Net.CreateChannel(ModuleUUID, "InitiateRecording")
Channels.ReportRecordingProgress = Ext.Net.CreateChannel(ModuleUUID, "ReportRecordingProgress")

EntityRecorder = {}

EntityRecorder.fileName = "recordedEntities.json"

-- Thanks Aahz
EntityRecorder.Levels = {
	[1] = "TUT_Avernus_C", -- nautiloid
	[2] = "WLD_Main_A", -- beach, grove, goblin camp, underdark
	[3] = "CRE_Main_A", -- mountain pass, creche
	[4] = "SCL_Main_A", -- shadow cursed lands
	[5] = "INT_Main_A", -- camp before baldur's gate
	[6] = "BGO_Main_A", -- rivington, wyrm's crossing
	[7] = "CTY_Main_A", -- lower city, sewers
	[8] = "IRN_Main_A", -- iron throne
	[9] = "END_Main",   -- morphic pool
	TUT_Avernus_C = 1,
	WLD_Main_A = 2,
	CRE_Main_A = 3,
	SCL_Main_A = 4,
	INT_Main_A = 5,
	BGO_Main_A = 6,
	CTY_Main_A = 7,
	IRN_Main_A = 8,
	END_Main = 9,
}

---@class EntityRecord
---@field Name string
---@field Template GUIDSTRING
---@field Race RaceUUID
---@field Faction Faction
---@field Progressions ProgressionTableId[]
---@field Tags TAG[]
---@field Stat string
---@field Abilities {[string]: number}

if Ext.IsClient() then

else
	Channels.InitiateRecording:SetHandler(function(data, user)
		Osi.AutoSave()

		---@type {[string] : {[GUIDSTRING] : EntityRecord}}
		local recordedEntities = {}

		local recorderTracker = {}

		for _, levelName in ipairs(EntityRecorder.Levels) do
			recordedEntities[levelName] = {}
			recorderTracker[levelName] = "Not Scanned"
		end

		FileUtils:SaveTableToFile(EntityRecorder.fileName, recordedEntities)

		Ext.Vars.GetModVariables(ModuleUUID).RecorderTracker = recorderTracker

		EntityRecorder:RecordAndTeleport(Ext.Entity.Get(Osi.GetHostCharacter()).Level.LevelName)
	end)

	Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
		EntityRecorder:RecordAndTeleport(levelName)
	end)

	function EntityRecorder:RecordAndTeleport(level)
		local recorderTracker = Ext.Vars.GetModVariables(ModuleUUID).RecorderTracker

		if recorderTracker then
			for l, levelName in ipairs(self.Levels) do
				if type(recorderTracker[levelName]) == "string" then
					if level ~= levelName then
						Osi.TeleportPartiesToLevelWithMovie(self.Levels[levelName], "", "")
						return
					else
						---@type {[GUIDSTRING] : EntityRecord}
						local recordedEntities = FileUtils:LoadTableFile(self.fileName)[levelName]

						Channels.ReportRecordingProgress:Broadcast({
							LevelName = levelName,
							Percentage = 0
						})

						local entitiesOnServer = Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")
						local maxCount = #entitiesOnServer

						local lastPercentage = 0

						for i, entity in ipairs(entitiesOnServer) do
							if Osi.IsDead(entity.Uuid.EntityUuid) == 0 then
								recordedEntities[entity.Uuid.EntityUuid] = {}
								local entityRecord = recordedEntities[entity.Uuid.EntityUuid]

								entityRecord.Name = (entity.DisplayName and entity.DisplayName.Name:Get())
									or (entity.ServerCharacter.Template and entity.ServerCharacter.Template.DisplayName:Get())
									or entity.Uuid.EntityUuid

								entityRecord.Race = entity.Race.Race
								entityRecord.Faction = entity.Faction.field_8
								entityRecord.Stat = entity.Data.StatsId
								entityRecord.Template = entity.ServerCharacter.Template.Id
								entityRecord.Tags = entity.Tag.Tags
								entityRecord.Abilities = {}
								for abilityId, val in ipairs(entity.BaseStats.BaseAbilities) do
									entityRecord.Abilities[tostring(Ext.Enums.AbilityId[abilityId])] = val
								end

								entityRecord.Progressions = {}
								for _, progressionContainer in ipairs(entity.ProgressionContainer.Progressions) do
									for _, progression in ipairs(progressionContainer) do
										table.insert(entityRecord.Progressions, progression.ProgressionMeta.Progression)
									end
								end
							end

							if math.floor(((i / maxCount) * 100)) > lastPercentage then
								lastPercentage = math.floor(((i / maxCount) * 100))

								Channels.ReportRecordingProgress:Broadcast({
									LevelName = levelName,
									Percentage = lastPercentage
								})
							end
						end

						FileUtils:SaveTableToFile(self.fileName, recordedEntities)
						recorderTracker[levelName] = TableUtils:CountElements(recordedEntities)
						Ext.Vars.GetModVariables(ModuleUUID).RecorderTracker = recorderTracker
					end
				end
			end

			Ext.Vars.GetModVariables(ModuleUUID).RecorderTracker = nil
		end
	end
end
