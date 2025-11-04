Ext.Require("Shared/Mutations/ListConfigurationManager.lua")

---@class ListDesignerBaseClass
ListDesignerBaseClass = {
	name = "List Designer",
	---@type string
	configKey = nil,

	settings = ConfigurationStructure.config.mutations.settings.customLists,

	---@type ExtuiWindow
	mainWindow = nil,
	---@type ExtuiTable
	layoutTable = nil,
	---@type ExtuiChildWindow
	listSection = nil,
	---@type ExtuiChildWindow
	designerSection = nil,
	---@type ExtuiTabBar
	browserTabParent = nil,
	---@type {[string]: ExtuiChildWindow}
	browserTabs = {},
	---@type ExtuiPopup	
	popup = nil,

	---@type ExtuiSelectable?
	activeListHandle = nil,
	---@type CustomList?
	activeList = nil,

	---@type EntryReplacerDictionary
	replaceMap = {},

	--- For Multiselect Drag/Drop tracking
	selectedEntries = {
		---@type EntryHandle[]
		entries = {},
		---@type ExtuiImageButton[]
		handles = {},
		---@type "Main"|"Browser"
		context = "Main",
		linkedEntries = false
	},

	-- Copied amongst inheritors so they can remove the entries they don't want
	---@class ListSubListIndex
	subListIndex = {
		["guaranteed"] = { name = "Guaranteed", description = "Will always be assigned to an enemy that is the assigned level or higher", colour = {} },
		["randomized"] = { name = "Randomized", description = "Will be placed into a pool of spells assigned to the same level to be randomly chosen per the mutator's config", colour = {} },
		["startOfCombatOnly"] = { name = "Cast On Combat Start", description = "Will only be cast on combat start - will not be added to the entity's spellList", colour = {} },
		["onDeathOnly"] = { name = "Cast On Death", description = "Will only be cast when the entity dies, targeting itself - will not be added to the entity's spellList.", colour = {} },
		["onLoadOnly"] = { name = "Cast On Level Load", description = "Will be cast as soon as the mutator is applied - will not be added to the entity's spellList", colour = {} },
		["blackListed"] = { name = "Blacklisted", description = "Only available for spells added via a linked progression - will prevent this spell from being added to the entity's spellList or cast by the entity", colour = {} }
	}
}

---@param name string
---@param configKey string
---@param subListTypesToExclude ("guaranteed"|"randomized"|"startOfCombatOnly"|"onLoadOnly"|"blackListed"|"onDeathOnly")[]?
---@return ListDesignerBaseClass
function ListDesignerBaseClass:new(name, configKey, subListTypesToExclude)
	ListConfigurationManager:maintainLists()
	local instance = {}

	setmetatable(instance, self)
	self.__index = self
	instance.name = name
	instance.configKey = configKey
	instance.browserTabs = {}
	instance.entryCacheForProgressions = {}
	instance.selectedEntries = {
		entries = {},
		handles = {},
		context = "Main",
		linkedEntries = false
	}
	instance.subListIndex = TableUtils:DeeplyCopyTable(ListDesignerBaseClass.subListIndex)
	instance.settings = ConfigurationStructure.config.mutations.settings.customLists

	if subListTypesToExclude then
		for _, subListType in pairs(subListTypesToExclude) do
			instance.subListIndex[subListType] = nil
		end
	end

	return instance
end

function ListDesignerBaseClass:clearSelectedEntries()
	for i in ipairs(self.selectedEntries.entries) do
		pcall(function(...)
			if self.selectedEntries.entries[i].subListName then
				self.selectedEntries.handles[i]:SetColor("Button", self.subListIndex[self.selectedEntries.entries[i].subListName].colour)
			end
			self.selectedEntries.handles[i]:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
		end)

		self.selectedEntries.entries[i] = nil
		self.selectedEntries.handles[i] = nil
	end
end

---@param activeListId Guid?
function ListDesignerBaseClass:launch(activeListId)
	if not self.mainWindow then
		self.mainWindow = Ext.IMGUI.NewWindow(self.name)
		self.mainWindow.Font = MCM.Get("font_size", "755a8a72-407f-4f0d-9a33-274ac0f0b53d")
		self.mainWindow.Closeable = true
		self.mainWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())
		self.mainWindow.Scaling = "Scaled"

		self.layoutTable = self.mainWindow:AddTable(self.name, 3)
		self.layoutTable.Resizable = true
		self.layoutTable.NoSavedSettings = true
		self.layoutTable:AddColumn("ListSection", "WidthFixed")
		self.layoutTable:AddColumn("", "WidthStretch")
		self.layoutTable:AddColumn("BrowserSection", "WidthFixed")
		self.layoutTable.ColumnDefs[1].NoResize = true
		self.layoutTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
		self.layoutTable.ColumnDefs[3].Width = 400 * Styler:ScaleFactor()


		local row = self.layoutTable:AddRow()

		self.listSection = row:AddCell():AddChildWindow("List")
		self.designerSection = row:AddCell():AddChildWindow("Designer")
		self.browserTabParent = row:AddCell():AddTabBar("Browsers")

		local collapseExpandUserFoldersButton = self.designerSection:AddButton("<<")
		collapseExpandUserFoldersButton.UserData = "keep"
		collapseExpandUserFoldersButton.OnClick = function()
			Helpers:CollapseExpand(
				collapseExpandUserFoldersButton.Label == "<<",
				self.layoutTable.ColumnDefs[1].Width,
				function(width)
					if width then
						self.layoutTable.ColumnDefs[1].Width = width
					end
					return self.layoutTable.ColumnDefs[1].Width
				end,
				self.listSection,
				function()
					if collapseExpandUserFoldersButton.Label == "<<" then
						collapseExpandUserFoldersButton.Label = ">>"
					else
						collapseExpandUserFoldersButton.Label = "<<"
					end
				end)
		end
		self.mainWindow.OnClose = function()
			self.layoutTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
			collapseExpandUserFoldersButton.Label = "<<"
			self.listSection.Visible = true
			for _, tab in pairs(self.browserTabs) do
				Helpers:KillChildren(tab)
			end
		end

		if self.configKey == "spellLists" or self.configKey == "passiveLists" then
			self.browserTabs["Progressions"] = self.browserTabParent:AddTabItem("Progressions"):AddChildWindow("Progression Browser")
			self.browserTabs["Progressions"].NoSavedSettings = true
		end

		self.popup = Styler:Popup(self.mainWindow)

		local docsButton = MazzleDocs:addDocButton(self.designerSection)
		docsButton.SameLine = true
		docsButton.UserData = "keep"

		local colorSettings = self.designerSection:AddGroup("colorSetting")
		colorSettings.UserData = "keep"
		colorSettings:AddText("Click A Color To Change It, Hover for Tooltips: "):SetStyle("Alpha", 0.6)

		for subListName, colour in TableUtils:OrderedPairs(self.settings.subListColours, function(key)
				return self.subListIndex[key].name == self.subListIndex["blackListed"].name and "zlisted" or self.subListIndex[key].name
			end,
			function(key, value)
				return self.subListIndex[key] ~= nil
			end)
		do
			self.subListIndex[subListName].colour = Styler:ConvertRGBAToIMGUI(colour._real)
			local colorEditer = colorSettings:AddColorEdit(
				self.subListIndex[subListName].name,
				{ 1, 1, 1 }
			)
			colorEditer.SameLine = true
			colorEditer.AlphaBar = true
			colorEditer.Color = self.subListIndex[subListName].colour
			colorEditer.NoInputs = true
			colorEditer:Tooltip():AddText("\t " .. self.subListIndex[subListName].description)
			colorEditer.OnChange = function(colorEdit)
				---@cast colorEdit ExtuiColorEdit
				for i, color in ipairs(colorEdit.Color) do
					colour[i] = color
				end
				self.subListIndex[subListName].colour = colorEdit.Color

				self:buildDesigner()
			end
		end
	else
		Helpers:KillChildren(self.listSection, self.designerSection)
		self.activeListHandle = nil

		self.mainWindow.Open = true
		self.mainWindow:SetFocus()
	end

	self:buildLists(activeListId)
end

---@param activeListId Guid?
function ListDesignerBaseClass:buildLists(activeListId)
	---@type {[Guid]: CustomList}
	local listConfig = ConfigurationStructure.config.mutations.lists[self.configKey]

	local headerTitle = self.listSection:AddSeparatorText("Your Lists ( ? )")
	headerTitle:Tooltip():AddText("\t Right-click on an entry to manage it")
	headerTitle:SetStyle("SeparatorTextAlign", 0.5)

	for guid, list in TableUtils:OrderedPairs(listConfig, function(key)
		return listConfig[key].name
	end) do
		list.useGameLevel = list.useGameLevel or false
		---@type ExtuiSelectable
		local listSelectable = self.listSection:AddSelectable(list.name)
		listSelectable.IDContext = guid
		if list.description and list.description ~= "" then
			listSelectable:Tooltip():AddText("\t " .. list.description)
		end
		listSelectable.UserData = guid

		listSelectable.OnRightClick = function()
			Helpers:KillChildren(self.popup)
			self.popup:Open()
			self.popup:AddSelectable("Edit", "DontClosePopups").OnClick = function()
				FormBuilder:CreateForm(self.popup, function(formResults)
					list.name = formResults.Name
					list.description = formResults.Description
					list.useGameLevel = false

					self:launch(self.activeListHandle and self.activeListHandle.UserData)
				end, {
					{
						label = "Name",
						type = "Text",
						errorMessageIfEmpty = "Required Field",
						defaultValue = list.name
					},
					{
						label = "Description",
						type = "Multiline",
						defaultValue = list.description
					}
				})
			end

			self.popup:AddSelectable("Delete").OnClick = function()
				list.delete = true
				self:launch(self.activeListHandle and self.activeListHandle.UserData)
			end
		end

		listSelectable.OnClick = function()
			if self.activeListHandle then
				self.activeListHandle.Selected = false
				Helpers:KillChildren(self.designerSection)
			end
			self.designerSection.Visible = true

			if self.settings.autoCollapseFoldersSection then
				self.designerSection.Children[1]:OnClick()
			end

			self.activeListHandle = listSelectable

			self.activeList = list

			self:buildBrowser()

			self:buildDesigner()
		end

		if guid == activeListId then
			listSelectable.Selected = true
			listSelectable:OnClick()
		end
	end

	self.listSection:AddNewLine()

	---@type ExtuiSelectable
	local createListButton = self.listSection:AddSelectable("Create a List")

	createListButton.OnClick = function()
		createListButton.Selected = false

		self.popup:Open()

		FormBuilder:CreateForm(self.popup, function(formResults)
			local list = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customLeveledList)

			list.name = formResults.Name
			list.description = formResults.Description

			listConfig[FormBuilder:generateGUID()] = list
			self:launch(self.activeListHandle and self.activeListHandle.UserData)
		end, {
			{
				label = "Name",
				type = "Text",
				errorMessageIfEmpty = "Required Field"
			},
			{
				label = "Description",
				type = "Multiline"
			}
		})
	end

	self:buildModLists(activeListId)
end

function ListDesignerBaseClass:buildModLists(activeListId)
	if MutationModProxy.ModProxy.lists[self.configKey]() then
		---@type {[Guid]: Guid[]}
		local modLists = {}

		for modId, modCache in pairs(MutationModProxy.ModProxy.lists[self.configKey]) do
			---@cast modCache +LocalModCache

			if modCache.lists[self.configKey] and next(modCache.lists[self.configKey]) then
				modLists[modId] = {}
				for listId in pairs(modCache.lists[self.configKey]) do
					table.insert(modLists[modId], listId)
				end
			end
		end

		if next(modLists) then
			self.listSection:AddSeparatorText("Mod-Added Lists"):SetStyle("SeparatorTextAlign", 0.5)

			for modId, spellLists in TableUtils:OrderedPairs(modLists, function(key)
				return Ext.Mod.GetMod(key).Info.Name
			end) do
				self.listSection:AddSeparatorText(Ext.Mod.GetMod(modId).Info.Name)

				for _, guid in TableUtils:OrderedPairs(spellLists, function(_, value)
					return MutationModProxy.ModProxy.lists[self.configKey][value].name
				end) do
					local list = MutationModProxy.ModProxy.lists[self.configKey][guid]
					list.useGameLevel = list.useGameLevel or false

					---@type ExtuiSelectable
					local spellListSelect = self.listSection:AddSelectable(list.name)
					spellListSelect.IDContext = guid
					spellListSelect.UserData = guid
					if list.description and list.description ~= "" then
						spellListSelect:Tooltip():AddText("\t " .. list.description)
					end

					spellListSelect.OnRightClick = function()
						Helpers:KillChildren(self.popup)
						self.popup:Open()

						self.popup:AddSelectable("Copy To Local Config").OnClick = function()
							---@type CustomList
							local listCopy = TableUtils:DeeplyCopyTable(list)
							listCopy.modId = nil

							if TableUtils:IndexOf(ConfigurationStructure.config.mutations.lists[self.configKey],
									---@param value CustomList
									function(value)
										return value.name == listCopy.name
									end)
							then
								listCopy.name = listCopy.name .. " (Copy)"
							end

							ConfigurationStructure.config.mutations.lists[self.configKey][FormBuilder:generateGUID()] = listCopy
							self:launch(activeListId)
						end
					end

					spellListSelect.OnClick = function()
						if self.activeListHandle then
							self.activeListHandle.Selected = false
						end
						self.designerSection.Visible = true
						self.designerSection.Children[1]:OnClick()

						self.activeListHandle = spellListSelect
						self.activeList = list

						self:buildBrowser()
						self:buildDesigner()
					end

					if guid == activeListId then
						spellListSelect.Selected = true
						spellListSelect:OnClick()
					end
				end
			end
		end
	end
end

---@param parent ExtuiTreeParent
function ListDesignerBaseClass:customizeDesigner(parent) end

---@param createListFunc fun(level: (number|GameLevel)):any?
function ListDesignerBaseClass:iterateLevels(createListFunc)
	if self.activeList.useGameLevel then
		for level in ipairs(EntityRecorder.Levels) do
			local result = createListFunc(level)
			if result then
				return result
			end
		end
	else
		for level = (self.configKey == "spellLists" and 0 or 1), 30 do
			local result = createListFunc(level)
			if result then
				return result
			end
		end
	end
end

local isHidden = {}
function ListDesignerBaseClass:buildDesigner()
	---@type {[string] : string[]}
	self.replaceMap = ConfigurationStructure.config.mutations.lists.entryReplacerDictionary[self.configKey]
	if self.activeList.modId then
		self.replaceMap = MutationConfigurationProxy.lists.entryReplacerDictionary[self.activeList.modId]
	end

	self:clearSelectedEntries()

	self.entryCacheForProgressions = {}
	Helpers:KillChildren(self.designerSection)
	self.designerSection:AddNewLine()
	local headerTitle = Styler:ScaledFont(self.designerSection:AddSeparatorText(self.activeList.name), "Big")
	headerTitle:SetStyle("SeparatorTextAlign", 0.5)
	if self.activeList.description and self.activeList.description ~= "" then
		headerTitle.Label = headerTitle.Label .. "( ? )"
		headerTitle:Tooltip():AddText("\t " .. self.activeList.description).TextWrapPos = 800 * Styler:ScaleFactor()
	end

	if self.activeList.modId then
		Styler:CheapTextAlign(Ext.Mod.GetMod(self.activeList.modId).Info.Name, self.designerSection)
		Styler:CheapTextAlign("Mod-Added List - You can browse, but not edit", self.designerSection, "Large"):SetColor("Text", { 1, 0, 0, 0.45 })
	end

	-- Allowing icons to auto-determine amount per row, but requires the window to have a size set first
	if self.designerSection.LastSize[1] == 0 then
		Ext.Timer.WaitFor(10, function()
			self:buildDesigner()
		end)
		return
	end

	local extraOptions = self.designerSection:AddTable("extraOptions", 3)
	extraOptions.BordersInnerV = true
	extraOptions.BordersOuterH = true
	extraOptions:SetColor("TableBorderStrong", { 0.56, 0.46, 0.26, 0.78 })
	self.designerSection:AddNewLine()

	local extraOptionsRow = extraOptions:AddRow()

	Styler:MiddleAlignedColumnLayout(extraOptionsRow:AddCell(), function(ele)
		Styler:DualToggleButton(ele, "Icon", "Text", false, function(swap)
			if swap then
				self.settings.iconOrText = self.settings.iconOrText == "Icon" and "Text" or "Icon"
				self:buildDesigner()
			end

			return self.settings.iconOrText == "Icon"
		end)

		if self.settings.iconOrText == "Icon" and self:renderEntriesBySubcategories({}, ele) then
			ele:AddSeparator()
			Styler:EnableToggleButton(ele, "Show SubCategories Under Levels", false, nil, function(swap)
				if swap then
					self.settings.showSeperatorsInMain = not self.settings.showSeperatorsInMain
					self:buildDesigner()
				end
				return self.settings.showSeperatorsInMain
			end)
		end

		ele:AddSeparator()
		Styler:EnableToggleButton(ele, "Auto-Collapse Folder View", false, nil, function(swap)
			if swap then
				self.settings.autoCollapseFoldersSection = not self.settings.autoCollapseFoldersSection
			end
			return self.settings.autoCollapseFoldersSection
		end)
	end)

	local extraOptionsCell = extraOptionsRow:AddCell()

	Styler:MiddleAlignedColumnLayout(extraOptionsCell, function(ele)
		self:customizeDesigner(ele)
	end)

	local sep = extraOptionsCell:AddSeparatorText(("Linked %s (?)"):format(self.name))
	sep:SetStyle("SeparatorTextAlign", 0.5)
	sep:Tooltip():AddText([[
	Any lists linked to this one will be applied whenever this list is, allowing you to create a 'Base' list that all specializations can be linked to,
eliminating the need for duplication between lists.
This logic will be run recursively, applying the lists linked to the linked lists (with protections against applying the same list multiple times).]])

	local linkedTable = extraOptionsCell:AddTable("LinkedLists", 1)
	linkedTable.BordersOuter = true
	linkedTable.NoSavedSettings = true

	local linkedCell = linkedTable:AddRow():AddCell()
	self.activeList.linkedLists = self.activeList.linkedLists or {}
	local function buildTable()
		Helpers:KillChildren(linkedCell)
		TableUtils:ReindexNumericTable(self.activeList.linkedLists)

		for s, listId in ipairs(self.activeList.linkedLists) do
			local spellList = MutationConfigurationProxy.lists[self.configKey][listId]
			if spellList then
				local delete = Styler:ImageButton(linkedCell:AddImageButton("delete" .. spellList.name, "ico_red_x", { 16, 16 }))
				delete.Disabled = self.activeList.modId ~= nil
				delete.OnClick = function()
					self.activeList.linkedLists[s].delete = true
					TableUtils:ReindexNumericTable(self.activeList.linkedLists)
					buildTable()
				end

				local link = linkedCell:AddTextLink(spellList.name .. (spellList.modId and string.format(" (from %s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
				link.Font = "Small"
				link.SameLine = true
				link.OnClick = function()
					self:launch(listId)
				end
			elseif not self.activeList.modId then
				self.activeList.linkedLists[s] = nil
			end
		end
		TableUtils:ReindexNumericTable(self.activeList.linkedLists)
	end
	buildTable()

	Styler:MiddleAlignedColumnLayout(extraOptionsCell, function(ele)
		local addDependencyButton = ele:AddButton(("Link A %s"):format(self.name))
		Styler:ScaledFont(addDependencyButton, "Small")
		addDependencyButton.Disabled = self.activeList.modId ~= nil
		addDependencyButton.OnClick = function()
			Helpers:KillChildren(self.popup)
			self.popup:Open()

			Styler:BuildCompleteUserAndModLists(self.popup,
				function(config)
					return config.lists and config.lists[self.configKey] and next(config.lists[self.configKey]) and config.lists[self.configKey]
				end,
				function(key, value)
					return value.name
				end,
				function(key, listItem)
					return self.activeList.useGameLevel == listItem.useGameLevel and self.activeListHandle.IDContext ~= key
				end,
				function(select, id, item)
					select.Label = item.name
					select.Selected = TableUtils:IndexOf(self.activeList.linkedLists, id) ~= nil
					select.OnClick = function()
						local index = TableUtils:IndexOf(self.activeList.linkedLists, id)
						if index then
							self.activeList.linkedLists[index] = nil
							select.Selected = false
						else
							select.Selected = true
							table.insert(self.activeList.linkedLists, id)
						end
						buildTable()
					end
				end)
		end
	end)

	Styler:MiddleAlignedColumnLayout(extraOptionsRow:AddCell(), function(ele)
		if self.configKey ~= "statusLists" then
			if self.activeList.blacklistSameEntriesInHigherProgressionLevels == nil then
				self.activeList.blacklistSameEntriesInHigherProgressionLevels = true
			end

			Styler:EnableToggleButton(ele, "Dedupe Spells Within A Progression", false,
				"If a progression offers the same spell at multiple levels, only the lowest level will be considered to have the spell (both in this UI and during mutator application). The Progression Browser will show all spells regardless of this setting.",
				function(swap)
					if swap then
						self.activeList.blacklistSameEntriesInHigherProgressionLevels = not self.activeList.blacklistSameEntriesInHigherProgressionLevels
						self:buildDesigner()
					end
					return self.activeList.blacklistSameEntriesInHigherProgressionLevels
				end)
			ele:AddSeparator()
		end

		ele:AddText("(?) Distribute By: "):Tooltip():AddText([[
	Changing this option will clear your list as the two options are not compatible with each other.
Using game level will distribute all entries in the same level that the entity is in and all the ones that come before (i.e. TUT, WLD, CRE, SCL if they're in SCL).
You can't link progressions when using Game Level, as progressions are distributed by character level.
Using entity level will use the entity's character level, post Character Level Mutators if applicable.]])
		Styler:DualToggleButton(ele, "Entity Level", "Game Level", true, function(swap)
			if swap then
				self.activeList.useGameLevel = not self.activeList.useGameLevel
				if self.activeList.levels then
					self.activeList.levels.delete = true
				end
				self.activeList.levels = {}
				if self.activeList.useGameLevel then
					for level in ipairs(EntityRecorder.Levels) do
						self.activeList.levels[level] = {
							manuallySelectedEntries = {}
						}
					end
				end

				if self.activeList.linkedProgressionTableIds then
					self.activeList.linkedProgressionTableIds.delete = true
					self.activeList.linkedProgressionTableIds = {}
				end

				self:buildDesigner()
			end
			return not self.activeList.useGameLevel
		end)

		ele:AddSeparator()
		ele:AddText("Default Pool is: ")
		local defaultCombo = ele:AddCombo("")
		defaultCombo.SameLine = true
		defaultCombo.WidthFitPreview = true

		local opts = {}
		local index
		for group in TableUtils:OrderedPairs(self.subListIndex) do
			if group ~= "blackListed" then
				table.insert(opts, self.subListIndex[group].name)
				if group == (self.activeList.defaultPool or self.settings.defaultPool[self.configKey]) then
					index = #opts
				end
			end
		end
		defaultCombo.Options = opts
		defaultCombo.SelectedIndex = index - 1
		defaultCombo.OnChange = function()
			local previous = self.activeList.defaultPool or self.settings.defaultPool[self.configKey]
			local chosen = TableUtils:IndexOf(self.subListIndex, function(value)
				return value.name == defaultCombo.Options[defaultCombo.SelectedIndex + 1]
			end)

			if chosen ~= previous then
				self.settings.defaultPool[self.configKey] = chosen
				Helpers:KillChildren(self.popup)
				self.popup:Open()

				Styler:CheapTextAlign(("Change all entries of the previous type to the new type in all %ss?"):format(self.name), self.popup)
				Styler:MiddleAlignedColumnLayout(self.popup, function(ele)
					local yesButton = ele:AddButton("Do it")
					yesButton.OnClick = function()
						if yesButton.Label ~= "Do it" then
							self.mainWindow:SetFocus()
							self.popup:SetCollapsed(true, "Always")
							for _, lists in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.lists[self.configKey]) do
								---@cast lists CustomList
								if lists.levels then
									for level, levelSubList in TableUtils:OrderedPairs(lists.levels) do
										if levelSubList.manuallySelectedEntries and levelSubList.manuallySelectedEntries[previous] then
											levelSubList.manuallySelectedEntries[chosen] = levelSubList.manuallySelectedEntries[chosen] or {}
											for _, entry in TableUtils:OrderedPairs(levelSubList.manuallySelectedEntries[previous]) do
												---@cast entry string[]
												table.insert(levelSubList.manuallySelectedEntries[chosen], entry)
											end
											levelSubList.manuallySelectedEntries[previous].delete = true
										end

										if levelSubList.linkedProgressions then
											for progressionTableId, list in TableUtils:OrderedPairs(levelSubList.linkedProgressions) do
												if list[previous] then
													list[previous].delete = true
												end
												if list[chosen] then
													list[chosen].delete = true
												end
												if not list() then
													list.delete = true
													if not levelSubList.linkedProgressions() then
														levelSubList.linkedProgressions.delete = true
													end
												end
											end
										end
									end
								end
							end
							self:buildDesigner()
						else
							yesButton.Label = "Are You Sure?"
							yesButton.AutoClosePopups = true
							Styler:Color(yesButton, "ErrorText")
						end
					end
				end)
			end
		end

		ele:AddSeparator()

		local deleteAllButton = ele:AddButton("Delete All Non-Linked Entries")
		deleteAllButton:SetColor("Button", { 1, 0, 0, 0.5 })
		deleteAllButton.Disabled = self.activeList.modId ~= nil
		local timer
		deleteAllButton.OnClick = function()
			if deleteAllButton.Label ~= "Delete All Non-Linked Entries" then
				Ext.Timer.Cancel(timer)
				timer = nil
				for _, leveledSubList in TableUtils:OrderedPairs(self.activeList.levels) do
					if leveledSubList.manuallySelectedEntries then
						leveledSubList.manuallySelectedEntries.delete = true
					end
				end

				self:buildDesigner()
			else
				deleteAllButton.Label = "Are You Sure?"
				timer = Ext.Timer.WaitFor(5000, function()
					deleteAllButton.Label = "Delete All Non-Linked Entries"
					timer = nil
				end)
			end
		end
	end).Disabled = self.activeList.modId ~= nil

	local leveledListGroup = self.designerSection:AddGroup("leveledLists")

	if self.activeList.levels and self.activeList.levels[31] then
		self.activeList.levels[0] = TableUtils:DeeplyCopyTable(self.activeList.levels[31]._real or self.activeList.levels[31])
		self.activeList.levels[31].delete = true
		self.activeList.levels[31] = nil
	end
	self:iterateLevels(function(level)
		local listGroup = leveledListGroup:AddGroup("list" .. level)

		listGroup:SetColor("Border", { 1, 0, 0, 1 })
		local listNumberGroup = listGroup:AddGroup("number")
		listNumberGroup:AddText(tostring(self.activeList.useGameLevel and EntityRecorder.Levels[level] or level) .. (level < 10 and "  " or "")).Font = "Big"
		local hideButton = Styler:ImageButton(listNumberGroup:AddImageButton("hideLevel" .. level, "Action_Hide", Styler:ScaleFactor({ 28, 28 })))
		local showButton = Styler:ImageButton(listNumberGroup:AddImageButton("showLevel" .. level, "ico_concentration", Styler:ScaleFactor({ 28, 28 })))
		listGroup.UserData = level
		if not self.activeList.modId then
			listGroup.DragDropType = "EntryReorder"
		end

		local entryGroup = listGroup:AddGroup("entries" .. level)
		entryGroup.SameLine = true
		entryGroup.Visible = isHidden[entryGroup.Label] ~= "false"
		hideButton.Visible = entryGroup.Visible
		showButton.Visible = not entryGroup.Visible
		hideButton.OnClick = function()
			if entryGroup.Visible then
				isHidden[entryGroup.Label] = true
				hideButton.Visible = false
				showButton.Visible = true
			else
				isHidden[entryGroup.Label] = nil
				hideButton.Visible = true
				showButton.Visible = false
			end
			entryGroup.Visible = not entryGroup.Visible
		end
		showButton.OnClick = hideButton.OnClick

		self.activeList.levels = self.activeList.levels or {}
		self.activeList.levels[level] = self.activeList.levels[level] or {}

		if self.activeList.levels[level].manuallySelectedEntries then
			self:buildEntryListFromSubList(entryGroup, self.activeList.levels[level].manuallySelectedEntries, level)
		end

		if self.activeList.linkedProgressionTableIds and next(self.activeList.linkedProgressionTableIds._real or self.activeList.linkedProgressionTableIds) then
			local sep = Styler:ScaledFont(entryGroup:AddSeparatorText("Linked Progressions"), "Big")
			local progGroup = entryGroup:AddGroup("linkedProg")

			local deleteProgGroup = true

			for _, progressionTableId in pairs(self.activeList.linkedProgressionTableIds) do
				if ListConfigurationManager.progressionIndex[progressionTableId] then
					if TableUtils:IndexOf(ListConfigurationManager.progressionIndex[progressionTableId].progressionLevels, function(value)
							return value.level == level
						end)
					then
						local progList = {
						}
						if self.activeList.levels
							and self.activeList.levels[level]
							and self.activeList.levels[level].linkedProgressions
							and self.activeList.levels[level].linkedProgressions[progressionTableId]
						then
							progList = self.activeList.levels[level].linkedProgressions[progressionTableId]
						end

						local delete = self:buildEntryListFromSubList(progGroup, progList, level, progressionTableId)
						if deleteProgGroup then
							deleteProgGroup = delete
						end
					end
				end
			end
			if deleteProgGroup then
				sep:Destroy()
				progGroup:Destroy()
			end
		end

		---@class EntryHandle
		---@field entryName EntryName
		---@field subListName string?
		---@field level (number|GameLevel)?
		---@field progressionTableId Guid?

		---@param group ExtuiGroup
		---@param entryElement ExtuiImage|ExtuiImageButton
		listGroup.OnDragDrop = function(group, entryElement)
			---@type EntryHandle[]
			local entryHandles = {}
			if #self.selectedEntries.entries > 0 then
				entryHandles = self.selectedEntries.entries

				local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
					return value.entryName == entryElement.UserData.spellName
				end)
				if not index then
					table.insert(entryHandles, entryElement.UserData)
				end

				if self.selectedEntries.context ~= "Main" then
					for _, handle in pairs(self.selectedEntries.handles) do
						handle:SetColor("Button", { 1, 1, 1, 0 })
						handle:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
						handle.Tint = { 1, 1, 1, 0.2 }
					end
				end

				self.selectedEntries.handles = {}
				self.selectedEntries.entries = {}
			else
				entryHandles = { entryElement.UserData }
			end

			self.activeList.levels = self.activeList.levels or {}
			self.activeList.levels[group.UserData] = self.activeList.levels[group.UserData] or {}
			self.activeList.levels[group.UserData].manuallySelectedEntries = self.activeList.levels[group.UserData].manuallySelectedEntries or {}

			local defaultPool = self.activeList.defaultPool or self.settings.defaultPool[self.configKey]

			for _, spellHandle in pairs(entryHandles) do
				if not self:CheckIfEntryIsInListLevel(self.activeList.levels[group.UserData], spellHandle.entryName, group.UserData) then
					self.activeList.levels[group.UserData].manuallySelectedEntries[spellHandle.subListName or defaultPool] =
						self.activeList.levels[group.UserData].manuallySelectedEntries[spellHandle.subListName or defaultPool] or {}

					table.insert(self.activeList.levels[group.UserData].manuallySelectedEntries[spellHandle.subListName or defaultPool], spellHandle.entryName)

					if spellHandle.subListName then
						local index = TableUtils:IndexOf(self.activeList.levels[spellHandle.level].manuallySelectedEntries[spellHandle.subListName], spellHandle.entryName)
						self.activeList.levels[spellHandle.level].manuallySelectedEntries[spellHandle.subListName][index] = nil
					end
				end
			end

			self:buildDesigner()
		end

		if #entryGroup.Children == 0 then
			entryGroup:AddDummy(self.designerSection.LastSize[1], 56)
		end

		listGroup:AddNewLine()
	end)
end

---@param parentGroup ExtuiGroup
---@param subLists CustomSubList
---@param level number|GameLevel
---@param progressionTableId string?
function ListDesignerBaseClass:buildEntryListFromSubList(parentGroup, subLists, level, progressionTableId)
	local entryListGroup = parentGroup:AddGroup(progressionTableId or tostring(level))
	local subListsClone = TableUtils:DeeplyCopyTable(subLists._real or subLists)
	if progressionTableId then
		if ListConfigurationManager.progressionIndex[progressionTableId] then
			Styler:ScaledFont(entryListGroup:AddSeparatorText(ListConfigurationManager.progressionIndex[progressionTableId].name), "Big"):SetStyle("SeparatorTextAlign", 0.05)
			subListsClone[self.activeList.defaultPool or self.settings.defaultPool[self.configKey]] = subListsClone
				[self.activeList.defaultPool or self.settings.defaultPool[self.configKey]] or {}
		else
			return
		end
	end

	local useIcons = self.settings.iconOrText == "Icon"
	local displayTable = entryListGroup:AddTable("display", useIcons and 1 or 3)

	local row = displayTable:AddRow()
	if useIcons then
		row:AddCell()
	end

	local count = 0

	local function buildProgressionSubList(subListName, subList)
		if subListName == (self.activeList.defaultPool or self.settings.defaultPool[self.configKey]) and progressionTableId then
			local blacklistLowerLevelEntries = self.activeList.blacklistSameEntriesInHigherProgressionLevels
			for _, progressionEntry in pairs(ListConfigurationManager.progressionIndex[progressionTableId].progressionLevels) do
				if progressionEntry.level == level and progressionEntry[self.configKey] then
					for _, nodeEntries in pairs(progressionEntry[self.configKey]) do
						---@cast nodeEntries string[]
						for _, entryName in pairs(nodeEntries) do
							if not TableUtils:IndexOf(subListsClone, function(value)
									return TableUtils:IndexOf(value, entryName) ~= nil
								end)
								and (not blacklistLowerLevelEntries or not ListConfigurationManager:hasSameEntryInLowerLevel(progressionTableId, progressionEntry.level, entryName, self.configKey))
							then
								if (self.name == SpellListDesigner.name and (Ext.Stats.GetCachedSpell(entryName).AiFlags & Ext.Enums.AIFlags.CanNotUse) == Ext.Enums.AIFlags.CanNotUse) then
									subListsClone.blackListed = subListsClone.blackListed or {}
									subLists.blackListed = subLists.blackListed or {}

									table.insert(subLists.blackListed, entryName)
									table.insert(subListsClone.blackListed, entryName)
								else
									table.insert(subList, entryName)
								end
							end
						end
					end
				end
			end
		end
	end

	local groupFunc
	local listForGroupFunc = {}
	if useIcons and self.settings.showSeperatorsInMain then
		buildProgressionSubList(self.activeList.defaultPool or self.settings.defaultPool[self.configKey], listForGroupFunc)
		for subListName, subList in pairs(subListsClone) do
			buildProgressionSubList(subListName, listForGroupFunc)
			for _, entry in pairs(subList) do
				table.insert(listForGroupFunc, entry)
			end
		end
		local success, childParent = pcall(function() return row.Children[1].Children[1] end)
		local parentContainer = success and childParent or row.Children[1]
		groupFunc = self:renderEntriesBySubcategories(listForGroupFunc, parentContainer)
	end

	for subListName, subList in TableUtils:OrderedPairs(subListsClone, function(key)
		return self.subListIndex[key].name == self.subListIndex["blackListed"].name and "zlisted" or self.subListIndex[key].name
	end) do
		-- if not self.subListIndex[subListName] then
		-- 	local default = self.settings.defaultPool[self.configKey]
		-- 	subLists[default] = subLists[default] or {}
		-- 	for _, entry in pairs(subLists[subListName]) do
		-- 		table.insert(subLists[default], entry)
		-- 	end
		-- 	subLists[subListName].delete = true
		-- 	Helpers:KillChildren(parentGroup)
		-- 	self:buildEntryListFromSubList(parentGroup, subLists, level, progressionTableId)
		-- 	return
		-- end
		buildProgressionSubList(subListName, subList)

		---@cast subList EntryName[]

		for _, entryName in TableUtils:OrderedPairs(subList) do
			---@type SpellData|PassiveData|StatusData
			local entryData = Ext.Stats.Get(entryName)
			if entryData then
				count = count + 1
				---@type ExtuiTreeParent
				local parent = useIcons and row.Children[1] or row:AddCell()
				if groupFunc then
					parent = groupFunc(entryData)
				end
				local totalChildren = #parent.Children + 1

				local entryImageButton = parent:AddImageButton(entryName .. "##" .. level, entryData.Icon ~= "" and entryData.Icon or "Item_Unknown",
					Styler:ScaleFactor({ 48, 48 }))

				if self.replaceMap[entryName] and next(self.replaceMap[entryName]._real or self.replaceMap[entryName]) then
					local replacesText = parent:AddText("R")
					replacesText.Font = "Tiny"
					replacesText.SameLine = true
				end
				if entryImageButton.Image.Icon == "" then
					entryImageButton:Destroy()
					entryImageButton = parent:AddImageButton(entryName .. "##" .. level, "Item_Unknown", Styler:ScaleFactor({ 48, 48 }))
				end

				if useIcons then
					entryImageButton.SameLine = totalChildren > 1
						and ((totalChildren) % math.floor((self.designerSection.LastSize[1]) / (64 * Styler:ScaleFactor())) ~= 0)
				else
					local link = Styler:HyperlinkText(parent, entryName, function(parent)
						ResourceManager:RenderDisplayWindow(entryData, parent)
					end)
					link.SameLine = true
					link:SetColor("TextLink", { 0.86, 0.79, 0.68, 0.78 })
				end

				entryImageButton:SetColor("Button", self.subListIndex[subListName].colour)
				entryImageButton.UserData = {
					entryName = entryName,
					subListName = subListName,
					level = level,
					progressionTableId = progressionTableId
				} --[[@as EntryHandle]]

				if not self.activeList.modId and not progressionTableId then
					entryImageButton.CanDrag = true
					entryImageButton.DragDropType = "EntryReorder"

					---@param preview ExtuiTreeParent
					entryImageButton.OnDragStart = function(_, preview)
						if self.selectedEntries.context == "Main" and #self.selectedEntries.entries > 0 then
							preview:AddText("Moving:")
							for _, spellName in pairs(self.selectedEntries.entries) do
								preview:AddText(spellName.entryName)
							end
						else
							preview:AddText("Moving " .. entryName)
						end
					end
				end

				local altTooltip = entryName
				altTooltip = altTooltip .. "\n\t" .. self.subListIndex[subListName].name
				if progressionTableId then
					altTooltip = altTooltip .. "\n\tLinked from Progression " .. ListConfigurationManager.progressionIndex[progressionTableId].name
				end
				if self.replaceMap[entryName] then
					altTooltip = altTooltip .. "\n\t Replaces:"
					for _, toReplace in TableUtils:OrderedPairs(self.replaceMap[entryName]) do
						altTooltip = altTooltip .. "\n\t\t" .. toReplace
					end
				end

				local aiCantUse = false
				if self.name == SpellListDesigner.name and (Ext.Stats.GetCachedSpell(entryName).AiFlags & Ext.Enums.AIFlags.CanNotUse) == Ext.Enums.AIFlags.CanNotUse then
					entryImageButton.Tint = { 1, 0, 0, 0.4 }
					altTooltip = altTooltip .. "\n !!!! SPELL CAN'T BE USED BY AI !!!!"
					aiCantUse = true
				end

				local showedTooltip = Styler:HyperlinkRenderable(entryImageButton, entryName, "Alt", true, altTooltip, function(parent)
					ResourceManager:RenderDisplayWindow(entryData, parent)
				end)
				if not progressionTableId or not aiCantUse then
					entryImageButton.OnClick = function()
						if not showedTooltip() then
							local function onCtrl()
								if self.selectedEntries.context ~= "Main"
									or (self.selectedEntries.linkedSpells and not progressionTableId)
									or (not self.selectedEntries.linkedSpells and progressionTableId)
								then
									self.selectedEntries.context = "Main"
									self.selectedEntries.entries = {}
									for _, handle in pairs(self.selectedEntries.handles) do
										if handle.UserData.subListName then
											handle:SetColor("Button", self.subListIndex[handle.UserData.subListName].colour)
										else
											handle:SetColor("Button", { 1, 1, 1, 0 })
										end
									end
									self.selectedEntries.handles = {}
								end

								if progressionTableId then
									self.selectedEntries.linkedSpells = true
								else
									self.selectedEntries.linkedSpells = false
								end

								local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
									return value.entryName == entryName
								end)
								if not index then
									table.insert(self.selectedEntries.entries, entryImageButton.UserData)
									table.insert(self.selectedEntries.handles, entryImageButton)
									entryImageButton:SetColor("Button", { 0, 1, 0, .8 })
									entryImageButton:SetColor("ButtonHovered", { 0, 1, 0, .8 })
								else
									table.remove(self.selectedEntries.entries, index)
									table.remove(self.selectedEntries.handles, index)

									entryImageButton:SetColor("Button", { 1, 1, 1, 0 })
									entryImageButton:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
								end
							end

							if not self.activeList.modId then
								if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
									onCtrl()
								elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
									if #self.selectedEntries.entries >= 1 and self.selectedEntries.context == "Main" then
										local lastEntry = self.selectedEntries.handles[#self.selectedEntries.handles]
										local lastEntryParent = lastEntry.ParentElement
										---@type ExtuiTreeParent
										local buttonParent = entryImageButton.ParentElement
										if not useIcons or self.settings.showSeperatorsInMain then
											buttonParent = buttonParent.ParentElement
											lastEntryParent = lastEntryParent.ParentElement
										end
										if lastEntryParent.Handle == buttonParent.Handle then
											local startSelecting = false
											local deselect = false
											---@param func fun(child: ExtuiStyledRenderable): boolean?
											local function iterateFunc(func)
												for _, child in ipairs(buttonParent.Children) do
													---@cast child ExtuiTreeParent
													if not useIcons or self.settings.showSeperatorsInMain then
														if pcall(function()
																return child.Children
															end)
														then
															for _, actualChild in ipairs(child.Children) do
																if type(actualChild.UserData) == "table" then
																	if func(actualChild) then
																		return
																	end
																end
															end
														end
													else
														if type(child.UserData) == "table" then
															if func(child) then
																return
															end
														end
													end
												end
											end
											iterateFunc(function(child)
												if self.name ~= SpellListDesigner.name or (Ext.Stats.GetCachedSpell(child.UserData.entryName).AiFlags & Ext.Enums.AIFlags.CanNotUse) ~= Ext.Enums.AIFlags.CanNotUse then
													if startSelecting or deselect then
														local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
															return value.entryName == child.UserData.entryName
														end)
														if not index then
															table.insert(self.selectedEntries.entries, child.UserData)
															table.insert(self.selectedEntries.handles, child)
															child:SetColor("Button", { 0, 1, 0, .8 })
															child:SetColor("ButtonHovered", { 0, 1, 0, .8 })
														elseif deselect then
															if self.selectedEntries.entries[index].subListName then
																child:SetColor("Button", self.subListIndex[self.selectedEntries.entries[index].subListName].colour)
															end
															child:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })

															self.selectedEntries.entries[index] = nil
															self.selectedEntries.handles[index] = nil
															TableUtils:ReindexNumericTable(self.selectedEntries.entries)
															TableUtils:ReindexNumericTable(self.selectedEntries.handles)
														end
														if child.Handle == lastEntry.Handle or child.Handle == entryImageButton.Handle then
															return true
														end
													elseif child.Handle == lastEntry.Handle then
														startSelecting = true
													elseif child.Handle == entryImageButton.Handle then
														local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
															return value.entryName == child.UserData.entryName
														end)
														if index then
															if self.selectedEntries.entries[index].subListName then
																child:SetColor("Button", self.subListIndex[self.selectedEntries.entries[index].subListName].colour)
															end
															child:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })

															self.selectedEntries.entries[index] = nil
															self.selectedEntries.handles[index] = nil
															TableUtils:ReindexNumericTable(self.selectedEntries.entries)
															TableUtils:ReindexNumericTable(self.selectedEntries.handles)
															deselect = true
														else
															startSelecting = true
															table.insert(self.selectedEntries.entries, child.UserData)
															table.insert(self.selectedEntries.handles, child)
															child:SetColor("Button", { 0, 1, 0, .8 })
															child:SetColor("ButtonHovered", { 0, 1, 0, .8 })
														end
													end
												end
											end)
										end
									else
										onCtrl()
									end
								elseif not aiCantUse then
									Helpers:KillChildren(self.popup)
									self.popup:Open()
									for subListCategory, index in TableUtils:OrderedPairs(self.subListIndex) do
										if subListCategory ~= subListName and (subListCategory ~= "blackListed" or progressionTableId) then
											self.popup:AddSelectable("Set As " .. index.name .. "##" .. level).OnClick = function()
												---@type EntryHandle[]
												local handles = {}
												if self.selectedEntries.context == "Main" and #self.selectedEntries.entries > 0 then
													handles = self.selectedEntries.entries
												end

												if not TableUtils:IndexOf(handles, function(value)
														return value.entryName == entryName
													end)
												then
													table.insert(handles, entryImageButton.UserData)
												end

												for _, handle in pairs(handles) do
													---@type LeveledSubList
													local subList = self.activeList.levels[handle.level]

													if handle.progressionTableId then
														subList.linkedProgressions = subList.linkedProgressions or {}
														subList.linkedProgressions[handle.progressionTableId] = subList.linkedProgressions[handle.progressionTableId] or {}
														subList = subList.linkedProgressions[handle.progressionTableId]
													else
														subList = subList.manuallySelectedEntries
													end

													if subListCategory ~= (self.activeList.defaultPool or self.settings.defaultPool[self.configKey]) or not progressionTableId then
														subList[subListCategory] = subList[subListCategory] or {}
														table.insert(subList[subListCategory], handle.entryName)
													elseif subList[subListCategory] then
														subList[subListCategory].delete = true
													end
													if handle.subListName then
														local index = TableUtils:IndexOf(subList[handle.subListName], handle.entryName)
														if index then
															subList[handle.subListName][index] = nil
															if subList[handle.subListName] and not next(subList[handle.subListName]._real or subList[handle.subListName]) then
																subList[handle.subListName].delete = true
															end

															if subList[handle.subListName] then
																TableUtils:ReindexNumericTable(subList[handle.subListName])
															end
														end
													end
												end
												self.selectedEntries.handles = {}
												self.selectedEntries.entries = {}
												self:buildDesigner()
											end
										end
									end

									---@type ExtuiMenu
									local replaceMenu = self.popup:AddMenu("Replaces:")
									Helpers:KillChildren(replaceMenu)
									replaceMenu:AddText([[Any entries listed below will be removed from the Entity if this entry is applied.
These fields are universal, applying to every list of the same type (i.e. Passive Lists).
If the List is from a mod, only that mod's map will be referenced, both here and during Profile Execution
Entries that replaces other entries are marked in the Main List view with a tiny 'R']])

									local displayGroup = replaceMenu:AddGroup("")
									local function buildEntryTable()
										Helpers:KillChildren(displayGroup)
										local displayRow = displayGroup:AddTable("entryDisplay", 2):AddRow()

										if self.replaceMap[entryName] and self.replaceMap[entryName]() then
											displayGroup:AddSeparatorText("Entries that will be removed:"):SetStyle("SeparatorTextAlign", 0.5)
											for i, entryBeingReplaced in ipairs(self.replaceMap[entryName]) do
												---@type StatusData|SpellData|PassiveData
												local stat = Ext.Stats.Get(entryBeingReplaced)
												if stat then
													local parent = displayRow:AddCell()
													if not self.activeList.modId then
														Styler:ImageButton(parent:AddImageButton("delete", "ico_red_x", Styler:ScaleFactor({ 20, 20 }))).OnClick = function()
															self.replaceMap[entryName][i] = nil
															self:buildDesigner()
															TableUtils:ReindexNumericTable(self.replaceMap[entryName])
															buildEntryTable()
														end
													end
													parent:AddImage(stat.Icon ~= "" and stat.Icon or "Item_Unknown", Styler:ScaleFactor({ 32, 32 })).SameLine = true
													Styler:HyperlinkText(parent, entryBeingReplaced, function(parent)
														ResourceManager:RenderDisplayWindow(stat, parent)
													end).SameLine = true
												elseif not self.activeList.modId then
													self.replaceMap[entryName][i] = nil
													TableUtils:ReindexNumericTable(self.replaceMap[entryName])
													Logger:BasicWarning("Removed %s from %s's Replacement map under the %s entries due to it not existing", entryBeingReplaced,
														entryName,
														self.configKey)
													buildEntryTable()
												end
											end
										end
									end
									buildEntryTable()

									if not self.activeList.modId then
										local statTypes = {
											[PassiveListDesigner.configKey] = "PassiveData",
											[SpellListDesigner.configKey] = "SpellData",
											[StatusListDesigner.configKey] = "StatusData"
										}
										StatBrowser:Render(statTypes[self.configKey],
											replaceMenu,
											nil,
											function(pos)
												return pos % 7 ~= 0
											end,
											function(entryId)
												return TableUtils:IndexOf(self.replaceMap[entryName], entryId) ~= nil
											end,
											nil,
											function(_, entryId)
												local index = TableUtils:IndexOf(self.replaceMap[entryName], entryId)
												if not index then
													self.replaceMap[entryName] = self.replaceMap[entryName] or {}

													table.insert(self.replaceMap[entryName], entryId)
												else
													self.replaceMap[entryName][index] = nil
													TableUtils:ReindexNumericTable(self.replaceMap[entryName])
													if not self.replaceMap[entryName]() then
														self.replaceMap[entryName].delete = true
													end
												end
												Ext.OnNextTick(function(e)
													buildEntryTable()
												end)
												self:buildDesigner()
											end
										)
									end


									if not progressionTableId then
										self.popup:AddSelectable("Remove").OnClick = function()
											---@type EntryHandle[]
											local handles = {}
											if self.selectedEntries.context == "Main" and #self.selectedEntries.entries > 0 then
												handles = self.selectedEntries.entries
											end

											if not TableUtils:IndexOf(handles, function(value)
													return value.entryName == entryName
												end)
											then
												table.insert(handles, entryImageButton.UserData)
											end

											for _, handle in pairs(handles) do
												---@type CustomSubList
												local subList = self.activeList.levels[handle.level].manuallySelectedEntries

												local index = TableUtils:IndexOf(subList[handle.subListName], handle.entryName)
												if index then
													subList[handle.subListName][index] = nil
													if not subList[handle.subListName]() then
														subList[handle.subListName].delete = true
													end
												end
											end
											self.selectedEntries.handles = {}
											self.selectedEntries.entries = {}
											self:buildDesigner()
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	if not row.Children[1] or #row.Children[1].Children == 0 then
		entryListGroup:Destroy()
		return true
	end
	if not useIcons then
		if row.Children[2] and #row.Children[2].Children == 0 then
			displayTable.Columns = 1
		elseif row.Children[3] and #row.Children[3].Children == 0 then
			displayTable.Columns = 2
		end
	end
end

function ListDesignerBaseClass:buildBrowser()
end

---@param entries string[]
---@param parent ExtuiTreeParent
---@return fun(entry: SpellData|PassiveData|StatusData): ExtuiTreeParent
function ListDesignerBaseClass:renderEntriesBySubcategories(entries, parent)
end

function ListDesignerBaseClass:buildStatBrowser(statType)
	Helpers:KillChildren(self.browserTabs[statType])

	self:clearSelectedEntries()

	StatBrowser:Render(statType,
		self.browserTabs[statType],
		function(parent, results)
			Styler:MiddleAlignedColumnLayout(parent, function(ele)
				parent.Size = { 0, 0 }

				local copyAllButton = ele:AddButton("Copy All")

				copyAllButton.OnClick = function()
					for _, statName in ipairs(results) do
						---@type SpellData|PassiveData|StatusData
						local stat = Ext.Stats.Get(statName)

						local level = self.activeList.useGameLevel and 1 or
							((stat.ModifierList == "SpellData" and stat.Level ~= "" and stat.Level > 0) and stat.Level or 1)

						self.activeList.levels = self.activeList.levels or {}
						self.activeList.levels[level] = self.activeList.levels[level] or {}
						local subLevelList = self.activeList.levels[level]

						if not self:CheckIfEntryIsInListLevel(subLevelList, statName, level)
							and (stat.ModifierList ~= "SpellData"
								or (Ext.Stats.GetCachedSpell(statName).AiFlags & Ext.Enums.AIFlags.CanNotUse) ~= Ext.Enums.AIFlags.CanNotUse)
						then
							subLevelList.manuallySelectedEntries = subLevelList.manuallySelectedEntries or
								TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)

							local defaultPool = self.activeList.defaultPool or self.settings.defaultPool[self.configKey]
							local leveledSubList = subLevelList.manuallySelectedEntries
							leveledSubList[defaultPool] = leveledSubList[defaultPool] or {}

							table.insert(leveledSubList[defaultPool], statName)
						end
					end

					self:buildDesigner()
				end
			end)
		end,
		function(pos)
			return pos % (math.floor(self.browserTabs[statType].LastSize[1] / (58 * Styler:ScaleFactor()))) ~= 0
		end,
		function(statName)
			return self:iterateLevels(function(level)
				if self.activeList.levels and self.activeList.levels[level] and self:CheckIfEntryIsInListLevel(self.activeList.levels[level], statName, level) then
					return true
				end
			end)
		end,
		function(statImage, statName)
			statImage.CanDrag = true
			statImage.DragDropType = "EntryReorder"
			statImage.UserData = {
				entryName = statName
			} --[[@as EntryHandle]]

			---@param preview ExtuiTreeParent
			statImage.OnDragStart = function(_, preview)
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
						return value.entryName == statImage.UserData.spellName
					end)
					if not index then
						table.insert(self.selectedEntries.entries, statImage.UserData)
						table.insert(self.selectedEntries.handles, statImage)
					end
				end

				if #self.selectedEntries.entries > 0 then
					preview:AddText("Moving:")
					for _, entryHandle in pairs(self.selectedEntries.entries) do
						preview:AddText(entryHandle.entryName)
					end
				else
					preview:AddText("Moving " .. statName)
				end
			end
		end,
		function(statImage, statName)
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
						return value.entryName == statName
					end)
					if not index then
						table.insert(self.selectedEntries.entries, statImage.UserData)
						table.insert(self.selectedEntries.handles, statImage)
						statImage:SetColor("Button", { 0, 1, 0, .8 })
						statImage:SetColor("ButtonHovered", { 0, 1, 0, .8 })
					else
						table.remove(self.selectedEntries.entries, index)
						table.remove(self.selectedEntries.handles, index)

						statImage:SetColor("Button", { 1, 1, 1, 0 })
						statImage:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
					end
				end
			elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
				if #self.selectedEntries.entries >= 1 then
					if self.selectedEntries.context == "Browser" then
						local lastEntry = self.selectedEntries.handles[#self.selectedEntries.handles]
						---@type ExtuiTreeParent
						local buttonParent = statImage.ParentElement

						if lastEntry.ParentElement.Handle == buttonParent.Handle then
							local startSelecting = false
							local deselect = false
							for _, child in ipairs(buttonParent.Children) do
								if child.UserData then
									if self.name ~= SpellListDesigner.name or (Ext.Stats.GetCachedSpell(child.UserData.entryName).AiFlags & Ext.Enums.AIFlags.CanNotUse) ~= Ext.Enums.AIFlags.CanNotUse then
										if startSelecting or deselect then
											local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
												return value.entryName == child.UserData.entryName
											end)
											if not index then
												table.insert(self.selectedEntries.entries, child.UserData)
												table.insert(self.selectedEntries.handles, child)
												child:SetColor("Button", { 0, 1, 0, .8 })
												child:SetColor("ButtonHovered", { 0, 1, 0, .8 })
											elseif deselect then
												child:SetColor("Button", { 1, 1, 1, 0 })
												child:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })

												self.selectedEntries.entries[index] = nil
												self.selectedEntries.handles[index] = nil
												TableUtils:ReindexNumericTable(self.selectedEntries.entries)
												TableUtils:ReindexNumericTable(self.selectedEntries.handles)
											end
											if child.Handle == lastEntry.Handle or child.Handle == statImage.Handle then
												break
											end
										elseif child.Handle == lastEntry.Handle then
											startSelecting = true
										elseif child.Handle == statImage.Handle then
											local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
												return value.entryName == child.UserData.entryName
											end)
											if index then
												child:SetColor("Button", { 1, 1, 1, 0 })
												child:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })

												self.selectedEntries.entries[index] = nil
												self.selectedEntries.handles[index] = nil
												TableUtils:ReindexNumericTable(self.selectedEntries.entries)
												TableUtils:ReindexNumericTable(self.selectedEntries.handles)
												deselect = true
											else
												startSelecting = true
												table.insert(self.selectedEntries.entries, child.UserData)
												table.insert(self.selectedEntries.handles, child)
												child:SetColor("Button", { 0, 1, 0, .8 })
												child:SetColor("ButtonHovered", { 0, 1, 0, .8 })
											end
										end
									end
								end
							end
						end
					else
						local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
							return value.entryName == statName
						end)
						if not index then
							table.insert(self.selectedEntries.entries, statImage.UserData)
							table.insert(self.selectedEntries.handles, statImage)
							statImage:SetColor("Button", { 0, 1, 0, .8 })
							statImage:SetColor("ButtonHovered", { 0, 1, 0, .8 })
						else
							table.remove(self.selectedEntries.entries, index)
							table.remove(self.selectedEntries.handles, index)

							statImage:SetColor("Button", { 1, 1, 1, 0 })
							statImage:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
						end
					end
				end
			end
		end)
end

function ListDesignerBaseClass:buildFullProgressionBrowser()
	if self.browserTabs["Progressions"] then
		Helpers:KillChildren(self.browserTabs["Progressions"])

		self:clearSelectedEntries()

		local searchBox = self.browserTabs["Progressions"]:AddInputText("")
		searchBox.Hint = "Search Progressions"

		local resultsGroup = self.browserTabs["Progressions"]:AddGroup("Results")

		local levelView = self.browserTabs["Progressions"]:AddGroup("Levels")

		local timer
		searchBox.OnChange = function()
			if timer then
				Ext.Timer.Cancel(timer)
			end
			timer = Ext.Timer.WaitFor(200, function()
				Helpers:KillChildren(resultsGroup)
				resultsGroup.Visible = true

				local searchValue = string.upper(searchBox.Text)
			end)
		end
	end
end

function ListDesignerBaseClass:buildLiteProgressionBrowser()
	if self.browserTabs["Progressions"] then
		Helpers:KillChildren(self.browserTabs["Progressions"])

		self:clearSelectedEntries()

		local searchBox = self.browserTabs["Progressions"]:AddInputText("")
		searchBox.Hint = "Search Progressions"

		local resultsGroup = self.browserTabs["Progressions"]:AddGroup("Results")

		if not next(ListConfigurationManager.progressionTables) then
			ListConfigurationManager:buildProgressionIndex()
		end

		local levelView = self.browserTabs["Progressions"]:AddGroup("Levels")
		local timer
		searchBox.OnChange = function()
			if timer then
				Ext.Timer.Cancel(timer)
			end
			timer = Ext.Timer.WaitFor(200, function()
				Helpers:KillChildren(resultsGroup)
				resultsGroup.Visible = true

				local searchValue = string.upper(searchBox.Text)

				for _, progressionTableUuid in TableUtils:OrderedPairs(ListConfigurationManager.progressionTables, function(key, value)
					return ListConfigurationManager.progressionIndex[value].name
				end, function(key, value)
					return TableUtils:IndexOf(ListConfigurationManager.progressionIndex[value].progressionLevels, function(value)
						return value[self.configKey] ~= nil
					end) ~= nil
				end) do
					local progressionTable = ListConfigurationManager.progressionIndex[progressionTableUuid]
					local progressionName = progressionTable.name
					if progressionName:upper():find(searchValue) then
						---@type ExtuiSelectable
						local select = resultsGroup:AddSelectable(progressionName)

						if TableUtils:IndexOf(self.activeList.linkedProgressionTableIds, progressionTableUuid) then
							select.Selected = true
						end

						select.OnClick = function()
							resultsGroup.Visible = false
							Helpers:KillChildren(levelView)

							local header = levelView:AddSeparatorText(progressionName)
							Styler:ScaledFont(header, "Large")
							header:SetStyle("SeparatorTextAlign", 0.5)

							Styler:MiddleAlignedColumnLayout(levelView, function(ele)
								local defaultPool = self.activeList.defaultPool or self.settings.defaultPool[self.configKey]
								local copyAllButton = ele:AddButton("Copy All")

								copyAllButton.OnClick = function()
									for _, progressionEntry in TableUtils:OrderedPairs(progressionTable.progressionLevels, function(key)
										return tonumber(key)
									end) do
										local level = progressionEntry.level
										if self.activeList.useGameLevel then
											level = 1
										end
										self.activeList.levels = self.activeList.levels or {}
										self.activeList.levels[level] = self.activeList.levels[level] or {}
										local subLevelList = self.activeList.levels[level]
										subLevelList.manuallySelectedEntries = subLevelList.manuallySelectedEntries or
											TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)

										local leveledSubList = subLevelList.manuallySelectedEntries
										leveledSubList[defaultPool] = leveledSubList[defaultPool] or {}

										if progressionEntry[self.configKey] then
											for _, entryList in pairs(progressionEntry[self.configKey]) do
												for _, entry in pairs(entryList) do
													if not self:CheckIfEntryIsInListLevel(subLevelList, entry, level)
														and (self.name ~= SpellListDesigner.name
															or (Ext.Stats.GetCachedSpell(entry).AiFlags & Ext.Enums.AIFlags.CanNotUse) ~= Ext.Enums.AIFlags.CanNotUse)
														and not ListConfigurationManager:hasSameEntryInLowerLevel(progressionTableUuid, level, entry, self.configKey)
													then
														table.insert(leveledSubList[defaultPool], entry)
													end
												end
											end
										end
									end

									select:OnClick()
									self:buildDesigner()
								end

								if not self.activeList.useGameLevel then
									local progressionIndex = TableUtils:IndexOf(self.activeList.linkedProgressionTableIds, progressionTableUuid)

									local linkButton = ele:AddButton(progressionIndex and "Unlink" or "Link (?)")
									linkButton:Tooltip():AddText(
										"\t (Un)Forms a link to this progression, dynamically pulling all entries from the ProgressionTable when needed. See SpellList wiki page.")

									linkButton.SameLine = true
									linkButton.OnClick = function()
										if progressionIndex then
											for _, subList in TableUtils:OrderedPairs(self.activeList.levels) do
												if subList.linkedProgressions and subList.linkedProgressions[progressionTableUuid] then
													subList.linkedProgressions[progressionTableUuid].delete = true
												end
											end
											self.activeList.linkedProgressionTableIds[progressionIndex] = nil
											linkButton.Label = "Link (?)"
											progressionIndex = nil
										else
											table.insert(self.activeList.linkedProgressionTableIds, progressionTableUuid)
											linkButton.Label = "Unlink"
											progressionIndex = #self.activeList.linkedProgressionTableIds._real
										end
										self:buildDesigner()
										select:OnClick()
									end
								end
							end)

							local progTable = Styler:TwoColumnTable(levelView, progressionTableUuid)
							progTable.Resizable = false
							progTable.NoSavedSettings = true

							for _, progressionEntry in TableUtils:OrderedPairs(progressionTable.progressionLevels, function(key, value)
								return value.level
							end, function(key, value)
								return value[self.configKey] ~= nil
							end) do
								local level = progressionEntry.level

								local row = progTable:AddRow()

								local levelName = tostring(level)
								if TableUtils:IndexOf(progressionTable.progressionLevels, function(value)
										return value.level == level and value.id ~= progressionEntry.id
									end)
								then
									levelName = levelName .. (" (%s)"):format(progressionEntry.id:sub(#progressionEntry.id - 5))
								end

								row:AddCell():AddText(levelName)

								local spellCell = row:AddCell()
								for nodeName, entryList in TableUtils:OrderedPairs(progressionEntry[self.configKey]) do
									---@cast nodeName string
									---@cast entryList string[]

									spellCell:AddSeparatorText(nodeName)
									local groupFunc = self:renderEntriesBySubcategories(entryList, spellCell)
									for i, entryName in ipairs(entryList) do
										---@type SpellData|PassiveData|StatusData
										local entryData = Ext.Stats.Get(entryName)

										local buttonParent = spellCell
										if groupFunc then
											buttonParent = groupFunc(entryData)
										end
										local totalChildren = groupFunc and (#buttonParent.Children + 1) or i

										local entryImageButton = buttonParent:AddImageButton(entryName .. totalChildren,
											entryData.Icon ~= "" and entryData.Icon or "Item_Unknown", Styler:ScaleFactor({ 48, 48 }))

										entryImageButton.SameLine = totalChildren > 1 and
											((totalChildren - 1) % (math.floor(self.browserTabs["Progressions"].LastSize[1] / (Styler:ScaleFactor() * 64))) ~= 0)
										entryImageButton.CanDrag = true
										entryImageButton.DragDropType = "EntryReorder"
										entryImageButton.UserData = {
											entryName = entryName
										} --[[@as EntryHandle]]

										if TableUtils:IndexOf(self.activeList.linkedProgressionTableIds, progressionTableUuid) then
											entryImageButton.Tint = { 1, 1, 1, 0.2 }
										else
											for l = 1, 30 do
												if self.activeList.levels and self.activeList.levels[l] and self:CheckIfEntryIsInListLevel(self.activeList.levels[l], entryName, l) then
													entryImageButton.Tint = { 1, 1, 1, 0.2 }
													break
												end
											end
										end

										local altTooltip = entryName
										if ListConfigurationManager:hasSameEntryInLowerLevel(progressionTableUuid, level, entryName, self.configKey) and tonumber(entryImageButton.Tint[4]) == 1.0 then
											entryImageButton.Tint = { 1, 1, 0, 0.4 }
											altTooltip = altTooltip .. "\n Already offered in a previous level"
										end

										if self.name == SpellListDesigner.name and (Ext.Stats.GetCachedSpell(entryName).AiFlags & Ext.Enums.AIFlags.CanNotUse) == Ext.Enums.AIFlags.CanNotUse then
											entryImageButton.Tint = { 1, 0, 0, 0.4 }
											altTooltip = altTooltip .. "\n !!!! SPELL CAN'T BE USED BY AI !!!!"
										end

										local tooltipFunction = Styler:HyperlinkRenderable(entryImageButton, entryName, "Alt", true, altTooltip, function(parent)
											ResourceManager:RenderDisplayWindow(entryData, parent)
										end)
										---@param preview ExtuiTreeParent
										entryImageButton.OnDragStart = function(_, preview)
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
													return value.entryName == entryName
												end)
												if not index then
													table.insert(self.selectedEntries.entries, entryImageButton.UserData)
													table.insert(self.selectedEntries.handles, entryImageButton)
												end
											end

											if #self.selectedEntries.entries > 0 then
												preview:AddText("Moving:")
												for _, spellName in pairs(self.selectedEntries.entries) do
													preview:AddText(spellName.entryName)
												end
											else
												preview:AddText("Moving " .. entryName)
											end
										end

										entryImageButton.OnClick = function()
											if not tooltipFunction() then
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
															return value.entryName == entryName
														end)
														if not index then
															table.insert(self.selectedEntries.entries, entryImageButton.UserData)
															table.insert(self.selectedEntries.handles, entryImageButton)
															entryImageButton:SetColor("Button", { 0, 1, 0, .8 })
															entryImageButton:SetColor("ButtonHovered", { 0, 1, 0, .8 })
														else
															table.remove(self.selectedEntries.entries, index)
															table.remove(self.selectedEntries.handles, index)

															entryImageButton:SetColor("Button", { 1, 1, 1, 0 })
															entryImageButton:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
														end
													end
												elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
													if #self.selectedEntries.entries >= 1 and self.selectedEntries.context == "Browser" then
														local lastEntry = self.selectedEntries.handles[#self.selectedEntries.handles]
														local lastEntryParent = lastEntry.ParentElement
														---@type ExtuiTreeParent
														local buttonParent = buttonParent
														if groupFunc then
															lastEntryParent = lastEntryParent.ParentElement
															buttonParent = buttonParent.ParentElement
														end
														if lastEntryParent.Handle == buttonParent.Handle then
															local startSelecting = false
															local deselect = false

															---@param func fun(child: ExtuiStyledRenderable): boolean?
															local function iterateFunc(func)
																for _, child in ipairs(buttonParent.Children) do
																	---@cast child ExtuiTreeParent
																	if groupFunc then
																		if pcall(function()
																				return child.Children
																			end)
																		then
																			for _, actualChild in ipairs(child.Children) do
																				if type(actualChild.UserData) == "table" then
																					if func(actualChild) then
																						return
																					end
																				end
																			end
																		end
																	else
																		if type(child.UserData) == "table" then
																			if func(child) then
																				return
																			end
																		end
																	end
																end
															end

															iterateFunc(function(child)
																if self.name ~= SpellListDesigner.name or (Ext.Stats.GetCachedSpell(child.UserData.entryName).AiFlags & Ext.Enums.AIFlags.CanNotUse) ~= Ext.Enums.AIFlags.CanNotUse then
																	if startSelecting or deselect then
																		local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
																			return value.entryName == child.UserData.entryName
																		end)
																		if not index then
																			table.insert(self.selectedEntries.entries, child.UserData)
																			table.insert(self.selectedEntries.handles, child)
																			child:SetColor("Button", { 0, 1, 0, .8 })
																			child:SetColor("ButtonHovered", { 0, 1, 0, .8 })
																		elseif deselect then
																			child:SetColor("Button", { 1, 1, 1, 0 })
																			child:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })

																			self.selectedEntries.entries[index] = nil
																			self.selectedEntries.handles[index] = nil
																			TableUtils:ReindexNumericTable(self.selectedEntries.entries)
																			TableUtils:ReindexNumericTable(self.selectedEntries.handles)
																		end
																		if child.Handle == lastEntry.Handle or child.Handle == entryImageButton.Handle then
																			return true
																		end
																	elseif child.Handle == lastEntry.Handle then
																		startSelecting = true
																	elseif child.Handle == entryImageButton.Handle then
																		local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
																			return value.entryName == child.UserData.entryName
																		end)
																		if index then
																			child:SetColor("Button", { 1, 1, 1, 0 })
																			child:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })

																			self.selectedEntries.entries[index] = nil
																			self.selectedEntries.handles[index] = nil
																			TableUtils:ReindexNumericTable(self.selectedEntries.entries)
																			TableUtils:ReindexNumericTable(self.selectedEntries.handles)
																			deselect = true
																		else
																			startSelecting = true
																			table.insert(self.selectedEntries.entries, child.UserData)
																			table.insert(self.selectedEntries.handles, child)
																			child:SetColor("Button", { 0, 1, 0, .8 })
																			child:SetColor("ButtonHovered", { 0, 1, 0, .8 })
																		end
																	end
																end
															end)
														end
													else
														local index = TableUtils:IndexOf(self.selectedEntries.entries, function(value)
															return value.entryName == entryName
														end)
														if not index then
															table.insert(self.selectedEntries.entries, entryImageButton.UserData)
															table.insert(self.selectedEntries.handles, entryImageButton)
															entryImageButton:SetColor("Button", { 0, 1, 0, .8 })
															entryImageButton:SetColor("ButtonHovered", { 0, 1, 0, .8 })
														else
															table.remove(self.selectedEntries.entries, index)
															table.remove(self.selectedEntries.handles, index)

															entryImageButton:SetColor("Button", { 1, 1, 1, 0 })
															entryImageButton:SetColor("ButtonHovered", { 0.64, 0.40, 0.28, 0.5 })
														end
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end)
		end
		searchBox.OnActivate = searchBox.OnChange
	end
end

---@param leveledSubList LeveledSubList
---@param entryName string
---@param level number|GameLevel
---@param ignoreProgressions boolean?
---@return boolean
function ListDesignerBaseClass:CheckIfEntryIsInListLevel(leveledSubList, entryName, level, ignoreProgressions)
	---@param value CustomSubList
	---@return boolean?
	local predicate = function(value)
		for _, subList in pairs(value) do
			if TableUtils:IndexOf(subList, entryName) ~= nil then
				return true
			end
		end
	end

	if leveledSubList.manuallySelectedEntries and TableUtils:IndexOf({ leveledSubList.manuallySelectedEntries }, predicate) then
		return true
	elseif not self.activeList.useGameLevel and leveledSubList.linkedProgressions then
		if TableUtils:IndexOf(leveledSubList.linkedProgressions, predicate) then
			return true
		end

		if not ignoreProgressions then
			for progressionId, subLists in pairs(leveledSubList.linkedProgressions) do
				if TableUtils:IndexOf(ListConfigurationManager.progressionIndex[progressionId].progressionLevels, function(value)
						if value.level == level then
							return TableUtils:IndexOf(value[self.configKey], function(value)
								return TableUtils:IndexOf(value, entryName) ~= nil
							end) ~= nil
						else
							return false
						end
					end) then
					return true
				end
			end
		end
	end

	return false
end

---@return MazzleDocsDocumentation
function ListDesignerBaseClass:generateDocs()
	return {
		{
			Topic = MutatorInterface.Topic,
			SubTopic = MutatorInterface.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Base List Designer",
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Summary"
				},
				{
					type = "Content",
					text =
					[[The List Designer is a component shared by the Spell, Passive, and Status List Mutators - on the Client-side, it serves as a straightforward GUI to construct progression-like distributions of spells/passives/statuses, with some interesting additions; on the Server-Side, it provides some common functionality for all the List Mutators.]]
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "Keybinds",
					prefix_color = "Green",
					centered = true,
					text =
					[[[Left-Click] - If the entry is already present in the list (the middle section), opens a popup showing the different pools you can set it to (or delete it, if it's not linked). Does nothing if the entry is in the right sidebar (browser section)
					
[Ctrl + Left-Click] - Adds or removes (if already selected) the clicked entry to/from a multiselect operation - the entry will be highlighted in green, and every entry highlighted this way will be included when dragging/dropping or changing the assigned pool.

[Shift + Left-Click] - Requires an active multiselect group to exist within the same context - If the clicked entry is not part of the current multiselect, it will add the clicked entry and all entries between it and the last entry added to the multiselect (chronologically speaking).
	If the entry is already in the multiselect, it will do the same, but remove all active entries without adding any. Both operations can be done on the left or right side of the last selected entry.
		
[Alt + Hover] - Opens a tooltip previewing the complete entry for the hovered stat, same way it would be displayed in the Inspector

[Alt + Left Click] - Opens a new window containing the same information for that stat entry as the inspector.]]
				} --[[@as MazzleDocsCallOut]],
				{
					type = "SubHeading",
					text = "The Layout"
				},
				{
					type = "Content",
					text = [[Most of the explanations of this component are left to the tooltips - thus, this section will only cover high-level details to help you get familiar.
There are three sections:

The left sidebar contains all known Lists, both from your config.json and from any mods loaded. This works very similiarly to the mutations section, just with a few less options, like folders and copying other lists (latter is out of laziness and lack of demand :P)

The middle section is the 'Designer' section - this is where you'll inspect, build, and configure your lists to contain your intended distribution of stats. This can be done according to the level of the selected entity, or the Game level they're currently in (see toggle in the options section, right side)

The right section is the 'Browser' section - here is where you can browse and link progressions or just browse for loose stat entries of the same type as the list (spells, passives, statuses). When you open up a List Designer for the first time in a loaded save, you'll notice a brief frozen period - this is due to Lab indexing all available progressions]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Building Your List"
				},
				{
					type = "Content",
					text =
					[[You have two options to build your lists, which can be combined with each other: Loose Stats and Linked Progressions (linked progressions are not applicable for Status Lists or if distributing by Game Level instead of Entity Level).

When you open up a progression in the Browser section, you have two buttons available: Link and Copy All. Copy all will add all entries to your list according to their respective levels in the Progression (or level 1 if distributing by Game Level).

Linking will instead create a sort of Symbolic link to that progression's TableUUID - no entries will actually be added to the config (with the exception of AICanNotUse Spells, which are auto-blacklisted), just the TableUUID.
This allows Lab to dynamically pull in all relevant stats for that progression in the active game state and internally assign them to the default pool (when exporting the list for use in Mods, the default pool will be exported as well, ensuring the intended behavior regardless of the user's settings). This means that you can add or remove mods that affect the relevant progression(s) and Lab will automatically adjust to the new state.

If you move any stats to a pool that isn't the default, they will be added to the config.json, creating a direct dependency on the mod that added that stat, if applicable.

Additionally, due to the above behavior, stats from Linked Progressions can't be moved to different levels - they are distributed the exact same way the progression is. This also plays into multi-select behavior, as you can't select stats in different levels, or loose stats + progression stats.

You can additionally or exclusively add loose stats to your list - just drag and drop entries from the Browser (either tab) into the level you want them in (using keybinds mentioned above to do multiple), and that's it! You can move them between levels freely, and they'll be exported in your config.]]
				},
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function ListDesignerBaseClass:generateChangelog()
	return {
		["1.8.2"] = {
			type = "Bullet",
			text = {
				"Fix error borne from purging data from an array when iterating said array",
			}
		},
		["1.8.1"] = {
			type = "Bullet",
			text = {
				"Fix error when a linked list doesn't exist, purging it from the config",
			}
		},
		["1.7.1"] = {
			type = "Bullet",
			text = {
				"Adds ability to copy mod-sourced Lists to your local config",
				"Fix ModLists not appearing in the Link list popup",
				"Fix linked lists not exporting"
			}
		},
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Refactors all Lists configs and approach to progression linking so it's flexible and robust in all situations (automatically migrates old configs to the new structure)",
				"Fixes all List types not correctly exporting loose Spells/Passives/Statuses when it's a Larian-sourced entry",
				"Safeguard button removal logic in List Designer",
				"Fixes Multi-select when crossing progression lines",
				"Adds a setting to control auto-collapse of the folder sidebar",
				"Adds a 'Default Pool' dropdown",
				"Indexes SelectPassive entries in PassiveList progressions",
				"Adds a new Stat Browser setting to show all spell upcasts in addition to the base spell",
				"Minor visual bug fixes",
			}
		},
		["1.6.0"] = {
			type = "Bullet",
			text = {
				"Fix Icon view",
				"Add Level 0 to Spell Lists for cantrips",
				"Changes the Tooltip Modifier for showing detailed window of the stat (spell/passive/status) to only show when holding Alt (was previously Shift and would pop up on hover without the modifier)",
				"Upgrades selection in lists/browsers - Ctrl click still multiselect, but Shift clicking will either select or deselect (depending on the state of the clicked button) all entries between the last entry selected (chronologically) and the button that was shift-clicked. Can be done for all buttons under a single level",
				"Adds logic to tint spells that have AIFlag = 'CanNotUse', excluding them from CopyAll operations, auto-blacklisting them in Linked Progressions (can't be changed), and excludes them from Shift-clicking multiselect. Can still be manually selected if manually added or still in the browser",
				"Breaks up spell buttons by Cantrip / Class Action / Regular spell in main list (only icon view) and the Progression browser (with an associated setting for the main list)",
				"Adds Separator headers for linked Progressions, showing what progression those entries came from",
				"Adds a new Cast On Death group for Spell Lists (will allow setting a randomized pool for them + castOnCombatStart/castOnLevelLoad in the future)",
				"Adds ability to convert lists to use Game Level instead of Character Level (or vice-versa, swapping this option will clear your list, CAHOOT! (there is a tooltip for this))",
				"Restructures the ui a bit, allows collapsing the folder sidebar (happens automatically on selecting a list)",
				"Adds ability to hide/show each level in a list",
			}
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
