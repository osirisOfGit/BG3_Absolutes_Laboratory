Ext.Require("Client/Mutations/ListDesignerBaseClass.lua")

---@class SpellListDesigner : ListDesignerBaseClass
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
	if not self.browserTabs["Spells"] then
		self.browserTabs["Spells"] = self.browserTabParent:AddTabItem("Spells"):AddChildWindow("Spell Browser")
		self.browserTabs["Spells"].NoSavedSettings = true
	end
	Helpers:KillChildren(self.browserTabs["Spells"])

	self:buildProgressionBrowser()

	StatBrowser:Render("SpellData",
		self.browserTabs["Spells"],
		function(parent, results)
			Styler:MiddleAlignedColumnLayout(parent, function(ele)
				parent.Size = { 0, 0 }

				local copyAllButton = ele:AddButton("Copy All")

				copyAllButton.OnClick = function()
					for _, spellName in ipairs(results) do
						---@type SpellData
						local spell = Ext.Stats.Get(spellName)

						local level = (spell.Level ~= "" and spell.Level > 0) and spell.Level or 1
						self.activeList.levels[level] = self.activeList.levels[level] or {}
						local subLevelList = self.activeList.levels[level]

						if not self:CheckIfEntryIsInListLevel(subLevelList, spellName, level) then
							subLevelList.manuallySelectedEntries = subLevelList.manuallySelectedEntries or
								TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)

							local leveledSubList = subLevelList.manuallySelectedEntries
							leveledSubList.randomized = leveledSubList.randomized or {}

							table.insert(leveledSubList.randomized, spellName)
						end
					end

					self:buildDesigner()
				end
			end)
		end,
		function(pos)
			return pos % (math.floor(self.browserTabs["Spells"].LastSize[1] / (58 * Styler:ScaleFactor()))) ~= 0
		end,
		function(spellName)
			for l = 1, 30 do
				if self.activeList.levels and self.activeList.levels[l] and self:CheckIfEntryIsInListLevel(self.activeList.levels[l], spellName, l) then
					return true
				end
			end
		end,
		function(spellImage, spellName)
			spellImage.CanDrag = true
			spellImage.DragDropType = "EntryReorder"
			spellImage.UserData = {
				entryName = spellName
			} --[[@as EntryHandle]]

			---@param preview ExtuiTreeParent
			spellImage.OnDragStart = function(_, preview)
				if self.selectedEntries.context ~= "Browser" then
					self.selectedEntries.context = "Browser"
					self.selectedEntries.entries = {}
					for _, handle in pairs(self.selectedEntries.handles) do
						if handle.UserData.subListName then
							handle:SetColor("Button", self.subListIndex[handle.UserData.subListName].colour)
						else
							handle:SetColor("Button", { 1, 1, 1, 0 })
						end
						handle:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
					end
					self.selectedEntries.handles = {}
				else
					local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
						return value.entryName == spellImage.UserData.spellName
					end)
					if not index then
						table.insert(self.selectedEntries.entries, spellImage.UserData)
						table.insert(self.selectedEntries.handles, spellImage)
					end
				end

				if #self.selectedEntries.entries > 0 then
					preview:AddText("Moving:")
					for _, entryHandle in pairs(self.selectedEntries.entries) do
						preview:AddText(entryHandle.entryName)
					end
				else
					preview:AddText("Moving " .. spellName)
				end
			end
		end,
		function(spellImage, spellName)
			if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
				if self.selectedEntries.context ~= "Browser" then
					self.selectedEntries.context = "Browser"
					self.selectedEntries.entries = {}
					for _, handle in pairs(self.selectedEntries.handles) do
						if handle.UserData.subListName then
							handle:SetColor("Button", self.subListIndex[handle.UserData.subListName].colour)
						else
							handle:SetColor("Button", { 1, 1, 1, 0 })
						end
					end
					self.selectedEntries.handles = {}
				else
					local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
						return value.entryName == spellName
					end)
					if not index then
						table.insert(self.selectedEntries.entries, spellImage.UserData)
						table.insert(self.selectedEntries.handles, spellImage)
						spellImage:SetColor("Button", { 0, 1, 0, .8 })
						spellImage:SetColor("ButtonHovered", { 0, 1, 0, .8 })
					else
						table.remove(self.selectedEntries.entries, index)
						table.remove(self.selectedEntries.handles, index)

						spellImage:SetColor("Button", { 1, 1, 1, 0 })
						spellImage:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
					end
				end
			end
		end)
end
