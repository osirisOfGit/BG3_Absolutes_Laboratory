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
			if race then
				---@type ResourceRace
				local subRace

				if race.ParentGuid and race.ParentGuid ~= "00000000-0000-0000-0000-000000000000" then
					local parentRace = Ext.StaticData.Get(race.ParentGuid, "Race")
					if parentRace then
						subRace = race
						race = Ext.StaticData.Get(race.ParentGuid, "Race")
					end
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
			else
				Logger:BasicWarning("Could not retrieve Race Data for RaceId %s", raceId)
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
		local cells = {}
		for i = 0, parent.Columns do
			table.insert(cells, row:AddCell())
		end

		local selectAll = not next(selectedSubRaces)
		for _, subRace in TableUtils:OrderedPairs(subRaces, function(key)
			return translationMap[subRaces[key]]
		end) do
			columnIndex = columnIndex + 1

			local parent = cells[columnIndex % parent.Columns] or cells[parent.Columns]

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
	initialize()

	---@type RaceSelector
	local selector = existingSelector
	selector.criteriaValue = selector.criteriaValue or {
		["RaceId"] = translationMap[raceOpts[1]],
		["SubRaceIds"] = {}
	} --[[@as RaceCriteria]]


	local raceCombo = parent:AddCombo("")
	raceCombo.IDContext = "race"
	raceCombo.WidthFitPreview = true
	raceCombo.Options = raceOpts
	raceCombo.SelectedIndex = selector.criteriaValue.RaceId and (TableUtils:IndexOf(raceOpts, translationMap[selector.criteriaValue.RaceId]) - 1) or 0

	local subRaceGroup = parent:AddTable("SubRaces", 6)

	subRaceGroup.SizingFixedFit = true
	buildSubraceOpts(racesWithSubraces[selector.criteriaValue.RaceId], subRaceGroup, selector.criteriaValue.SubRaceIds)

	raceCombo.OnChange = function()
		if raceCombo.SelectedIndex > -1 then
			selector.criteriaValue.RaceId = translationMap[raceOpts[raceCombo.SelectedIndex + 1]]

			selector.criteriaValue.SubRaceIds = nil
			selector.criteriaValue.SubRaceIds = {}
			buildSubraceOpts(racesWithSubraces[selector.criteriaValue.RaceId], subRaceGroup, selector.criteriaValue.SubRaceIds)
		else
			selector.criteriaValue.RaceId = nil
			selector.criteriaValue.SubRaceIds = nil
			buildSubraceOpts(racesWithSubraces[selector.criteriaValue.RaceId], subRaceGroup, selector.criteriaValue.SubRaceIds)
		end
	end
end

---@param selector RaceSelector
function RaceSelector:handleDependencies(_, selector, removeMissingDependencies)
	if removeMissingDependencies then
		if not Ext.StaticData.Get(selector.criteriaValue.RaceId, "Race") then
			selector.criteriaValue = {
				RaceId = nil,
				SubRaceIds = {}
			}
		elseif selector.criteriaValue.SubRaceIds then
			for i, subRaceId in ipairs(selector.criteriaValue.SubRaceIds) do
				if not Ext.StaticData.Get(subRaceId, "Race") then
					selector.criteriaValue.SubRaceIds[i] = nil
				end
			end
			TableUtils:ReindexNumericTable(selector.criteriaValue.SubRaceIds)
		end
	else
		local raceSources = Ext.StaticData.GetSources("Race")

		local sources = {
			[selector.criteriaValue.RaceId] = TableUtils:IndexOf(raceSources, function(value)
				return TableUtils:IndexOf(value, selector.criteriaValue.RaceId) ~= nil
			end)
		}

		if selector.criteriaValue.SubRaceIds then
			for _, subRaceId in ipairs(selector.criteriaValue.SubRaceIds) do
				sources[subRaceId] = TableUtils:IndexOf(raceSources, function(value)
					return TableUtils:IndexOf(value, subRaceId) ~= nil
				end)
			end
		end

		for raceId, source in pairs(sources) do
			selector.modDependencies = selector.modDependencies or {}
			if not selector.modDependencies[source] then
				local name, author, version = Helpers:BuildModFields(source)
				if author == "Larian" then
					goto continue
				end
				selector.modDependencies[source] = {
					modName = name,
					modAuthor = author,
					modVersion = version,
					modId = source,
					packagedItems = {}
				}

				---@type ResourceRace
				local raceData = Ext.StaticData.Get(raceId, "Race")
				selector.modDependencies[source].packagedItems[raceId] = raceData.DisplayName:Get() or raceData.Name
			end
			::continue::
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
			if race == criteriaValue.RaceId then
				return true
			else
				---@type ResourceRace
				local raceResource = Ext.StaticData.Get(race, "Race")
				return raceResource.ParentGuid == criteriaValue.RaceId
			end
		else
			return TableUtils:IndexOf(criteriaValue.SubRaceIds, race) ~= nil
		end
	end
end
