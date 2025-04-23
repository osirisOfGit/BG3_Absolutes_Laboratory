---@alias LevelName string
---@alias Faction string
---@alias RaceUUID string
---@alias ClassUUID string
---@alias StatusName string

---@class LocalCharacterRecord
---@field displayName string
---@field icon string
---@field stat string
---@field levelName LevelName
---@field faction string
---@field templateId GUIDSTRING
---@field skillList CharacterSpellData[]
---@field statusList StatusName[]

---@class CharacterIndex
---@field acts {[LevelName]: GUIDSTRING}
---@field factions {[Faction]: GUIDSTRING}
---@field races {[RaceUUID]: GUIDSTRING}
---@field classes {[ClassUUID]: GUIDSTRING}

---@type CharacterIndex
CharacterIndex = {
	acts = {},
	factions = {},
	classes = {},
	races = {}
}

---@type {[GUIDSTRING]: LocalCharacterRecord}
local localCharList = {}

if Ext.IsServer() then
	Ext.Events.StatsLoaded:Subscribe(function(e)
		for id, localChar in pairs(Ext.ServerTemplate.GetAllLocalTemplates()) do
			if localChar.TemplateType == "character" then
				---@cast localChar CharacterTemplate

				localCharList[id] = {
					displayName = localChar.DisplayName:Get() or localChar.Name,
					icon = localChar.Icon,
					stat = localChar.Stats,
					faction = localChar.Faction,
					levelName = localChar.LevelName,
					templateId = localChar.TemplateName,
					skillList = localChar.SkillList and Ext.Json.Stringify(localChar.SkillList, { StringifyInternalTypes = true, IterateUserdata = true }),
					statusList = localChar.StatusList and Ext.Json.Stringify(localChar.StatusList, { StringifyInternalTypes = true, IterateUserdata = true })
				}
			end
		end

		local success = FileUtils:SaveTableToFile("localCharacterTemplates.json", localCharList)

		if success then
			Ext.ClientNet.PostMessageToServer(ModuleUUID .. "_LocalCharIndexed", "")
		end
	end)
else
	Ext.RegisterNetListener(ModuleUUID .. "_LocalCharIndexed", function(channel, payload, user)
		localCharList = FileUtils:LoadTableFile("localCharacterTemplates.json")

		for id, localCharRecord in pairs(localCharList) do
			
		end
	end)
end
