Ext.Require("Client/Mutations/ListDesignerBaseClass.lua")

---@class SpellListDesigner : ListDesignerBaseClass
SpellListDesigner = ListDesignerBaseClass:new("Spell List",
	"spellLists",
	{ "SelectSpells", "AddSpells" },
	---@param spellMeta ResourceProgressionSpell|ResourceProgressionAddedSpell
	function(spellMeta, addToListFunc)
		---@type ResourceSpellList
		local progSpellList = Ext.StaticData.Get(spellMeta.SpellUUID, "SpellList")

		for _, spellName in pairs(progSpellList.Spells) do
			addToListFunc(spellName)
		end
	end)

-- ---@param spellList CustomList
-- function SpellListDesigner:buildSpellBrowser(spellList)
-- 	Helpers:KillChildren(self.spellBrowser)

-- 	SpellBrowser:Render(self.spellBrowser,
-- 		function(parent, results)
-- 			Styler:MiddleAlignedColumnLayout(parent, function(ele)
-- 				parent.Size = { 0, 0 }

-- 				local copyAllButton = ele:AddButton("Copy All")

-- 				copyAllButton.OnClick = function()
-- 					for _, spellName in ipairs(results) do
-- 						---@type SpellData
-- 						local spell = Ext.Stats.Get(spellName)

-- 						local level = (spell.Level ~= "" and spell.Level > 0) and spell.Level or 1
-- 						spellList.levels[level] = spellList.levels[level] or {}
-- 						local subLevelList = spellList.levels[level]

-- 						if not self:CheckIfSpellIsInSpellListLevel(subLevelList, spellName, level) then
-- 							subLevelList.manuallySelectedEntries = subLevelList.manuallySelectedEntries or
-- 								TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)

-- 							local leveledSubList = subLevelList.manuallySelectedEntries
-- 							leveledSubList.randomized = leveledSubList.randomized or {}

-- 							table.insert(leveledSubList.randomized, spellName)
-- 						end
-- 					end

-- 					self:buildSpellListDesigner(spellList)
-- 				end
-- 			end)
-- 		end,
-- 		function(pos)
-- 			return pos % (math.floor(self.spellBrowser.LastSize[1] / 58 * Styler:ScaleFactor())) ~= 0
-- 		end,
-- 		function(spellName)
-- 			for l = 1, 30 do
-- 				if spellList.levels and spellList.levels[l] and self:CheckIfSpellIsInSpellListLevel(spellList.levels[l], spellName, l) then
-- 					return true
-- 				end
-- 			end
-- 		end,
-- 		function(spellImage, spellName)
-- 			spellImage.CanDrag = true
-- 			spellImage.DragDropType = "SpellReorder"
-- 			spellImage.UserData = {
-- 				entryName = spellName
-- 			} --[[@as EntryHandle]]

-- 			---@param preview ExtuiTreeParent
-- 			spellImage.OnDragStart = function(_, preview)
-- 				if self.selectedSpells.context == "Browser" and #self.selectedSpells.spells > 0 then
-- 					preview:AddText("Moving:")
-- 					for _, spellName in pairs(self.selectedSpells.spells) do
-- 						preview:AddText(spellName.entryName)
-- 					end
-- 				else
-- 					preview:AddText("Moving " .. spellName)
-- 				end
-- 			end
-- 		end,
-- 		function(spellImage, spellName)
-- 			if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
-- 				if self.selectedSpells.context ~= "Browser" then
-- 					self.selectedSpells.context = "Browser"
-- 					self.selectedSpells.spells = {}
-- 					for _, handle in pairs(self.selectedSpells.handles) do
-- 						if handle.UserData.subListName then
-- 							handle:SetColor("Button", self.subListIndex[handle.UserData.subListName].colour)
-- 						else
-- 							handle:SetColor("Button", { 1, 1, 1, 0 })
-- 						end
-- 					end
-- 					self.selectedSpells.handles = {}
-- 				end
-- 				table.insert(self.selectedSpells.spells, spellImage.UserData)
-- 				table.insert(self.selectedSpells.handles, spellImage)
-- 				spellImage:SetColor("Button", { 0, 1, 0, .8 })
-- 			elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Alt" then
-- 				if self.selectedSpells.context == "Browser" then
-- 					local index = TableUtils:IndexOf(self.selectedSpells.spells, spellName)
-- 					if index then
-- 						table.remove(self.selectedSpells.spells, index)
-- 						table.remove(self.selectedSpells.handles, index)

-- 						spellImage:SetColor("Button", { 1, 1, 1, 0 })
-- 					end
-- 				end
-- 			end
-- 		end)
-- end
