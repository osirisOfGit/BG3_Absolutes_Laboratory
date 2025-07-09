Ext.Require("Client/Mutations/ListDesignerBaseClass.lua")

---@class PassiveListDesigner : ListDesignerBaseClass
PassiveListDesigner = ListDesignerBaseClass:new("Passive List",
	"passiveLists",
	{ "PassivePrototypesAdded", "PassivePrototypesRemoved", "PassivesAdded", "PassivesRemoved" },
	---@param passiveMeta ResourceProgressionPassive|StatsPassivePrototype
	function(passiveMeta, addToListFunc)
		if type(passiveMeta) == "string" then
			addToListFunc(passiveMeta)
		elseif Ext.Types.GetObjectType(passiveMeta) == "resource::ProgressionPassive" then
			---@type ResourcePassiveList
			local progSpellList = Ext.StaticData.Get(passiveMeta.UUID, "PassiveList")

			for _, spellName in pairs(progSpellList.Passives) do
				addToListFunc(spellName)
			end
		else
			addToListFunc(passiveMeta.Name)
		end
	end)

function PassiveListDesigner:buildBrowser()
	if not SpellListDesigner.browserTabs["Passives"] then
		self.browserTabs["Passives"] = self.browserTabParent:AddTabItem("Passives"):AddChildWindow("Spell Browser")
		self.browserTabs["Passives"].NoSavedSettings = true
	end
	Helpers:KillChildren(self.browserTabs["Passives"])

	self:buildProgressionBrowser()

	StatBrowser:Render("PassiveData",
		self.browserTabs["Passives"],
		function(parent, results)
			Styler:MiddleAlignedColumnLayout(parent, function(ele)
				parent.Size = { 0, 0 }

				local copyAllButton = ele:AddButton("Copy All")

				copyAllButton.OnClick = function()
					for _, passiveName in ipairs(results) do
						---@type SpellData
						local spell = Ext.Stats.Get(passiveName)

						local level = (spell.Level ~= "" and spell.Level > 0) and spell.Level or 1
						self.activeList.levels[level] = self.activeList.levels[level] or {}
						local subLevelList = self.activeList.levels[level]

						if not self:CheckIfEntryIsInListLevel(subLevelList, passiveName, level) then
							subLevelList.manuallySelectedEntries = subLevelList.manuallySelectedEntries or
								TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)

							local leveledSubList = subLevelList.manuallySelectedEntries
							leveledSubList.randomized = leveledSubList.randomized or {}

							table.insert(leveledSubList.randomized, passiveName)
						end
					end

					self:buildDesigner()
				end
			end)
		end,
		function(pos)
			return pos % (math.floor(self.browserTabs["Passives"].LastSize[1] / (58 * Styler:ScaleFactor()))) ~= 0
		end,
		function(passiveName)
			for l = 1, 30 do
				if self.activeList.levels and self.activeList.levels[l] and self:CheckIfEntryIsInListLevel(self.activeList.levels[l], passiveName, l) then
					return true
				end
			end
		end,
		function(passiveImage, passiveName)
			passiveImage.CanDrag = true
			passiveImage.DragDropType = "EntryReorder"
			passiveImage.UserData = {
				entryName = passiveName
			} --[[@as EntryHandle]]

			---@param preview ExtuiTreeParent
			passiveImage.OnDragStart = function(_, preview)
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
						return value.entryName == passiveImage.UserData.spellName
					end)
					if not index then
						table.insert(self.selectedEntries.entries, passiveImage.UserData)
						table.insert(self.selectedEntries.handles, passiveImage)
					end
				end

				if #self.selectedEntries.entries > 0 then
					preview:AddText("Moving:")
					for _, entryHandle in pairs(self.selectedEntries.entries) do
						preview:AddText(entryHandle.entryName)
					end
				else
					preview:AddText("Moving " .. passiveName)
				end
			end
		end,
		function(passiveImage, passiveName)
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
						return value.entryName == passiveName
					end)
					if not index then
						table.insert(self.selectedEntries.entries, passiveImage.UserData)
						table.insert(self.selectedEntries.handles, passiveImage)
						passiveImage:SetColor("Button", { 0, 1, 0, .8 })
						passiveImage:SetColor("ButtonHovered", { 0, 1, 0, .8 })
					else
						table.remove(self.selectedEntries.entries, index)
						table.remove(self.selectedEntries.handles, index)

						passiveImage:SetColor("Button", { 1, 1, 1, 0 })
						passiveImage:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
					end
				end
			end
		end)
end
