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

		for _, spellName in pairs(progSpellList.Spells) do
			addToListFunc(spellName)
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

function SpellListDesigner:customizeDesigner()
	self.designerSection:AddText("Primary Abilities ( ? )"):Tooltip():AddText([[
	Any Abilities Mutators that run will check the entity for assigned Spell Lists - if it finds them, it will decide which Abilities get the highest scores (in addition to +2 and +1 base additions)
based on this list, if specified - if multiple Spell Lists are assigned, it will average out the priorities based on how many levels of each list were assigned]])
	local abilityGroup = self.designerSection:AddGroup("AbilityGroup")
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
			input.WidthFitPreview = true
			input.SameLine = true
			input.Options, input.SelectedIndex  = buildAbilityOptions(abilityCategory)

			input.OnChange = function ()
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

	self.designerSection:AddNewLine()
end
