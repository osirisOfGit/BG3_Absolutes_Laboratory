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
	---@type ExtuiChildWindow
	browserSection = nil,
	---@type ExtuiPopup	
	popup = nil,

	---@type string[]?
	progressionLinkedNodes = nil,
	-- Intentionally not cloning the below in :new so all lists share the progression index
	hasIndexedRelevantProgressions = false,
	--- ProgressionId: (ProgressionName: Level: ListName)
	---@type {[Guid]: Guid[][][]}
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

	--- For Drag/Drop tracking
	selectedEntries = {
		---@type EntryHandle[]
		entryDatas = {},
		---@type ExtuiImageButton[]
		handles = {},
		context = "Main",
		linkedEntries = false
	},

	-- Shared amongst inheritors
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
---@param progressionLinkedNodes string[]
---@return ListDesignerBaseClass
function ListDesignerBaseClass:new(name, configKey, progressionLinkedNodes)
	local instance = {}

	setmetatable(instance, self)
	self.__index = self
	self.name = name
	self.configKey = configKey
	self.progressionLinkedNodes = progressionLinkedNodes
	self.entryCacheForProgressions = {}
	self.selectedEntries = {
		entries = {},
		handles = {},
		context = "Main",
		linkedEntries = false
	}

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
		self.browserSection = row:AddCell():AddChildWindow("Browser")

		self.popup = self.mainWindow:AddPopup(self.name .. "popup")
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
			self.popup:AddSelectable("Edit").OnClick = function()
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

						self.browserSection.Visible = false
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

function ListDesignerBaseClass:buildDesigner()
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

	local leveledListGroup = self.designerSection:AddGroup("leveledLists")

	for level = 1, 30 do
		local listGroup = leveledListGroup:AddGroup("list" .. level)
		listGroup:SetColor("Border", { 1, 0, 0, 1 })
		listGroup:AddText(tostring(level) .. (level < 10 and "  " or "")).Font = "Big"
		listGroup.UserData = level
		if not self.activeList.modId then
			listGroup.DragDropType = "EntryReorder"
		end

		local spellGroup = listGroup:AddGroup("entries")
		spellGroup.SameLine = true

		if self.activeList.levels and self.activeList.levels[level] then
			if self.activeList.levels[level].manuallySelectedEntries then
				buildSpellListFromSubList(spellGroup, self.activeList.levels[level].manuallySelectedEntries, level)
			end

			if self.activeList.levels[level].linkedProgressions and next(self.activeList.levels[level].linkedProgressions) then
				local sep = spellGroup:AddSeparatorText("Linked Progressions")
				local progGroup = spellGroup:AddGroup("linkedProg")

				for progressionTableId, subLists in TableUtils:OrderedPairs(self.activeList.levels[level].linkedProgressions) do
					buildSpellListFromSubList(progGroup, subLists, level, progressionTableId)
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
			if #self.selectedEntries.entryDatas > 0 then
				entryHandles = self.selectedEntries.entryDatas

				local index = TableUtils:IndexOf(self.selectedEntries.entryDatas, function(value)
					return value.entryName == entryElement.UserData.spellName
				end)
				if not index then
					table.insert(entryHandles, entryElement.UserData)
				end

				if self.selectedEntries.context ~= "Main" then
					for _, handle in pairs(self.selectedEntries.handles) do
						handle:SetColor("Button", { 1, 1, 1, 0 })
					end
				end

				self.selectedEntries.handles = {}
				self.selectedEntries.entryDatas = {}
			else
				entryHandles = { entryElement.UserData }
			end

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

		if #spellGroup.Children == 0 then
			spellGroup:AddDummy(56, 56)
		end

		listGroup:AddNewLine()
	end
end

---@param parentGroup ExtuiGroup
---@param subLists CustomSubList
---@param level number
---@param progressionTableId string?
function ListDesignerBaseClass:buildSpellListFromSubList(parentGroup, subLists, level, progressionTableId)
	if progressionTableId and not subLists.randomized then
		subLists.randomized = {}
	end
	for subListName, subList in TableUtils:OrderedPairs(subLists, function(key)
		return self.subListIndex[key].name
	end) do
		if subListName == "randomized" and progressionTableId and self.progressions[self.progressionTranslations[progressionTableId]][level] then
			-- So additions to linked progressions don't get stored to the config
			subList = {}

			for _, entryName in pairs(self.progressions[self.progressionTranslations[progressionTableId]][level]) do
				if not self:CheckIfEntryIsInListLevel(self.activeList.levels[level], entryName, level, true) then
					if not TableUtils:IndexOf(self.entryCacheForProgressions[level], entryName) then
						table.insert(subList, entryName)
						self.entryCacheForProgressions[level] = self.entryCacheForProgressions[level] or {}
						table.insert(self.entryCacheForProgressions[level], entryName)
					end
				end
			end
		end

		---@cast subList EntryName[]
		for _, entryName in TableUtils:OrderedPairs(subList, function(key)
			return subList[key]
		end) do
			---@type SpellData|PassiveData|StatusData
			local entryData = Ext.Stats.Get(entryName)
			if entryData then
				local entryImageButton = parentGroup:AddImageButton(entryName .. "##" .. level, entryData.Icon, { 48 * Styler:ScaleFactor(), 48 * Styler:ScaleFactor() })
				if entryImageButton.Image.Icon == "" then
					entryImageButton:Destroy()
					entryImageButton = parentGroup:AddImageButton(entryName .. "##" .. level, "Item_Unknown", { 48 * Styler:ScaleFactor(), 48 * Styler:ScaleFactor() })
				end
				entryImageButton.SameLine = #parentGroup.Children > 0
					and ((#parentGroup.Children - 1) % math.floor((self.designerSection.LastSize[1]) / (63 * Styler:ScaleFactor())) ~= 0)

				entryImageButton:SetColor("Button", self.subListIndex[subListName].colour)
				entryImageButton.UserData = {
					entryName = entryName,
					subListName = subListName,
					level = level,
					progressionTableId = progressionTableId
				} --[[@as EntryHandle]]


				if not self.activeList.modId and not progressionTableId then
					entryImageButton.CanDrag = true
					entryImageButton.DragDropType = "SpellReorder"

					---@param preview ExtuiTreeParent
					entryImageButton.OnDragStart = function(_, preview)
						if self.selectedEntries.context == "Main" and #self.selectedEntries.entryDatas > 0 then
							preview:AddText("Moving:")
							for _, spellName in pairs(self.selectedEntries.entryDatas) do
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
								self.selectedEntries.entryDatas = {}
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

							table.insert(self.selectedEntries.entryDatas, entryImageButton.UserData)
							table.insert(self.selectedEntries.handles, entryImageButton)
							entryImageButton:SetColor("Button", { 0, 1, 0, .8 })
						elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Alt" then
							if self.selectedEntries.context == "Main" then
								local index = TableUtils:IndexOf(self.selectedEntries.entryDatas, function(value)
									return value.entryName == entryName
								end)
								if index then
									table.remove(self.selectedEntries.entryDatas, index)
									table.remove(self.selectedEntries.handles, index)

									entryImageButton:SetColor("Button", self.subListIndex[entryImageButton.UserData.subListName].colour)
								end
							end
						else
							Helpers:KillChildren(self.popup)
							self.popup:Open()
							for subListCategory, index in TableUtils:OrderedPairs(self.subListIndex) do
								if subListCategory ~= subListName and (subListCategory ~= "blackListed" or progressionTableId) then
									self.popup:AddSelectable("Set As " .. index.name .. "##" .. level).OnClick = function()
										---@type EntryHandle[]
										local handles = {}
										if self.selectedEntries.context == "Main" and #self.selectedEntries.entryDatas > 0 then
											handles = self.selectedEntries.entryDatas
										end

										if not TableUtils:IndexOf(handles, function(value)
												return value.entryName == entryName
											end)
										then
											table.insert(handles, entryImageButton.UserData)
										end

										for _, handle in pairs(handles) do
											---@type CustomSubList
											local subList = self.activeList.levels[handle.level][handle.progressionTableId and "linkedProgressions" or "selectedEntries"]
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
										self.selectedEntries.entryDatas = {}
										self:buildDesigner()
									end
								end
							end

							if not progressionTableId then
								self.popup:AddSelectable("Remove").OnClick = function()
									---@type EntryHandle[]
									local handles = {}
									if self.selectedEntries.context == "Main" and #self.selectedEntries.entryDatas > 0 then
										handles = self.selectedEntries.entryDatas
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
									self.selectedEntries.entryDatas = {}
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

---@param iterateEntriesFunc fun(resource: any, addToListFunc: fun(name: string))
function ListDesignerBaseClass:buildProgressionIndex(iterateEntriesFunc)
	if not self.hasIndexedRelevantProgressions and self.progressionLinkedNodes then
		self.hasIndexedRelevantProgressions = true

		---@param progression ResourceProgression
		---@return boolean?
		local function hasRelevantNodes(progression)
			for _, node in pairs(self.progressionLinkedNodes) do
				if progression[node] and next(Ext.Types.Serialize(progression[node])) then
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
					table.insert(nodesToIterate, progression[node])
				end

				for _, meta in TableUtils:CombinedPairs(table.unpack(nodesToIterate)) do
					iterateEntriesFunc(meta, function(name)
						table.insert(self.progressions[progression.Name][progression.Level][self.name], name)
					end)
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
---@param spellName string
---@param level number
---@param ignoreProgressions boolean?
---@return boolean
function ListDesignerBaseClass:CheckIfEntryIsInListLevel(leveledSubList, spellName, level, ignoreProgressions)
	---@param value CustomSubList
	---@return boolean?
	local predicate = function(value)
		for _, subList in pairs(value) do
			if TableUtils:IndexOf(subList, spellName) ~= nil then
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
				if TableUtils:IndexOf(self.progressions[self.progressionTranslations[progressionId]][level], spellName) then
					return true
				end
			end
		end
	end

	return false
end
