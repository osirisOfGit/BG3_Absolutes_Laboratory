CharacterWindow = {}

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

---@param parent ExtuiTreeParent
---@param templateId string
function CharacterWindow:BuildWindow(parent, templateId)
	local displayTable = parent:AddTable("characterDisplayWindow", 3)
	displayTable:AddColumn("", "WidthStretch")
	displayTable:AddColumn("", "WidthFixed")
	displayTable:AddColumn("", "WidthStretch")

	local row = displayTable:AddRow()
	row:AddCell()
	local displayCell = row:AddCell()
	row:AddCell()

	---@type CharacterTemplate
	local characterTemplate = Ext.Template.GetRootTemplate(templateId)

	if characterTemplate then
		Styler:MiddleAlignedColumnLayout(displayCell, function(ele)
			ele:AddImage(characterTemplate.Icon, { 128, 128 })
		end)

		Styler:CheapTextAlign(CharacterIndex.displayNameMappings[templateId], displayCell, "Big")
		Styler:CheapTextAlign(string.gsub(characterTemplate.FileName, "^.*[\\/]Mods[\\/]", ""), displayCell)
		Styler:CheapTextAlign(characterTemplate.LevelName, displayCell)

		if characterTemplate.Stats and characterTemplate.Stats ~= "" then
			---@type Character
			local characterStat = Ext.Stats.Get(characterTemplate.Stats)

			if characterStat then
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
							local tableToPopulate = tostring(stat[fieldName]) == tostring(parentStat[fieldName]) and inheritedProperties or overriddenProperties

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
							for key, value in TableUtils:OrderedPairs(overriddenProperties, function(key)
								return type(overriddenProperties[key]) == "string" and overriddenProperties[key] or key
							end) do
								local statDisplayRow = statDisplayTable:AddRow()
								local leftCell = statDisplayRow:AddCell()
								local rightCell = statDisplayRow:AddCell()

								local success, error = pcall(function()
									if type(value) == "string" then
										leftCell:AddText(value)
										rightCell:AddText(tostring(stat[value]))
									elseif type(value) == "table" then
										for _, fieldName in TableUtils:OrderedPairs(value) do
											leftCell:AddText(fieldName)
											rightCell:AddText(tostring(stat[fieldName]))
										end
									end
								end)
								if not success then
									Logger:BasicError(error)
								end
							end
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
						for key, value in TableUtils:OrderedPairs(propertiesToCopy or statsToParse, function(key)
							return type((propertiesToCopy or statsToParse)[key]) == "string" and (propertiesToCopy or statsToParse)[key] or key
						end) do
							local statDisplayRow = statDisplayTable:AddRow()
							local leftCell = statDisplayRow:AddCell()
							local rightCell = statDisplayRow:AddCell()

							local success, error = pcall(function()
								if type(value) == "string" then
									leftCell:AddText(value)
									rightCell:AddText(tostring(stat[value]))
								elseif type(value) == "table" then
									for _, fieldName in TableUtils:OrderedPairs(value) do
										leftCell:AddText(fieldName)
										rightCell:AddText(tostring(stat[fieldName]))
									end
								end
							end)
							if not success then
								Logger:BasicError(error)
							end
						end
					end
				end

				buildRecursiveStatTable(characterStat, nil, parent)
			end
		end
	end
end
