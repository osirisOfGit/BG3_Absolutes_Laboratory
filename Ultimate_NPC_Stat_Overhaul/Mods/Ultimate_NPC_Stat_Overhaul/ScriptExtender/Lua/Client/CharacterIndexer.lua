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
	factions = {},
	races = {}
}

---@type CharacterIndex
CharacterIndex.entities = {
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
	field = (not field or field == "") and "UNKOWN" or field
	tableToAddTo[field] = tableToAddTo[field] or {}

	table.insert(tableToAddTo[field], id)
end

---@return fun():number wrapped coroutine
function CharacterIndex:hydrateTemplateIndex()
	local progressions = Ext.StaticData.GetAll("Progression")
	local templates = Ext.ClientTemplate.GetAllRootTemplates()

	local maxCount = TableUtils:CountElements(progressions) + TableUtils:CountElements(templates)
	return coroutine.wrap(function()
		local count = 0
		local lastPercentage = 0

		for _, progressionId in pairs(progressions) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")

			if progression and progression.ResourceUUID then
				self.displayNameMappings[progression.ResourceUUID] = progression.Name or "Unknown"
				self.progressionIndex[progression.ResourceUUID] = progression.TableUUID
				addToTable(self.progressionIndex, progression.TableUUID, progression.ResourceUUID)
				count = count + 1
				if math.floor(((count / maxCount) * 100)) > lastPercentage then
					lastPercentage = math.floor(((count / maxCount) * 100))
					coroutine.yield(count / maxCount)
				end
			end
		end

		local templateIndex = self.templates

		---@param faction ResourceFaction
		---@param id string
		local function buildFaction(faction, id)
			self.displayNameMappings[faction.ResourceUUID] = faction.Faction

			if faction.ParentGuid ~= "00000000-0000-0000-0000-000000000000" then
				buildFaction(Ext.StaticData.Get(faction.ParentGuid, "Faction"), id)
			else
				addToTable(templateIndex.factions, faction.ResourceUUID, id)
			end
		end

		for id, characterTemplate in pairs(templates) do
			if characterTemplate.TemplateType == "character" and not string.find(characterTemplate.Name, "Timeline") then
				---@cast characterTemplate CharacterTemplate

				self.displayNameMappings[id] = characterTemplate.DisplayName:Get() or characterTemplate.Name or characterTemplate.TemplateName

				addToTable(templateIndex.acts, characterTemplate.LevelName, id)
				addToTable(templateIndex.races, characterTemplate.Race, id)
				if characterTemplate.Race then
					---@type ResourceRace
					local raceResource = Ext.StaticData.Get(characterTemplate.Race, "Race")

					if raceResource then
						self.displayNameMappings[characterTemplate.Race] = raceResource.DisplayName:Get() or raceResource.Name
					end
				end

				if characterTemplate.CombatComponent.Faction then
					---@type ResourceFaction	
					local faction = Ext.StaticData.Get(characterTemplate.CombatComponent.Faction, "Faction")
					if faction then
						buildFaction(faction, id)
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
				coroutine.yield(count / maxCount)
			end
		end
	end)
end

function CharacterIndex:hydrateEntityIndex()
	local entities = Ext.Entity.GetAllEntitiesWithComponent("ClientCharacter")
	local maxCount = #entities

	local index = self.entities
	return coroutine.wrap(function()
		local count = 0
		local lastPercentage = 0

		for _, entity in ipairs(entities) do
			if not entity.Player and not entity.PartyMember then
				local id = entity.Uuid.EntityUuid

				if not self.displayNameMappings[id] then
					self.displayNameMappings[id] = (entity.DisplayName and entity.DisplayName.Name:Get())
						or (entity.ClientCharacter.Template and entity.ClientCharacter.Template.DisplayName:Get())
						or id
				end

				addToTable(index.factions, entity.Faction and entity.Faction.field_8, id)
				addToTable(index.races, entity.Race and entity.Race.Race, id)

				if entity.ProgressionContainer then
					for _, progressionGroup in ipairs(entity.ProgressionContainer.Progressions) do
						for _, progression in ipairs(progressionGroup) do
							---@cast progression ProgressionMetaComponent

							addToTable(index.progressions, self.progressionIndex[progression.Progression], id)
						end
					end
				end
			end

			count = count + 1
			if math.floor(((count / maxCount) * 100)) > lastPercentage then
				lastPercentage = math.floor(((count / maxCount) * 100))
				coroutine.yield(count / maxCount)
			end
		end
	end)
end
