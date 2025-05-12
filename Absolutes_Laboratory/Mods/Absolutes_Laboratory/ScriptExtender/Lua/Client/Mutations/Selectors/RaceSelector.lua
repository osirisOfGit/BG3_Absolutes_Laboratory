RaceSelector = SelectorInterface:new("Race")

---@alias RaceId string
---@alias SubRaceId string

---@class RaceSelector : Selector
---@field criteriaValue {["RaceId"|"SubRaceId"]: RaceId|SubRaceId}

local racesWithSubraces = {}
local translationMap = {}
local raceOpts = {}
local subRaceOpts = {}
local function initialize()
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
				table.insert(raceOpts, race.DisplayName:Get())
				translationMap[race.DisplayName:Get()] = race.ResourceUUID
				translationMap[race.ResourceUUID] = race.DisplayName:Get()
			end

			if subRace and not foundSubraces[subRace.ResourceUUID] then
				table.insert(racesWithSubraces[race.ResourceUUID], subRace)
				table.sort(racesWithSubraces[race.ResourceUUID])

				foundSubraces[subRace.ResourceUUID] = true

				table.insert(subRaceOpts, subRace.DisplayName:Get())
				translationMap[subRace.DisplayName:Get()] = subRace.ResourceUUID
				translationMap[subRace.ResourceUUID] = subRace.DisplayName:Get()
			end
		end

		table.sort(raceOpts)
		table.insert(raceOpts, 1, "N/A")
		table.sort(subRaceOpts)
		table.insert(subRaceOpts, 1, "N/A")
	end
end

---@param parent ExtuiTreeParent
---@param existingSelector RaceSelector?
---@param onChangeFunc fun(selector: RaceSelector)
function RaceSelector:createSelector(parent, existingSelector, onChangeFunc)
	---@type RaceSelector
	local selector = existingSelector or TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.selector)
	if not existingSelector then
		selector.criteriaCategory = self.name
		selector.criteriaValue = {}
	end

	initialize()

	local raceCombo = parent:AddCombo("")
	raceCombo.IDContext = parent.IDContext .. "race"
	raceCombo.WidthFitPreview = true
	raceCombo.Options = raceOpts
	raceCombo.SelectedIndex = selector.criteriaValue["RaceId"] and (TableUtils:IndexOf(raceOpts, translationMap[selector.criteriaValue["RaceId"]]) - 1) or -1


	local subRaceCombo = parent:AddCombo("")
	subRaceCombo.IDContext = parent.IDContext .. "subRace"
	subRaceCombo.WidthFitPreview = true
	subRaceCombo.Options = subRaceOpts
	subRaceCombo.SelectedIndex = selector.criteriaValue["SubRaceId"] and (TableUtils:IndexOf(subRaceOpts, translationMap[selector.criteriaValue["SubRaceId"]]) - 1) or -1

	raceCombo.OnChange = function()
		selector.criteriaValue["RaceId"] = translationMap[raceOpts[raceCombo.SelectedIndex + 1]]
	end
end
