Ext.Require("Client/Mutations/ListDesignerBaseClass.lua")

---@class SpellListDesigner : ListDesignerBaseClass
---@field activeList SpellList
SpellListDesigner = ListDesignerBaseClass:new("Spell List",
	"spellLists",
	nil,
	{ "SelectSpells", "AddSpells" },
	---@param spellMeta ResourceProgressionSpell|ResourceProgressionAddedSpell
	function(spellMeta, addToListFunc)
		---@type ResourceSpellList
		local progSpellList = Ext.StaticData.Get(spellMeta.SpellUUID, "SpellList")

		if progSpellList then
			for _, spellName in pairs(progSpellList.Spells) do
				addToListFunc(spellName)
			end
		else
			error(string.format("SpellUUID %s does not exist as a spell list", spellMeta.SpellUUID))
		end
	end)

function SpellListDesigner:buildBrowser()
	if not self.browserTabs["SpellData"] then
		self.browserTabs["SpellData"] = self.browserTabParent:AddTabItem("Spells"):AddChildWindow("Spell Browser")
		self.browserTabs["SpellData"].NoSavedSettings = true
	end

	self:buildProgressionBrowser()
	self:buildStatBrowser("SpellData")
end

function SpellListDesigner:customizeDesigner(parent)
	parent:AddText("Primary Abilities ( ? )\t\t\t"):Tooltip():AddText([[
	Any Abilities Mutators that run will check the entity for assigned Spell Lists - if it finds them, it will decide which Abilities get the highest scores (in addition to +2 and +1 base additions)
based on this list, if specified - if multiple Spell Lists are assigned, it will average out the priorities based on how many levels of each list were assigned]])
	local abilityGroup = parent:AddGroup("AbilityGroup")
	abilityGroup.Font = "Small"

	local function build()
		Helpers:KillChildren(abilityGroup)

		local function buildAbilityOptions(abilityCategory)
			local opts = {}
			for i = 0, 6 do
				local ability = tostring(Ext.Enums.AbilityId[i])
				local index = TableUtils:IndexOf(self.activeList.abilityPriorities, ability)

				if not index or index == abilityCategory then
					table.insert(opts, ability)
				end
			end

			return opts, (self.activeList.abilityPriorities and TableUtils:IndexOf(opts, self.activeList.abilityPriorities[abilityCategory]) or 0) - 1
		end

		local abilityTable = abilityGroup:AddTable("", 2)
		abilityTable.SizingFixedFit = true

		for _, prop in ipairs({ "Primary", "Secondary", "Tertiary" }) do
			local row = abilityTable:AddRow()
			local abilityCategory = prop:lower() .. "Stat"
			row:AddCell():AddText(prop .. ": ")

			local input = row:AddCell():AddCombo("##" .. prop)
			input.Disabled = self.activeList.modId ~= nil
			input.WidthFitPreview = true
			input.SameLine = true
			input.Options, input.SelectedIndex = buildAbilityOptions(abilityCategory)

			input.OnChange = function()
				local chosenAbility = input.Options[input.SelectedIndex + 1]
				if chosenAbility == "None" then
					if self.activeList.abilityPriorities and self.activeList.abilityPriorities[abilityCategory] then
						self.activeList.abilityPriorities[abilityCategory] = nil
						build()
					end
				else
					self.activeList.abilityPriorities = self.activeList.abilityPriorities or {}
					self.activeList.abilityPriorities[abilityCategory] = chosenAbility
					build()
				end
			end
		end
	end
	build()
end

---@return fun(entry: SpellData): ExtuiTreeParent
function SpellListDesigner:renderEntriesBySubcategories(entries, parent)
	local groups = {}
	for _, entry in pairs(entries) do
		if TableUtils:CountElements(groups) == 3 then
			break
		end
		---@type SpellData
		local spell = Ext.Stats.Get(entry)

		if spell then
			if not TableUtils:IndexOf(spell.SpellFlags, "IsSpell") then
				if not groups["Class Actions"] then
					parent:AddSeparatorText("Class Actions"):SetStyle("SeparatorTextAlign", 0.1)
					groups["Class Actions"] = parent:AddGroup("Class Actions")
				end
			elseif spell.Level == 0 then
				if not groups["Cantrips"] then
					parent:AddSeparatorText("Cantrips"):SetStyle("SeparatorTextAlign", 0.1)
					groups["Cantrips"] = parent:AddGroup("Cantrips")
				end
			elseif not groups["Regular Spells"] then
				parent:AddSeparatorText("Regular Spells"):SetStyle("SeparatorTextAlign", 0.1)
				groups["Regular Spells"] = parent:AddGroup("Regular Spells")
			end
		end
	end

	return function(spell)
		if not TableUtils:IndexOf(spell.SpellFlags, "IsSpell") then
			return groups["Class Actions"]
		elseif spell.Level == 0 then
			return groups["Cantrips"]
		else
			return groups["Regular Spells"]
		end
	end
end
