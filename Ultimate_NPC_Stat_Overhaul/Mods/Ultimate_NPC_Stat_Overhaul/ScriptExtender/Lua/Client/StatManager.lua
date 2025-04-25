StatManager = {}

---@class StatFieldsToParse
local statsToParse = {
	["Resistances"] = {
		"AcidResistance",
		"BludgeoningResistance",
		"ColdResistance",
		"FireResistance",
		"ForceResistance",
		"LightningResistance",
		"NecroticResistance",
		"PiercingResistance",
		"PoisonResistance",
		"PsychicResistance",
		"RadiantResistance",
		"SlashingResistance",
		"ThunderResistance",
	},
	["Abilities"] = {
		"Strength",
		"Dexterity",
		"Constitution",
		"Intelligence",
		"Wisdom",
		"Charisma",
	},
	"ActionResources",
	"Armor",
	"ArmorType",
	"Class",
	"DarkvisionRange",
	"DefaultBoosts",
	"DifficultyStatuses",
	"ExtraProperties",
	"Flags",
	"FOV",
	"GameSize",
	"Hearing",
	"Initiative",
	"Level",
	"MinimumDetectionRange",
	"Passives",
	"PersonalStatusImmunities",
	"ProficiencyBonusScaling",
	"ProficiencyBonus",
	"Progressions",
	"Sight",
	"SpellCastingAbility",
	"UnarmedAttackAbility",
	"UnarmedRangedAttackAbility",
	"VerticalFOV",
	"Vitality",
	"Weight",
	"XPReward",
}

---@param stat Character
---@param propertiesToRender StatFieldsToParse
---@param statDisplayTable ExtuiTable
local function buildDisplayTable(stat, propertiesToRender, statDisplayTable)
	local function makeDisplayable(value)
		if type(value) == "table" then
			return table.concat(value, "|")
		else
			return tostring(value)
		end
	end
	for key, value in TableUtils:OrderedPairs(propertiesToRender, function(key)
		return type(propertiesToRender[key]) == "string" and propertiesToRender[key] or key
	end) do
		local statDisplayRow = statDisplayTable:AddRow()
		local leftCell = statDisplayRow:AddCell()
		local rightCell = statDisplayRow:AddCell()
		local success, error = pcall(function()
			if type(value) == "string" then
				local statValue = makeDisplayable(stat[value])
				if statValue then
					leftCell:AddText(value)
					rightCell:AddText(statValue)
				end
			elseif type(value) == "table" then
				for _, fieldName in TableUtils:OrderedPairs(value) do
					local statValue = makeDisplayable(stat[fieldName])
					if statValue and statValue ~= "" then
						leftCell:AddText(fieldName)
						rightCell:AddText(statValue)
					end
				end
			end
		end)
		if not success then
			statDisplayRow:Destroy()
			Logger:BasicError(error)
		elseif #rightCell.Children == 0 then
			statDisplayRow:Destroy()
		end
	end
end


---@param characterStat Character
---@param parent ExtuiTreeParent
function StatManager:RenderDisplayWindow(characterStat, parent)
	---@param stat Character
	---@param propertiesToCopy StatFieldsToParse?
	---@param parentCell ExtuiTreeParent|ExtuiTableCell
	local function buildRecursiveStatTable(stat, propertiesToCopy, parentCell)
		---@type Character?
		local parentStat = stat.Using ~= "" and Ext.Stats.Get(stat.Using) or nil
		if parentStat then
			---@type StatFieldsToParse
			local overriddenProperties = {}
			---@type StatFieldsToParse
			local inheritedProperties = {}

			local function determineStatDiff(fieldName, key, parentKey)
				local isInherited
				if type(stat[fieldName]) == "table" then
					isInherited = TableUtils:CompareLists(stat[fieldName], parentStat[fieldName])
				else
					isInherited = tostring(stat[fieldName]) == tostring(parentStat[fieldName])
				end

				local tableToPopulate = isInherited and inheritedProperties or overriddenProperties

				if parentKey then
					if not tableToPopulate[parentKey] then
						tableToPopulate[parentKey] = {}
					end
					tableToPopulate[parentKey][key] = fieldName
				else
					tableToPopulate[key] = fieldName
				end
			end

			for key, value in TableUtils:OrderedPairs(propertiesToCopy or statsToParse) do
				local success, error = pcall(function()
					if type(value) == "string" then
						determineStatDiff(value, key)
					elseif type(value) == "table" then
						for index, fieldName in pairs(value) do
							determineStatDiff(fieldName, index, key)
						end
					end
				end)
				if not success then
					Logger:BasicError(error)
				end
			end

			parentCell:AddText(string.format("%s | Original Mod: %s ", stat.Name, stat.OriginalModId,
				stat.ModId ~= stat.OriginalModId and ("| Modified By: " .. stat.ModId) or "")).Font = "Large"

			local statDisplayTable = parentCell:AddTable("StatDisplay" .. stat.Name, 2)
			statDisplayTable:AddColumn("", "WidthFixed")
			statDisplayTable:AddColumn("", "WidthStretch")

			statDisplayTable.Borders = true
			if next(overriddenProperties) then
				buildDisplayTable(characterStat, overriddenProperties, statDisplayTable)
			end

			if next(inheritedProperties) then
				local statDisplayRow = statDisplayTable:AddRow()
				statDisplayRow:AddCell()

				local rightCell = statDisplayRow:AddCell()
				buildRecursiveStatTable(parentStat, inheritedProperties, rightCell)
			end

			if #statDisplayTable.Children == 0 then
				statDisplayTable:Destroy()
			end
		else
			parentCell:AddText(string.format("%s | Original Mod: %s ", stat.Name, stat.OriginalModId,
				stat.ModId ~= stat.OriginalModId and ("| Modified By: " .. stat.ModId) or "")).Font = "Large"

			local statDisplayTable = parentCell:AddTable("StatDisplay" .. stat.Name, 2)
			statDisplayTable:AddColumn("", "WidthFixed")
			statDisplayTable:AddColumn("", "WidthStretch")
			statDisplayTable.Borders = true
			buildDisplayTable(characterStat, propertiesToCopy or statsToParse, statDisplayTable)
		end
	end

	buildRecursiveStatTable(characterStat, nil, parent)
end
