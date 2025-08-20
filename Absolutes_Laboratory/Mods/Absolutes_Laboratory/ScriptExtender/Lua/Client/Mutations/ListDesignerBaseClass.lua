---@class ListDesignerBaseClass
ListDesignerBaseClass = {
	name = "List Designer",
	---@type string
	configKey = nil,

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

	---@type string[]?
	progressionLinkedNodes = nil,
	---@type fun(resource: any, addToListFunc: fun(name: string))
	iterateProgressionEntriesFunc = nil,
	-- Intentionally not cloning the below in :new so all lists share the progression index
	hasIndexedRelevantProgressions = false,
	--- ProgressionName:  Level:    ListName  entryNames
	---@type {[string]: {[integer]: {[string]: string[]}}}
	progressions = {},
	---@type {[Guid]: {[number]: Guid}}
	progressionTableToProgression = {},
	progressionTranslations = {},
	-- Used when building the lists in the designer, so we're not adding the same entry from multiple progressions - should be unique per inheriting class
	---@type EntryName[][]
	entryCacheForProgressions = {},

	---@type ExtuiSelectable?
	activeListHandle = nil,
	---@type CustomList?
	activeList = nil,

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
		["onLoadOnly"] = { name = "Cast On Level Load", description = "Will be cast as soon as the mutator is applied - will not be added to the entity's spellList", colour = {} },
		["blackListed"] = { name = "Blacklisted", description = "Only available for spells added via a linked progression - will prevent this spell from being added to the entity's spellList or cast by the entity", colour = {} }
	}
}

---@param name string
---@param configKey string
---@param subListTypesToExclude ("guaranteed"|"randomized"|"startOfCombatOnly"|"onLoadOnly"|"blackListed")[]?
---@param progressionLinkedNodes string[]?
---@param iterateProgressionEntriesFunc fun(resource: any, addToListFunc: fun(name: string))?
---@return ListDesignerBaseClass
function ListDesignerBaseClass:new(name, configKey, subListTypesToExclude, progressionLinkedNodes, iterateProgressionEntriesFunc)
	local instance = {}

	setmetatable(instance, self)
	self.__index = self
	instance.name = name
	instance.iterateProgressionEntriesFunc = iterateProgressionEntriesFunc
	instance.configKey = configKey
	instance.browserTabs = {}
	instance.progressionLinkedNodes = progressionLinkedNodes
	instance.entryCacheForProgressions = {}
	instance.selectedEntries = {
		entries = {},
		handles = {},
		context = "Main",
		linkedEntries = false
	}
	instance.subListIndex = TableUtils:DeeplyCopyTable(ListDesignerBaseClass.subListIndex)

	if subListTypesToExclude then
		for _, subListType in pairs(subListTypesToExclude) do
			instance.subListIndex[subListType] = nil
		end
	end

	return instance
end

---@param activeListId Guid?
function ListDesignerBaseClass:launch(activeListId)
	if not self.mainWindow then
		self.mainWindow = Ext.IMGUI.NewWindow(self.name)
		self.mainWindow.Closeable = true
		self.mainWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())

		self.layoutTable = self.mainWindow:AddTable(self.name, 3)
		self.layoutTable.Resizable = true
		self.layoutTable.NoSavedSettings = true
		self.layoutTable:AddColumn("ListSection", "WidthFixed")
		self.layoutTable:AddColumn("", "WidthStretch")
		self.layoutTable:AddColumn("BrowserSection", "WidthFixed")
		self.layoutTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
		self.layoutTable.ColumnDefs[3].Width = 400 * Styler:ScaleFactor()

		local row = self.layoutTable:AddRow()

		self.listSection = row:AddCell():AddChildWindow("List")
		self.designerSection = row:AddCell():AddChildWindow("Designer")
		self.browserTabParent = row:AddCell():AddTabBar("Browsers")

		if self.progressionLinkedNodes then
			self.browserTabs["Progressions"] = self.browserTabParent:AddTabItem("Progressions"):AddChildWindow("Progression Browser")
			self.browserTabs["Progressions"].NoSavedSettings = true
		end

		self.popup = self.mainWindow:AddPopup(self.name .. "popup")
		self.popup:SetColor("PopupBg", { 0, 0, 0, 1 })
		self.popup:SetColor("Border", { 1, 0, 0, 0.5 })

		local colorSettings = self.designerSection:AddGroup("colorSetting")
		colorSettings.UserData = "keep"
		colorSettings:AddText("Click A Color To Change It, Hover for Tooltips"):SetStyle("Alpha", 0.6)

		for subListName, colour in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.settings.customLists.subListColours, function(key)
				return self.subListIndex[key].name
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
	ConfigurationStructure.config.mutations[self.configKey] = ConfigurationStructure.config.mutations[self.configKey] or {}

	---@type {[Guid]: CustomList}
	local listConfig = ConfigurationStructure.config.mutations[self.configKey]

	local headerTitle = self.listSection:AddSeparatorText("Your Lists ( ? )")
	headerTitle:Tooltip():AddText("\t Right-click on an entry to manage it")
	headerTitle:SetStyle("SeparatorTextAlign", 0.5)

	for guid, list in TableUtils:OrderedPairs(listConfig, function(key)
		return listConfig[key].name
	end) do
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

function ListDesignerBaseClass:buildModLists(activeListID)
	if MutationModProxy.ModProxy[self.configKey]() then
		---@type {[Guid]: Guid[]}
		local modLists = {}

		for modId, modCache in pairs(MutationModProxy.ModProxy[self.configKey]) do
			---@cast modCache LocalModCache

			if modCache[self.configKey] and next(modCache[self.configKey]) then
				modLists[modId] = {}
				for listId in pairs(modCache[self.configKey]) do
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
					return MutationModProxy.ModProxy[self.configKey][value].name
				end) do
					local list = MutationModProxy.ModProxy[self.configKey][guid]

					---@type ExtuiSelectable
					local spellListSelect = self.listSection:AddSelectable(list.name)
					spellListSelect.IDContext = guid
					spellListSelect.UserData = guid
					if list.description and list.description ~= "" then
						spellListSelect:Tooltip():AddText("\t " .. list.description)
					end

					spellListSelect.OnClick = function()
						if self.activeListHandle then
							self.activeListHandle.Selected = false
						end
						self.designerSection.Visible = true

						self.activeListHandle = spellListSelect
						self.activeList = list

						self:buildBrowser()
						self:buildDesigner()
					end

					if guid == activeListID then
						spellListSelect.Selected = true
						spellListSelect:OnClick()
					end
				end
			end
		end
	end
end

function ListDesignerBaseClass:customizeDesigner() end

function ListDesignerBaseClass:buildDesigner()
	if self.progressionLinkedNodes then
		self:buildProgressionIndex()
	end

	self.entryCacheForProgressions = {}
	Helpers:KillChildren(self.designerSection)
	local headerTitle = Styler:CheapTextAlign(self.activeList.name, self.designerSection)
	headerTitle.Font = "Big"
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

	self:customizeDesigner()

	local deleteAllButton = self.designerSection:AddButton("Delete All Non-Linked Entries")
	deleteAllButton.Disabled = self.activeList.modId ~= nil
	deleteAllButton.OnClick = function()
		for _, leveledSubList in TableUtils:OrderedPairs(self.activeList.levels) do
			if leveledSubList.manuallySelectedEntries then
				leveledSubList.manuallySelectedEntries.delete = true
			end
		end
		self:buildDesigner()
	end

	Styler:ToggleButton(self.designerSection, "Icon", "Text", true, function(swap)
		local setting = ConfigurationStructure.config.mutations.settings.customLists
		if swap then
			setting.iconOrText = setting.iconOrText == "Icon" and "Text" or "Icon"
			self:buildDesigner()
		end

		return setting.iconOrText == "Icon"
	end)

	local leveledListGroup = self.designerSection:AddGroup("leveledLists")

	for level = 1, 30 do
		local listGroup = leveledListGroup:AddGroup("list" .. level)
		listGroup:SetColor("Border", { 1, 0, 0, 1 })
		listGroup:AddText(tostring(level) .. (level < 10 and "  " or "")).Font = "Big"
		listGroup.UserData = level
		if not self.activeList.modId then
			listGroup.DragDropType = "EntryReorder"
		end

		local entryGroup = listGroup:AddGroup("entries")
		entryGroup.SameLine = true

		if self.activeList.levels and self.activeList.levels[level] then
			if self.activeList.levels[level].manuallySelectedEntries then
				self:buildEntryListFromSubList(entryGroup, self.activeList.levels[level].manuallySelectedEntries, level)
			end

			if self.activeList.levels[level].linkedProgressions and next(self.activeList.levels[level].linkedProgressions) then
				local sep = entryGroup:AddSeparatorText("Linked Progressions")
				local progGroup = entryGroup:AddGroup("linkedProg")

				for progressionTableId, subLists in TableUtils:OrderedPairs(self.activeList.levels[level].linkedProgressions) do
					self:buildEntryListFromSubList(progGroup, subLists, level, progressionTableId)
				end

				if #progGroup.Children == 0 then
					sep:Destroy()
					progGroup:Destroy()
				end
			end
		end

		---@class EntryHandle
		---@field entryName EntryName
		---@field subListName string?
		---@field level number?
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

			for _, spellHandle in pairs(entryHandles) do
				if not self:CheckIfEntryIsInListLevel(self.activeList.levels[group.UserData], spellHandle.entryName, group.UserData) then
					self.activeList.levels[group.UserData].manuallySelectedEntries[spellHandle.subListName or "randomized"] =
						self.activeList.levels[group.UserData].manuallySelectedEntries[spellHandle.subListName or "randomized"] or {}

					table.insert(self.activeList.levels[group.UserData].manuallySelectedEntries[spellHandle.subListName or "randomized"], spellHandle.entryName)

					if spellHandle.subListName then
						local index = TableUtils:IndexOf(self.activeList.levels[spellHandle.level].manuallySelectedEntries[spellHandle.subListName], spellHandle.entryName)
						self.activeList.levels[spellHandle.level].manuallySelectedEntries[spellHandle.subListName][index] = nil
					end
				end
			end

			self:buildDesigner()
		end

		if #entryGroup.Children == 0 then
			entryGroup:AddDummy(56, 56)
		end

		listGroup:AddNewLine()
	end
end

---@param parentGroup ExtuiGroup
---@param subLists CustomSubList
---@param level number
---@param progressionTableId string?
function ListDesignerBaseClass:buildEntryListFromSubList(parentGroup, subLists, level, progressionTableId)
	if progressionTableId and not subLists.randomized then
		subLists.randomized = {}
	end

	local useIcons = ConfigurationStructure.config.mutations.settings.customLists.iconOrText == "Icon"
	local displayTable = parentGroup:AddTable("display", useIcons and 1 or 3)
	local row = displayTable:AddRow()
	row:AddCell()
	if not useIcons then
		row:AddCell()
		row:AddCell()
	end

	local count = 0

	for subListName, subList in TableUtils:OrderedPairs(subLists, function(key)
		return self.subListIndex[key].name
	end) do
		if subListName == "randomized"
			and progressionTableId
		then
			local progressionEntry = self.progressions[self.progressionTranslations[progressionTableId]]
			if progressionEntry
				and progressionEntry[level]
				and progressionEntry[level][self.name] then
				-- So additions to linked progressions don't get stored to the config
				subList = {}

				for _, entryName in pairs(progressionEntry[level][self.name]) do
					if not self:CheckIfEntryIsInListLevel(self.activeList.levels[level], entryName, level, true) then
						if not TableUtils:IndexOf(self.entryCacheForProgressions[level], entryName) then
							table.insert(subList, entryName)
							self.entryCacheForProgressions[level] = self.entryCacheForProgressions[level] or {}
							table.insert(self.entryCacheForProgressions[level], entryName)
						end
					end
				end
			end
		end

		---@cast subList EntryName[]
		for _, entryName in TableUtils:OrderedPairs(subList, function(key)
			return subList[key]
		end) do
			count = count + 1
			local parent = row.Children[useIcons and 1 or ((count % 3) > 0 and (count % 3) or 3)]

			---@type SpellData|PassiveData|StatusData
			local entryData = Ext.Stats.Get(entryName)
			if entryData then
				local entryImageButton = parent:AddImageButton(entryName .. "##" .. level, entryData.Icon ~= "" and entryData.Icon or "Item_Unknown",
					{ 48 * Styler:ScaleFactor(), 48 * Styler:ScaleFactor() })
				if entryImageButton.Image.Icon == "" then
					entryImageButton:Destroy()
					entryImageButton = parent:AddImageButton(entryName .. "##" .. level, "Item_Unknown", { 48 * Styler:ScaleFactor(), 48 * Styler:ScaleFactor() })
				end

				if useIcons then
					entryImageButton.SameLine = #parent.Children > 0
						and ((#parent.Children - 1) % math.floor((self.designerSection.LastSize[1]) / (63 * Styler:ScaleFactor())) ~= 0)
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

				entryImageButton.OnClick = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						local window = Ext.IMGUI.NewWindow(entryName)
						window.Closeable = true
						window.AlwaysAutoResize = true

						window.OnClose = function()
							window:Destroy()
							window = nil
						end
						ResourceManager:RenderDisplayWindow(entryData, window)
					elseif not self.activeList.modId then
						if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
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
						else
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
											---@type CustomSubList
											local subList = self.activeList.levels[handle.level][handle.progressionTableId and "linkedProgressions" or "manuallySelectedEntries"]
											if handle.progressionTableId then
												subList = subList[handle.progressionTableId]
											end

											if subListCategory ~= "randomized" or not progressionTableId then
												subList[subListCategory] = subList[subListCategory] or {}
												table.insert(subList[subListCategory], handle.entryName)
											end
											if handle.subListName then
												local index = TableUtils:IndexOf(subList[handle.subListName], handle.entryName)
												if index then
													subList[handle.subListName][index] = nil
													if not subList[handle.subListName]() then
														subList[handle.subListName].delete = true
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

				local tooltip = entryImageButton:Tooltip()

				entryImageButton.OnHoverEnter = function()
					Helpers:KillChildren(tooltip)
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						ResourceManager:RenderDisplayWindow(entryData, tooltip)
					else
						tooltip:AddText("\t " .. entryName)
						tooltip:AddText("\t " .. self.subListIndex[subListName].name)
						if progressionTableId then
							tooltip:AddText("\t  Linked from Progression " .. self.progressionTranslations[progressionTableId])
						end
					end
				end

				entryImageButton.OnHoverLeave = function()
					Helpers:KillChildren(tooltip)
					tooltip:AddText("\t " .. entryName)
					tooltip:AddText("\t " .. self.subListIndex[subListName].name)
					if progressionTableId then
						tooltip:AddText("\tLinked from Progression: " .. self.progressionTranslations[progressionTableId])
					end
				end
			end
		end
	end
end

function ListDesignerBaseClass:buildBrowser()
end

function ListDesignerBaseClass:buildStatBrowser(statType)
	Helpers:KillChildren(self.browserTabs[statType])

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

						local level = (stat.ModifierList == "SpellData" and stat.Level ~= "" and stat.Level > 0) and stat.Level or 1
						self.activeList.levels[level] = self.activeList.levels[level] or {}
						local subLevelList = self.activeList.levels[level]

						if not self:CheckIfEntryIsInListLevel(subLevelList, statName, level) then
							subLevelList.manuallySelectedEntries = subLevelList.manuallySelectedEntries or
								TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)

							local leveledSubList = subLevelList.manuallySelectedEntries
							leveledSubList.randomized = leveledSubList.randomized or {}

							table.insert(leveledSubList.randomized, statName)
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
			for l = 1, 30 do
				if self.activeList.levels and self.activeList.levels[l] and self:CheckIfEntryIsInListLevel(self.activeList.levels[l], statName, l) then
					return true
				end
			end
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
			end
		end)
end

function ListDesignerBaseClass:buildProgressionBrowser()
	if self.browserTabs["Progressions"] then
		Helpers:KillChildren(self.browserTabs["Progressions"])

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

				for progressionName, indexedProgLevelLists in TableUtils:OrderedPairs(self.progressions) do
					if progressionName:upper():find(searchValue) then
						---@type ExtuiSelectable
						local select = resultsGroup:AddSelectable(progressionName)

						select.OnClick = function()
							resultsGroup.Visible = false
							Helpers:KillChildren(levelView)

							local header = levelView:AddSeparatorText(progressionName)
							header.Font = "Large"
							header:SetStyle("SeparatorTextAlign", 0.5)

							Styler:MiddleAlignedColumnLayout(levelView, function(ele)
								local copyAllButton = ele:AddButton("Copy All")

								copyAllButton.OnClick = function()
									for level, lists in TableUtils:OrderedPairs(indexedProgLevelLists, function(key)
										return tonumber(key)
									end) do
										self.activeList.levels = self.activeList.levels or {}
										self.activeList.levels[level] = self.activeList.levels[level] or {}
										local subLevelList = self.activeList.levels[level]
										subLevelList.manuallySelectedEntries = subLevelList.manuallySelectedEntries or
											TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)

										local leveledSubList = subLevelList.manuallySelectedEntries
										leveledSubList.randomized = leveledSubList.randomized or {}

										for _, spell in pairs(lists[self.name] or {}) do
											if not self:CheckIfEntryIsInListLevel(subLevelList, spell, level) then
												table.insert(leveledSubList.randomized, spell)
											end
										end
									end

									self:buildDesigner()
								end

								local tableUUID = self.progressionTranslations[progressionName]
								local hasProgression = TableUtils:IndexOf(self.activeList.levels, function(value)
									return value.linkedProgressions ~= nil and value.linkedProgressions[tableUUID] ~= nil
								end) ~= nil

								local linkButton = ele:AddButton(hasProgression and "Unlink" or "Link (?)")
								linkButton:Tooltip():AddText(
									"\t (Un)Forms a link to this progression, dynamically pulling all entries from the ProgressionTable when needed. See SpellList wiki page.")

								linkButton.SameLine = true
								linkButton.OnClick = function()
									if hasProgression then
										for _, subList in TableUtils:OrderedPairs(self.activeList.levels) do
											if subList.linkedProgressions and subList.linkedProgressions[tableUUID] then
												subList.linkedProgressions[tableUUID].delete = true
											end
										end
										linkButton.Label = "Link (?)"
									else
										self.activeList.levels = self.activeList.levels or {}
										for level in pairs(self.progressions[progressionName]) do
											self.activeList.levels[level] = self.activeList.levels[level] or {}
											self.activeList.levels[level].linkedProgressions = self.activeList.levels[level].linkedProgressions or {}
											self.activeList.levels[level].linkedProgressions[tableUUID] =
												TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customSubList)
										end
										linkButton.Label = "Unlink"
									end
									hasProgression = not hasProgression
									self:buildDesigner()
								end
							end)

							local progTable = Styler:TwoColumnTable(levelView, progressionName)
							for level, lists in TableUtils:OrderedPairs(indexedProgLevelLists, function(key)
								return tonumber(key)
							end, function(key, value)
								return value[self.name] ~= nil
							end) do
								local row = progTable:AddRow()
								row:AddCell():AddText(tostring(level))

								local spellCell = row:AddCell()
								for i, entryName in ipairs(lists[self.name] or {}) do
									---@type SpellData|PassiveData|StatusData
									local entryData = Ext.Stats.Get(entryName)

									local entryImageButton = spellCell:AddImageButton(entryName .. i, entryData.Icon ~= "" and entryData.Icon or "Item_Unknown", { 48, 48 })
									local tooltipFunction = Styler:HyperlinkRenderable(entryImageButton, entryName, "Shift", false, entryName, function(parent)
										ResourceManager:RenderDisplayWindow(entryData, parent)
									end)
									entryImageButton.SameLine = (i - 1) % (math.floor(self.browserTabs["Progressions"].LastSize[1] / 64)) ~= 0
									entryImageButton.CanDrag = true
									entryImageButton.DragDropType = "EntryReorder"
									entryImageButton.UserData = {
										entryName = entryName
									} --[[@as EntryHandle]]

									for l = 1, 30 do
										if self.activeList.levels and self.activeList.levels[l] and self:CheckIfEntryIsInListLevel(self.activeList.levels[l], entryName, l) then
											entryImageButton.Tint = { 1, 1, 1, 0.2 }
											break
										end
									end

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

function ListDesignerBaseClass:buildProgressionIndex()
	if not self.hasIndexedRelevantProgressions and self.progressionLinkedNodes then
		self.hasIndexedRelevantProgressions = true

		---@param progression ResourceProgression
		---@return boolean?
		local function hasRelevantNodes(progression)
			for _, node in pairs(self.progressionLinkedNodes) do
				if progression[node]
					and ((type(progression[node]) == "string" and progression[node] ~= "")
						or (type(progression[node]) == "userdata" and next(Ext.Types.Serialize(progression[node]))))
				then
					return true
				end
			end
		end

		for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")
			if hasRelevantNodes(progression) then
				if not self.progressionTranslations[progression.Name] then
					self.progressionTranslations[progression.Name] = progression.TableUUID
				end
				self.progressionTranslations[progression.TableUUID] = progression.Name

				self.progressions[progression.Name] = self.progressions[progression.Name] or {}
				self.progressions[progression.Name][progression.Level] = self.progressions[progression.Name][progression.Level] or {}
				self.progressions[progression.Name][progression.Level][self.name] = self.progressions[progression.Name][progression.Level][self.name] or {}

				local nodesToIterate = {}
				for _, node in pairs(self.progressionLinkedNodes) do
					if type(progression[node]) == "table" or type(progression[node]) == "userdata" then
						table.insert(nodesToIterate, progression[node])
					else
						local splitTable = {}
						for _, val in string.gmatch(progression[node], "([^;]+)") do
							table.insert(splitTable, val)
						end
						if next(splitTable) then
							table.insert(nodesToIterate, splitTable)
						end
					end
				end

				for _, meta in TableUtils:CombinedPairs(table.unpack(nodesToIterate)) do
					local success, error = pcall(function(...)
						self.iterateProgressionEntriesFunc(meta, function(name)
							if not TableUtils:IndexOf(self.progressions[progression.Name], function(value)
									return TableUtils:IndexOf(value[self.name], name) ~= nil
								end)
							then
								table.insert(self.progressions[progression.Name][progression.Level][self.name], name)
							end
						end)
					end)

					if not success then
						Logger:BasicWarning("Could not process a node of progression %s (%s) due to error %s", progression.ResourceUUID, progression.Name, error)
					end
				end

				if #self.progressions[progression.Name][progression.Level][self.name] == 0 then
					self.progressions[progression.Name][progression.Level][self.name] = nil
					if not next(self.progressions[progression.Name][progression.Level]) then
						self.progressions[progression.Name][progression.Level] = nil
					end
				else
					self.progressionTableToProgression[progression.TableUUID] = self.progressionTableToProgression[progression.TableUUID] or {}
					self.progressionTableToProgression[progression.TableUUID][progression.Level] = progressionId
				end
			end
		end
	end
end

---@param leveledSubList LeveledSubList
---@param entryName string
---@param level number
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
	elseif leveledSubList.linkedProgressions then
		if TableUtils:IndexOf(leveledSubList.linkedProgressions, predicate) then
			return true
		end

		if not ignoreProgressions then
			for progressionId, subLists in pairs(leveledSubList.linkedProgressions) do
				if TableUtils:IndexOf(self.progressions[self.progressionTranslations[progressionId]][level], entryName) then
					return true
				end
			end
		end
	end

	return false
end

---@param export MutationsConfig
---@param mutator Mutator
---@param lists Guid[]
---@param removeMissingDependencies boolean?
function ListDesignerBaseClass:HandleDependences(export, mutator, lists, removeMissingDependencies)
	self:buildProgressionIndex()

	local progressionSources = Ext.StaticData.GetSources("Progression")

	---@param statName string
	---@param container table?
	---@return boolean?
	local function buildStatDependency(statName, container)
		---@type (SpellData|PassiveData|StatusData)?
		local stat = Ext.Stats.Get(statName)
		if stat then
			if not removeMissingDependencies then
				container = container or mutator
				container.modDependencies = container.modDependencies or {}
				if not container.modDependencies[stat.OriginalModId] then
					local name, author, version = Helpers:BuildModFields(stat.OriginalModId)
					if author == "Larian" then
						return true
					end

					container.modDependencies[stat.OriginalModId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = stat.OriginalModId,
						packagedItems = {}
					}
				end
				local name = Ext.Loca.GetTranslatedString(stat.DisplayName, statName)
				name = name == "" and statName or name
				container.modDependencies[stat.OriginalModId].packagedItems[statName] = name
			end
			return true
		else
			return false
		end
	end

	for l, listId in pairs(lists) do
		local list = MutationConfigurationProxy[self.configKey][listId]
		local listModId = list.modId
		if not listModId then
			--- @type CustomList
			local listDef = removeMissingDependencies == true
				and export[self.configKey][listId]
				or TableUtils:DeeplyCopyTable(ConfigurationStructure.config.mutations[self.configKey][listId]._real)

			listId = listId .. "Exported"

			if listDef.levels then
				for level, levelSubList in pairs(listDef.levels) do
					if levelSubList.linkedProgressions then
						for progressionTableId, sublists in pairs(levelSubList.linkedProgressions) do
							for _, entries in pairs(sublists) do
								for i, entry in pairs(entries) do
									if not buildStatDependency(entry, listDef) then
										entries[i] = nil
									end
								end
								TableUtils:ReindexNumericTable(entries)
							end

							local progressionId = SpellListDesigner.progressionTableToProgression[progressionTableId][level]
							if progressionId then
								---@type ResourceProgression
								local progression = Ext.StaticData.Get(progressionId, "Progression")
								if not progression then
									levelSubList.linkedProgressions[progressionId] = nil
								elseif not removeMissingDependencies then
									local progressionSource = TableUtils:IndexOf(progressionSources, function(value)
										return TableUtils:IndexOf(value, progressionId) ~= nil
									end)
									if progressionSource then
										listDef.modDependencies = listDef.modDependencies or {}
										if not listDef.modDependencies[progressionSource] then
											local name, author, version = Helpers:BuildModFields(progressionSource)
											if author == "Larian" then
												goto continue
											end
											listDef.modDependencies[progressionSource] = {
												modName = name,
												modAuthor = author,
												modVersion = version,
												modId = progressionSource,
												packagedItems = {}
											}
										end
										listDef.modDependencies[progressionSource].packagedItems[progressionId] = progression.Name
									end
									::continue::
								end
							end
						end
					end

					if levelSubList.manuallySelectedEntries then
						for _, entries in pairs(levelSubList.manuallySelectedEntries) do
							for i, entry in pairs(entries) do
								if not buildStatDependency(entry, listDef) then
									entries[i] = nil
								end
							end
							TableUtils:ReindexNumericTable(entries)
						end
					end
				end
			end

			export[self.configKey] = export[self.configKey] or {}
			if not export[self.configKey][listId] then
				export[self.configKey][listId] = listDef
			end
		else
			local name, author, version = Helpers:BuildModFields(listModId)
			mutator.modDependencies = mutator.modDependencies or {}
			mutator.modDependencies[listModId] = {
				modAuthor = author,
				modName = name,
				modVersion = version,
				modId = listModId,
				packagedItems = nil
			}
		end
	end
end
