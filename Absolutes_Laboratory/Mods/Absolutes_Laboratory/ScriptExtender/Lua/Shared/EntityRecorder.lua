Channels.InitiateRecording = Ext.Net.CreateChannel(ModuleUUID, "InitiateRecording")
Channels.ReportRecordingProgress = Ext.Net.CreateChannel(ModuleUUID, "ReportRecordingProgress")

EntityRecorder = {}

EntityRecorder.recorderFilename = "recordedEntities.json"
EntityRecorder.trackerFilename = "recorderTracker.json"

-- Thanks Aahz
EntityRecorder.Levels = {
	[1] = "Global",     -- global level
	[2] = "TUT_Avernus_C", -- nautiloid
	[3] = "WLD_Main_A", -- beach, grove, goblin camp, underdark
	[4] = "CRE_Main_A", -- mountain pass, creche
	[5] = "SCL_Main_A", -- shadow cursed lands
	[6] = "INT_Main_A", -- camp before baldur's gate
	[7] = "BGO_Main_A", -- rivington, wyrm's crossing
	[8] = "CTY_Main_A", -- lower city, sewers
	[9] = "IRN_Main_A", -- iron throne
	[10] = "END_Main",  -- morphic pool
	Global = 1,
	TUT_Avernus_C = 2,
	WLD_Main_A = 3,
	CRE_Main_A = 4,
	SCL_Main_A = 5,
	INT_Main_A = 6,
	BGO_Main_A = 7,
	CTY_Main_A = 8,
	IRN_Main_A = 9,
	END_Main = 10,
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
	---@return {[string]: {[GUIDSTRING]: EntityRecord}}
	function EntityRecorder:GetEntities()
		return FileUtils:LoadTableFile(self.recorderFilename) or {}
	end

	---@param entityId GUIDSTRING
	---@return string? LevelName
	function EntityRecorder:GetLevelForEntity(entityId)
		for level, entities in pairs(FileUtils:LoadTableFile(self.recorderFilename) or {}) do
			if entities[entityId] then
				return level
			end
		end
	end

	---@param parent ExtuiTreeParent
	function EntityRecorder:BuildButton(parent)
		if Ext.ClientNet.IsHost() then
			local button = parent:AddButton("Index All Alive Character Entities")
			button:Tooltip():AddText([[
	 This will teleport you to each level in the game and record all the entities loaded onto the server for that level
You only need to do this once or after you install mods that would add new entities - a local file will be written containing the results.
A save will be initiated first so you can load back to it - this MAY spoil different parts of the game, but if you're using this mod, you should be fine with that.
Don't reload, restart, or otherwise mess with the game until the process is completed.
		]])

			button.OnClick = function()
				Channels.InitiateRecording:SendToServer({})
			end
		end
	end

	---@type ExtuiWindow?
	local reportWindow

	Channels.ReportRecordingProgress:SetHandler(function(data, user)
		if not reportWindow then
			reportWindow = Ext.IMGUI.NewWindow("Entity Recorder Report")
			reportWindow:SetStyle("Alpha", 1)
			reportWindow.AlwaysAutoResize = true
			reportWindow.NoTitleBar = true
			reportWindow.NoCollapse = true
			reportWindow.NoSavedSettings = true
			reportWindow:SetPos({ Ext.IMGUI.GetViewportSize()[1] / 2, Ext.IMGUI.GetViewportSize()[2] / 2 }, "Always")
		elseif not data.LevelName then
			local function fadeOut()
				if reportWindow:GetStyle("Alpha") > 0 then
					reportWindow:SetStyle("Alpha", reportWindow:GetStyle("Alpha") - 0.1)
					Ext.Timer.WaitFor(300, function()
						fadeOut()
					end)
				else
					reportWindow:Destroy()
				end
			end

			Ext.Timer.WaitFor(3000, function()
				fadeOut()
			end)
		end

		Helpers:KillChildren(reportWindow)

		local displayTable = Styler:TwoColumnTable(reportWindow)
		displayTable.SizingFixedSame = true

		local headers = displayTable:AddRow()
		headers.Headers = true
		headers:AddCell():AddText("Level Name")
		headers:AddCell():AddText("# of Entities")

		for _, levelName in ipairs(EntityRecorder.Levels) do
			local row = displayTable:AddRow()

			row:AddCell():AddText(levelName)

			row:AddCell():AddText(data.LevelName == levelName and "Scanning" or data.Tracker[levelName])
		end
	end)
else
	Channels.InitiateRecording:SetHandler(function(data, user)
		Osi.AutoSave()

		Ext.Timer.WaitFor(5000, function()
			---@type {[string] : {[GUIDSTRING] : EntityRecord}}
			local recordedEntities = {}

			local recorderTracker = {}

			for _, levelName in ipairs(EntityRecorder.Levels) do
				recordedEntities[levelName] = {}
				recorderTracker[levelName] = "Not Scanned"
			end

			FileUtils:SaveTableToFile(EntityRecorder.recorderFilename, recordedEntities)

			FileUtils:SaveTableToFile(EntityRecorder.trackerFilename, recorderTracker)

			EntityRecorder:RecordAndTeleport(Ext.Entity.Get(Osi.GetHostCharacter()).Level.LevelName)
		end)
	end)

	Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(levelName, isEditorMode)
		EntityRecorder:RecordAndTeleport(levelName)
	end)

	function EntityRecorder:RecordAndTeleport(level)
		local recorderTracker = FileUtils:LoadTableFile(EntityRecorder.trackerFilename)

		if next(recorderTracker) then
			for l, levelName in ipairs(self.Levels) do
				if type(recorderTracker[levelName]) == "string" then
					if level ~= levelName and levelName ~= "Global" then
						Osi.TeleportPartiesToLevelWithMovie(levelName, "", "")
						return
					else
						local recordedLevels = FileUtils:LoadTableFile(self.recorderFilename)
						---@type {[GUIDSTRING] : EntityRecord}
						local recordedEntities = recordedLevels[levelName]

						Channels.ReportRecordingProgress:Broadcast({
							Tracker = recorderTracker,
							LevelName = levelName,
						})

						local entities = {}

						if levelName == "Global" then
							for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("IsGlobal")) do
								if entity.ServerCharacter then
									table.insert(entities, entity)
								end
							end
						else
							entities = Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")
						end

						for _, entity in ipairs(entities) do
							if Osi.IsDead(entity.Uuid.EntityUuid) == 0 and (levelName == "Global" or not entity.IsGlobal) then
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
									if abilityId > 1 then
										entityRecord.Abilities[tostring(Ext.Enums.AbilityId[abilityId - 1])] = val
									end
								end

								entityRecord.Progressions = {}
								for _, progressionContainer in ipairs(entity.ProgressionContainer.Progressions) do
									for _, progression in ipairs(progressionContainer) do
										table.insert(entityRecord.Progressions, progression.ProgressionMeta.Progression)
									end
								end
							end
						end

						FileUtils:SaveTableToFile(self.recorderFilename, recordedLevels)
						recorderTracker[levelName] = TableUtils:CountElements(recordedEntities)
						FileUtils:SaveTableToFile(EntityRecorder.trackerFilename, recorderTracker)
					end
				end
			end

			FileUtils:SaveTableToFile(EntityRecorder.trackerFilename, {})
			Channels.ReportRecordingProgress:Broadcast({
				Tracker = recorderTracker
			})
			recorderTracker = nil
			Helpers:ForceGarbageCollection("Post Entity Recording")
		end
	end
end
