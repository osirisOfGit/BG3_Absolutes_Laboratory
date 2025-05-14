RaceSelector = SelectorInterface:new("Race")

---@alias RaceId string
---@alias SubRaceId string

---@class RaceSelector : Selector
---@field criteriaValue {["RaceId"|"SubRaceId"]: RaceId|SubRaceId}

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
		table.insert(raceOpts, 1, "N/A")
		table.sort(subRaceOpts)
		table.insert(subRaceOpts, 1, "N/A")
	end
end

local function buildSubraceOpts(subRaces)
	local newSubraceOpts = {"N/A"}

	if subRaces then
		for _, subRace in ipairs(subRaceOpts) do
			if TableUtils:IndexOf(subRaces, translationMap[subRace]) then
				table.insert(newSubraceOpts, subRace)
			end
		end
	end

	return newSubraceOpts
end

---@param parent ExtuiTreeParent
---@param existingSelector RaceSelector?
function RaceSelector:renderSelector(parent, existingSelector)
	---@type RaceSelector
	local selector = existingSelector
	selector.criteriaValue = selector.criteriaValue or {}

	initialize()

	local raceCombo = parent:AddCombo("")
	raceCombo.IDContext = "race"
	raceCombo.WidthFitPreview = true
	raceCombo.Options = raceOpts
	raceCombo.SelectedIndex = selector.criteriaValue["RaceId"] and (TableUtils:IndexOf(raceOpts, translationMap[selector.criteriaValue["RaceId"]]) - 1) or 0

	local subRaceCombo = parent:AddCombo("")
	subRaceCombo.SameLine = true
	subRaceCombo.IDContext = "subRace"
	subRaceCombo.WidthFitPreview = true
	subRaceCombo.Options = buildSubraceOpts(racesWithSubraces[selector.criteriaValue and selector.criteriaValue["RaceId"]])
	subRaceCombo.SelectedIndex = selector.criteriaValue["SubRaceId"] and ((TableUtils:IndexOf(subRaceCombo.Options, translationMap[selector.criteriaValue["SubRaceId"]]) or 1) - 1) or 0
	subRaceCombo.Visible = raceCombo.SelectedIndex > 0 and #subRaceCombo.Options > 1

	raceCombo.OnChange = function()
		if raceCombo.SelectedIndex > 0 then
			selector.criteriaValue["RaceId"] = translationMap[raceOpts[raceCombo.SelectedIndex + 1]]

			subRaceCombo.Options = buildSubraceOpts(racesWithSubraces[selector.criteriaValue["RaceId"]])
			subRaceCombo.Visible = #subRaceCombo.Options > 1
			subRaceCombo.SelectedIndex = 0
		else
			selector.criteriaValue["RaceId"] = nil
			selector.criteriaValue["SubRaceId"] = nil
			subRaceCombo.Options = {}
			subRaceCombo.Visible = false
		end
	end

	subRaceCombo.OnChange = function()
		if subRaceCombo.SelectedIndex > 0 then
			selector.criteriaValue["SubRaceId"] = translationMap[subRaceCombo.Options[subRaceCombo.SelectedIndex + 1]]
		else
			selector.criteriaValue["SubRaceId"] = nil
		end
	end
end
