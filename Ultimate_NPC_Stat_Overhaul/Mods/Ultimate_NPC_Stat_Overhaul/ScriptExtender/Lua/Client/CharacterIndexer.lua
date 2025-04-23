---@alias LevelName string
---@alias Faction string
---@alias RaceUUID string
---@alias ProgressionTableId string
---@alias StatusName string

---@class CharacterIndex
---@field acts {[LevelName]: GUIDSTRING[]}
---@field factions {[Faction]: GUIDSTRING[]}?
---@field races {[RaceUUID]: GUIDSTRING[]}
---@field progressions {[ProgressionTableId]: GUIDSTRING[]}

CharacterIndex = {}

---@type CharacterIndex
CharacterIndex.templates = {
	acts = {},
	progressions = {},
	races = {}
}

---@type CharacterIndex
CharacterIndex.entities = {
	acts = {},
	factions = {},
	progressions = {},
	races = {}
}

---@type {[string]: string|string[]}
CharacterIndex.progressionIndex = {}

---@type {[GUIDSTRING]: string}
CharacterIndex.displayNameMappings = {}

---@param tableToAddTo table
---@param field string
---@param id string
local function addToTable(tableToAddTo, field, id)
	field = field == "" and "Unknown" or field

	if field then
		tableToAddTo[field] = tableToAddTo[field] or {}

		table.insert(tableToAddTo[field], id)
	end
end


local function hydrateIndex()
	for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
		---@type ResourceProgression
		local progression = Ext.StaticData.Get(progressionId, "Progression")

		CharacterIndex.displayNameMappings[progression.ResourceUUID] = progression.Name
		CharacterIndex.progressionIndex[progression.ResourceUUID] = progression.TableUUID
		addToTable(CharacterIndex.progressionIndex, progression.TableUUID, progression.ResourceUUID)
	end

	local templateIndex = CharacterIndex.templates
	for id, characterTemplate in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
		if characterTemplate.TemplateType == "character" then
			---@cast characterTemplate CharacterTemplate

			CharacterIndex.displayNameMappings[id] = characterTemplate.DisplayName:Get() or characterTemplate.Name

			addToTable(templateIndex.acts, characterTemplate.LevelName, id)
			addToTable(templateIndex.races, characterTemplate.Race, id)
			if characterTemplate.Race then
				---@type ResourceRace
				local raceResource = Ext.StaticData.Get(characterTemplate.Race, "Race")

				if raceResource then
					CharacterIndex.displayNameMappings[characterTemplate.Race] = raceResource.DisplayName:Get() or raceResource.Name
				end
			end

			---@type Character
			local stat = Ext.Stats.Get(characterTemplate.Stats)

			if stat then
				addToTable(templateIndex.progressions, stat.Progressions, id)
			end
		end
	end
end

Ext.Events.StatsLoaded:Subscribe(hydrateIndex)

Ext.Events.ResetCompleted:Subscribe(hydrateIndex)
