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

---@return number, fun():number wrapped coroutine
function CharacterIndex:hydrateIndex()
	local progressions = Ext.StaticData.GetAll("Progression")
	local templates = Ext.ClientTemplate.GetAllRootTemplates()

	local maxCount = TableUtils:CountElements(progressions) + TableUtils:CountElements(templates)
	return maxCount, coroutine.wrap(function()
		local count = 0
		local lastPercentage = 0

		for _, progressionId in pairs(progressions) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")

			self.displayNameMappings[progression.ResourceUUID] = progression.Name
			self.progressionIndex[progression.ResourceUUID] = progression.TableUUID
			addToTable(self.progressionIndex, progression.TableUUID, progression.ResourceUUID)
			count = count + 1
			if math.floor(((count / maxCount) * 100)) > lastPercentage then
				lastPercentage = math.floor(((count / maxCount) * 100))
				coroutine.yield(count)
			end
		end

		local templateIndex = self.templates
		for id, characterTemplate in pairs(templates) do
			if characterTemplate.TemplateType == "character" then
				---@cast characterTemplate CharacterTemplate

				self.displayNameMappings[id] = characterTemplate.DisplayName:Get() or characterTemplate.Name

				addToTable(templateIndex.acts, characterTemplate.LevelName, id)
				addToTable(templateIndex.races, characterTemplate.Race, id)
				if characterTemplate.Race then
					---@type ResourceRace
					local raceResource = Ext.StaticData.Get(characterTemplate.Race, "Race")

					if raceResource then
						self.displayNameMappings[characterTemplate.Race] = raceResource.DisplayName:Get() or raceResource.Name
					end
				end

				---@type Character
				local stat = Ext.Stats.Get(characterTemplate.Stats)

				if stat then
					addToTable(templateIndex.progressions, stat.Progressions, id)
				end
			end
			count = count + 1
			if math.floor(((count / maxCount) * 100)) > lastPercentage then
				lastPercentage = math.floor(((count / maxCount) * 100))
				coroutine.yield(count)
			end
		end
	end)
end
