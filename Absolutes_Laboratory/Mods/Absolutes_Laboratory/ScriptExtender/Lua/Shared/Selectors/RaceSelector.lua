RaceSelector = SelectorInterface:new("Race")

---@class RaceCriteria
---@field RaceId string
---@field SubRaceIds string[]

---@class RaceSelector : Selector
---@field criteriaValue RaceCriteria

---@type {[string]: string[]}
local racesWithSubraces = {}
---@type {[string]: string}
local translationMap = {}

---@type string[]
local raceOpts = {}

---@type string[]
local subRaceOpts = {}

local function initialize()
	---@param race ResourceRace
	---@return string
	local function getName(race)
		local name = race.DisplayName:Get() or race.Name
		if translationMap[name] and translationMap[name] ~= race.ResourceUUID then
			name = string.format("%s (%s)", name, race.ResourceUUID:sub(-5))
		end
		return name
	end
	if not next(racesWithSubraces) then
		local foundSubraces = {}
		for _, raceId in pairs(Ext.StaticData.GetAll("Race")) do
			---@type ResourceRace
			local race = Ext.StaticData.Get(raceId, "Race")
			---@type ResourceRace
			local subRace

			if race.ParentGuid and race.ParentGuid ~= "00000000-0000-0000-0000-000000000000" then
				subRace = race
				race = Ext.StaticData.Get(race.ParentGuid, "Race")
			end

			if not racesWithSubraces[race.ResourceUUID] then
				racesWithSubraces[race.ResourceUUID] = {}
				local name = getName(race)
				table.insert(raceOpts, name)
				translationMap[name] = race.ResourceUUID
				translationMap[race.ResourceUUID] = name
			end

			if subRace and not foundSubraces[subRace.ResourceUUID] then
				table.insert(racesWithSubraces[race.ResourceUUID], subRace.ResourceUUID)

				foundSubraces[subRace.ResourceUUID] = true

				local name = getName(subRace)
				table.insert(subRaceOpts, name)
				translationMap[name] = subRace.ResourceUUID
				translationMap[subRace.ResourceUUID] = name
			end
		end

		table.sort(raceOpts)
		table.sort(subRaceOpts)
	end
end

---@param subRaces string[]
---@param parent ExtuiTable
---@param selectedSubRaces string[]
local function buildSubraceOpts(subRaces, parent, selectedSubRaces)
	Helpers:KillChildren(parent)

	local columnIndex = 0
	if subRaces then
		local row = parent:AddRow()
		local cells = { row:AddCell(), row:AddCell(), row:AddCell() }

		local selectAll = not selectedSubRaces()
		for _, subRace in TableUtils:OrderedPairs(subRaces, function(key)
			return translationMap[subRaces[key]]
		end) do
			columnIndex = columnIndex + 1

			parent = cells[columnIndex % 3] or cells[3]

			local select = parent:AddCheckbox(translationMap[subRace])

			if selectAll then
				select.Checked = true
				table.insert(selectedSubRaces, subRace)
			else
				select.Checked = TableUtils:IndexOf(selectedSubRaces, subRace) ~= nil
			end

			select.OnChange = function()
				if select.Checked then
					table.insert(selectedSubRaces, subRace)
				else
					table.remove(selectedSubRaces, TableUtils:IndexOf(selectedSubRaces, subRace))
				end
			end
		end
	end
end

---@param parent ExtuiTreeParent
---@param existingSelector RaceSelector?
function RaceSelector:renderSelector(parent, existingSelector)
	---@type RaceSelector
	local selector = existingSelector
	selector.criteriaValue = selector.criteriaValue or {
		["RaceId"] = nil,
		["SubRaceIds"] = {}
	} --[[@as RaceCriteria]]

	initialize()

	local raceCombo = parent:AddCombo("")
	raceCombo.IDContext = "race"
	raceCombo.WidthFitPreview = true
	raceCombo.Options = raceOpts
	raceCombo.SelectedIndex = selector.criteriaValue.RaceId and (TableUtils:IndexOf(raceOpts, translationMap[selector.criteriaValue.RaceId]) - 1) or 0

	local subRaceGroup = parent:AddTable("SubRaces", 3)
	subRaceGroup.SizingFixedFit = true
	buildSubraceOpts(racesWithSubraces[selector.criteriaValue.RaceId], subRaceGroup, selector.criteriaValue.SubRaceIds)

	raceCombo.OnChange = function()
		if raceCombo.SelectedIndex > 0 then
			selector.criteriaValue.RaceId = translationMap[raceOpts[raceCombo.SelectedIndex + 1]]

			selector.criteriaValue.SubRaceIds = nil
			selector.criteriaValue.SubRaceIds = {}
			buildSubraceOpts(racesWithSubraces[selector.criteriaValue.RaceId], subRaceGroup, selector.criteriaValue.SubRaceIds)
		else
			selector.criteriaValue.RaceId = nil
			selector.criteriaValue.SubRaceIds = nil
			selector.criteriaValue.SubRaceIds = {}
		end
	end
end

---@param selector RaceSelector
---@return fun(entity: EntityHandle|EntityRecord):boolean
function RaceSelector:predicate(selector)
	local criteriaValue = selector.criteriaValue

	return function(entity)
		local race
		if type(entity) == "userdata" then
			---@cast entity EntityHandle
			race = entity.Race.Race
		else
			---@cast entity EntityRecord
			race = entity.Race
		end

		if not next(criteriaValue.SubRaceIds) then
			return race == criteriaValue.RaceId
		else
			return TableUtils:IndexOf(criteriaValue.SubRaceIds, race) ~= nil
		end
	end
end
