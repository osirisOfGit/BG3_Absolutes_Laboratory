SpellListDesigner = {}

SpellListDesigner.selectedSpells = {
	---@type SpellHandle[]
	spells = {},
	---@type ExtuiImageButton[]
	handles = {},
	context = "Main",
	linkedSpells = false
}

---@type {[string]: SpellName[][]}
SpellListDesigner.progressions = {}

SpellListDesigner.progressionTranslation = {}

function SpellListDesigner:buildProgressionIndex()
	if not next(self.progressions) then
		for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")
			if progression.AddSpells and next(Ext.Types.Serialize(progression.AddSpells))
				or progression.SelectSpells and next(Ext.Types.Serialize(progression.SelectSpells))
			then
				if not self.progressionTranslation[progression.Name] then
					self.progressionTranslation[progression.Name] = progression.TableUUID
				end
				self.progressionTranslation[progression.TableUUID] = progression.Name

				self.progressions[progression.Name] = self.progressions[progression.Name] or {}
				self.progressions[progression.Name][progression.Level] = self.progressions[progression.Name][progression.Level] or {}

				for _, addSpellMeta in TableUtils:CombinedPairs(progression.AddSpells, progression.SelectSpells) do
					---@type ResourceSpellList
					local progSpellList = Ext.StaticData.Get(addSpellMeta.SpellUUID, "SpellList")

					for _, spellName in pairs(progSpellList.Spells) do
						if not TableUtils:IndexOf(self.progressions[progression.Name], function(value)
								return TableUtils:IndexOf(value, spellName) ~= nil
							end)
						then
							table.insert(self.progressions[progression.Name][progression.Level], spellName)
						end
					end
				end
				if self.progressions[progression.Name][progression.Level] and #self.progressions[progression.Name][progression.Level] == 0 then
					self.progressions[progression.Name][progression.Level] = nil
				end
			end
		end
	end
end

---@class SpellSubListIndex
---@field name string
---@field description string
---@field colour number[]

---@type {[string] : SpellSubListIndex}
SpellListDesigner.subListIndex = {
	["guaranteed"] = { name = "Guaranteed", description = "Will always be assigned to an enemy that is the assigned level or higher", colour = {} },
	["randomized"] = { name = "Randomized", description = "Will be placed into a pool of spells assigned to the same level to be randomly chosen per the mutator's config", colour = {} },
	["startOfCombatOnly"] = { name = "Cast On Combat Start", description = "Will only be cast on combat start - will not be added to the entity's spellList", colour = {} },
	["onLoadOnly"] = { name = "Cast On Level Load", description = "Will be cast as soon as the mutator is applied - will not be added to the entity's spellList", colour = {} },
	["blackListed"] = { name = "Blacklisted", description = "Only available for spells added via a linked progression - will prevent this spell from being added to the entity's spellList or cast by the entity", colour = {} }
}

---@type ExtuiWindow?
SpellListDesigner.spellListDesignerWindow = nil

---@type ExtuiWindow?
SpellListDesigner.formWindow = nil

---@type ExtuiTable
SpellListDesigner.displayTable = nil

---@type ExtuiSelectable?
local activeSpellList

function SpellListDesigner:buildSpellDesignerWindow(activeList)
	local spellLists = ConfigurationStructure.config.mutations.spellLists

	if not self.spellListDesignerWindow then
		self:buildProgressionIndex()

		self.spellListDesignerWindow = Ext.IMGUI.NewWindow("Spell List Designer")
		self.spellListDesignerWindow.Closeable = true
		self.spellListDesignerWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())

		self.formWindow = Ext.IMGUI.NewWindow("Spell List Form")
		self.formWindow.Closeable = true
		self.formWindow:SetStyle("WindowMinSize", 150 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())
		self.formWindow.Open = false

		SpellListDesigner.displayTable = self.spellListDesignerWindow:AddTable("SpellListDesigner", 3)
		self.displayTable.Resizable = true
		self.displayTable.NoSavedSettings = true
		self.displayTable:AddColumn("SpellLists", "WidthFixed")
		self.displayTable:AddColumn("", "WidthStretch")
		self.displayTable:AddColumn("ProgressionBrowser", "WidthFixed")
		self.displayTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
		self.displayTable.ColumnDefs[3].Width = 0

		local row = self.displayTable:AddRow()
		SpellListDesigner.lists = row:AddCell():AddChildWindow("lists")
		self.lists.NoSavedSettings = true

		SpellListDesigner.designer = row:AddCell():AddChildWindow("designer")
		self.designer.NoSavedSettings = true
		self.designer.ChildAlwaysAutoResize = true
		self.designer.Visible = false

		SpellListDesigner.browser = row:AddCell():AddTabBar("Browser")
		self.browser.Visible = false

		self.progressionBrowser = self.browser:AddTabItem("Progressions"):AddChildWindow("progressionBrowser")
		self.progressionBrowser.NoSavedSettings = true
		self.progressionBrowser.ChildAlwaysAutoResize = true

		self.spellBrowser = self.browser:AddTabItem("Spells"):AddChildWindow("SpellBrowser")
		self.spellBrowser.NoSavedSettings = true
		self.spellBrowser.ChildAlwaysAutoResize = true

		local colorSettings = self.designer:AddGroup("colorSetting")
		colorSettings.UserData = "keep"
		colorSettings:AddText("Click A Color To Change It, Hover for Tooltips"):SetStyle("Alpha", 0.6)

		for subListName, colour in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.settings.spellLists.subListColours, function(key)
			return self.subListIndex[key].name
		end) do
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
				Helpers:KillChildren(self.designer)
				self:buildSpellListDesigner(spellLists[activeSpellList.UserData])
			end
		end
	else
		Helpers:KillChildren(self.lists, self.designer)
		self.spellListDesignerWindow.Open = true
		self.spellListDesignerWindow:SetFocus()
		self.designer.Size = { 0, 0 }
		activeSpellList = nil
	end

	local headerTitle = self.lists:AddSeparatorText("Your SpellLists ( ? )")
	headerTitle:Tooltip():AddText("\t Ctrl-click on an entry to manage it")
	headerTitle:SetStyle("SeparatorTextAlign", 0.5)

	local popup = self.lists:AddPopup("SpellListPopup")

	for guid, spellList in TableUtils:OrderedPairs(spellLists, function(key)
		return spellLists[key].name
	end) do
		---@type ExtuiSelectable
		local spellListSelect = self.lists:AddSelectable(spellList.name)
		if spellList.description and spellList.description ~= "" then
			spellListSelect:Tooltip():AddText(spellList.description)
		end
		spellListSelect.UserData = guid

		spellListSelect.OnClick = function()
			if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
				Helpers:KillChildren(popup)
				popup:Open()
				popup:AddSelectable("Edit").OnClick = function()
					self.formWindow.Open = true
					self.formWindow:SetFocus()

					FormBuilder:CreateForm(self.formWindow, function(formResults)
						spellList.name = formResults.Name
						spellList.description = formResults.Description

						self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
						self.formWindow.Open = false
					end, {
						{
							label = "Name",
							type = "Text",
							errorMessageIfEmpty = "Required Field",
							defaultValue = spellList.name
						},
						{
							label = "Description",
							type = "Multiline",
							defaultValue = spellList.description
						}
					})
				end

				popup:AddSelectable("Delete").OnClick = function()
					spellList.delete = true
					self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
				end
			else
				if activeSpellList then
					activeSpellList.Selected = false
					Helpers:KillChildren(self.designer)
				end
				self.designer.Visible = true

				activeSpellList = spellListSelect

				self.displayTable.ColumnDefs[3].Width = 400 * Styler:ScaleFactor()
				self.browser.Visible = true
				self:buildProgressionBrowser(spellList)
				self:buildSpellBrowser(spellList)

				self:buildSpellListDesigner(spellList)
			end
		end

		if guid == activeList then
			spellListSelect.Selected = true
			spellListSelect:OnClick()
		end
	end

	self.lists:AddNewLine()

	---@type ExtuiSelectable
	local createListButton = self.lists:AddSelectable("Create a List")

	createListButton.OnClick = function()
		createListButton.Selected = false

		self.formWindow.Open = true
		self.formWindow:SetFocus()

		FormBuilder:CreateForm(self.formWindow, function(formResults)
			local spellList = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.leveledSpellList)

			spellList.name = formResults.Name
			spellList.description = formResults.Description

			spellLists[FormBuilder:generateGUID()] = spellList
			self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
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

---@param spellList SpellList
function SpellListDesigner:buildSpellListDesigner(spellList)
	Helpers:KillChildren(self.designer)
	local headerTitle = Styler:CheapTextAlign(spellList.name, self.designer)
	headerTitle.Font = "Big"
	if spellList.description and spellList.description ~= "" then
		headerTitle.Label = headerTitle.Label .. "( ? )"
		headerTitle:Tooltip():AddText("\t " .. spellList.description).TextWrapPos = 800 * Styler:ScaleFactor()
	end

	if self.designer.LastSize[1] == 0 then
		Ext.Timer.WaitFor(10, function()
			self:buildSpellListDesigner(spellList)
		end)
		return
	end

	local tipsButton = self.designer:AddButton("Tips")
	tipsButton:Tooltip():AddText([[
	This designer allows you to construct custom spell lists and/or assign Laboratory-specific properties to existing Progression-based Spell lists
	The numbers below represent character level, not class or spell levels.
	Use the Progression Browser to search for a progression series that has at least one associated Spell List, and either copy its spells to a given level or link your Spell List to it
	If you link it, you won't be able to move spells to different levels or outright delete them, but you can still assign them to different categories or blacklist them.
	Spells default to the randomized category, and since spell lists are freshly inspected every LevelGameplayReady event, any uncategorized spells discovered will be automatically assigned there during the mutator application.
	Spells you manually select can be assigned to any level and category, except blacklist (remove them instead)
	All non-linked Spells (and all spells in the Browsers) can be drag and dropped to any level to place them there. If assigned a category, that category will be preserved.
	Click on a spell in the main view to display the popup that allows you to recategorize that spell
	
	List of Shortcuts:
	- Shift: Hold before hovering on a spell to view its complete tooltip. Click on a spell while holding to launch a dedicated window for that tooltip
	- Ctrl: Multi-select, adding those spells to a group that you can collectively drag and drop or assign to one category. You can only multi-select spells that are identical typse (linked, non-linked, in browser sidebar)
	- Alt: Remove a spell from the ongoing multi-select
	]])
	local deleteAllButton = self.designer:AddButton("Delete All Non-Linked Spells")
	deleteAllButton.OnClick = function()
		for _, leveledSubList in TableUtils:OrderedPairs(spellList.levels) do
			if leveledSubList.selectedSpells then
				leveledSubList.selectedSpells.delete = true
			end
		end
		self:buildSpellListDesigner(spellList)
	end

	local leveledListGroup = self.designer:AddGroup("leveledLists")

	local popup = self.designer:AddPopup("SpellActionPopup")

	---@type SpellName[][]
	local spellCacheForProgressions = {}

	---@param parentGroup ExtuiGroup
	---@param subLists SpellSubLists
	---@param level number
	---@param progressionTableId string?
	local function buildSpellListFromSubList(parentGroup, subLists, level, progressionTableId)
		if progressionTableId and not subLists.randomized then
			subLists.randomized = {}
		end
		for subListName, subList in TableUtils:OrderedPairs(subLists, function(key)
			return self.subListIndex[key].name
		end) do
			if subListName == "randomized" and progressionTableId and self.progressions[self.progressionTranslation[progressionTableId]][level] then
				-- So additions to linked progressions don't get stored to the config
				subList = {}

				for _, spellName in pairs(self.progressions[self.progressionTranslation[progressionTableId]][level]) do
					if not self:CheckIfSpellIsInSpellListLevel(spellList.levels[level], spellName, level, true) then
						if not TableUtils:IndexOf(spellCacheForProgressions[level], spellName) then
							table.insert(subList, spellName)
							spellCacheForProgressions[level] = spellCacheForProgressions[level] or {}
							table.insert(spellCacheForProgressions[level], spellName)
						end
					end
				end
			end

			---@cast subList SpellName[]
			for sI, spellName in TableUtils:OrderedPairs(subList, function(key)
				return subList[key]
			end) do
				---@type SpellData
				local spellData = Ext.Stats.Get(spellName)

				local spellImage = parentGroup:AddImageButton(spellName .. "##" .. level, spellData.Icon, { 48, 48 })
				if spellImage.Image.Icon == "" then
					spellImage:Destroy()
					spellImage = parentGroup:AddImageButton(spellName .. "##" .. level, "Item_Unknown", { 48, 48 })
				end
				spellImage.SameLine = #parentGroup.Children > 0 and ((#parentGroup.Children - 1) % math.floor((self.designer.LastSize[1]) / 63) ~= 0)
				spellImage:SetColor("Button", self.subListIndex[subListName].colour)
				spellImage.UserData = {
					spellName = spellName,
					subListName = subListName,
					level = level,
					progressionTableId = progressionTableId
				} --[[@as SpellHandle]]

				if not progressionTableId then
					spellImage.CanDrag = true
					spellImage.DragDropType = "SpellReorder"

					---@param spellImage ExtuiImageButton
					---@param preview ExtuiTreeParent
					spellImage.OnDragStart = function(spellImage, preview)
						if self.selectedSpells.context == "Main" and #self.selectedSpells.spells > 0 then
							preview:AddText("Moving:")
							for _, spellName in pairs(self.selectedSpells.spells) do
								preview:AddText(spellName.spellName)
							end
						else
							preview:AddText("Moving " .. spellName)
						end
					end
				end

				spellImage.OnClick = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						local window = Ext.IMGUI.NewWindow(spellName)
						window.Closeable = true
						window.AlwaysAutoResize = true

						window.OnClose = function()
							window:Destroy()
							window = nil
						end
						ResourceManager:RenderDisplayWindow(spellData, window)
					elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
						if self.selectedSpells.context ~= "Main"
							or (self.selectedSpells.linkedSpells and not progressionTableId)
							or (not self.selectedSpells.linkedSpells and progressionTableId)
						then
							self.selectedSpells.context = "Main"
							self.selectedSpells.spells = {}
							for _, handle in pairs(self.selectedSpells.handles) do
								if handle.UserData.subListName then
									handle:SetColor("Button", self.subListIndex[handle.UserData.subListName].colour)
								else
									handle:SetColor("Button", { 1, 1, 1, 0 })
								end
							end
							self.selectedSpells.handles = {}
						end

						if progressionTableId then
							self.selectedSpells.linkedSpells = true
						else
							self.selectedSpells.linkedSpells = false
						end

						table.insert(self.selectedSpells.spells, spellImage.UserData)
						table.insert(self.selectedSpells.handles, spellImage)
						spellImage:SetColor("Button", { 0, 1, 0, .8 })
					elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Alt" then
						if self.selectedSpells.context == "Main" then
							local index = TableUtils:IndexOf(self.selectedSpells.spells, function(value)
								return value.spellName == spellName
							end)
							if index then
								table.remove(self.selectedSpells.spells, index)
								table.remove(self.selectedSpells.handles, index)

								spellImage:SetColor("Button", self.subListIndex[spellImage.UserData.subListName].colour)
							end
						end
					else
						Helpers:KillChildren(popup)
						popup:Open()
						for subListCategory, index in TableUtils:OrderedPairs(self.subListIndex) do
							if subListCategory ~= subListName and (subListCategory ~= "blackListed" or progressionTableId) then
								popup:AddSelectable("Set As " .. index.name .. "##" .. level).OnClick = function()
									---@type SpellHandle[]
									local handles = {}
									if self.selectedSpells.context == "Main" and #self.selectedSpells.spells > 0 then
										handles = self.selectedSpells.spells
									end

									if not TableUtils:IndexOf(handles, function(value)
											return value.spellName == spellName
										end)
									then
										table.insert(handles, spellImage.UserData)
									end

									for _, handle in pairs(handles) do
										---@type SpellSubLists
										local subList = spellList.levels[handle.level][handle.progressionTableId and "linkedProgressions" or "selectedSpells"]
										if handle.progressionTableId then
											subList = subList[handle.progressionTableId]
										end

										if subListCategory ~= "randomized" or not progressionTableId then
											subList[subListCategory] = subList[subListCategory] or {}
											table.insert(subList[subListCategory], handle.spellName)
										end
										if handle.subListName then
											local index = TableUtils:IndexOf(subList[handle.subListName], handle.spellName)
											if index then
												subList[handle.subListName][index] = nil
											end
										end
									end
									self.selectedSpells.handles = {}
									self.selectedSpells.spells = {}
									self:buildSpellListDesigner(spellList)
								end
							end
						end

						if not progressionTableId then
							popup:AddSelectable("Remove").OnClick = function()
								---@type SpellHandle[]
								local handles = {}
								if self.selectedSpells.context == "Main" and #self.selectedSpells.spells > 0 then
									handles = self.selectedSpells.spells
								end

								if not TableUtils:IndexOf(handles, function(value)
										return value.spellName == spellName
									end)
								then
									table.insert(handles, spellImage.UserData)
								end

								for _, handle in pairs(handles) do
									---@type SpellSubLists
									local subList = spellList.levels[handle.level].selectedSpells

									local index = TableUtils:IndexOf(subList[handle.subListName], handle.spellName)
									if index then
										subList[handle.subListName][index] = nil
									end
								end
								self.selectedSpells.handles = {}
								self.selectedSpells.spells = {}
								self:buildSpellListDesigner(spellList)
							end
						end
					end
				end

				local tooltip = spellImage:Tooltip()

				spellImage.OnHoverEnter = function()
					Helpers:KillChildren(tooltip)
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						ResourceManager:RenderDisplayWindow(spellData, tooltip)
					else
						tooltip:AddText("\t " .. spellName)
						tooltip:AddText("\t " .. self.subListIndex[subListName].name)
						if progressionTableId then
							tooltip:AddText("\t  Linked from Progression " .. self.progressionTranslation[progressionTableId])
						end
					end
				end

				spellImage.OnHoverLeave = function()
					Helpers:KillChildren(tooltip)
					tooltip:AddText("\t " .. spellName)
					tooltip:AddText("\t " .. self.subListIndex[subListName].name)
					if progressionTableId then
						tooltip:AddText("\tLinked from Progression: " .. self.progressionTranslation[progressionTableId])
					end
				end
			end
		end
	end

	for level = 1, 30 do
		local listGroup = leveledListGroup:AddGroup("list" .. level)
		listGroup:SetColor("Border", { 1, 0, 0, 1 })
		listGroup:AddText(tostring(level) .. (level < 10 and "  " or "")).Font = "Big"
		listGroup.UserData = level
		listGroup.DragDropType = "SpellReorder"
		local spellGroup = listGroup:AddGroup("spells")
		spellGroup.SameLine = true

		if spellList.levels and spellList.levels[level] then
			if spellList.levels[level].selectedSpells then
				buildSpellListFromSubList(spellGroup, spellList.levels[level].selectedSpells, level)
			end

			if spellList.levels[level].linkedProgressions and next(spellList.levels[level].linkedProgressions) then
				local sep = spellGroup:AddSeparatorText("Linked Progressions")
				local progGroup = spellGroup:AddGroup("linkedProg")

				for progressionTableId, subLists in TableUtils:OrderedPairs(spellList.levels[level].linkedProgressions) do
					buildSpellListFromSubList(progGroup, subLists, level, progressionTableId)
				end

				if #progGroup.Children == 0 then
					sep:Destroy()
					progGroup:Destroy()
				end
			end
		end

		---@class SpellHandle
		---@field spellName SpellName
		---@field subListName string?
		---@field level number?
		---@field progressionTableId Guid?

		---@param group ExtuiGroup
		---@param spellItem ExtuiImage|ExtuiImageButton
		listGroup.OnDragDrop = function(group, spellItem)
			---@type SpellHandle[]
			local spellHandles = {}
			if #self.selectedSpells.spells > 0 then
				spellHandles = self.selectedSpells.spells

				local index = TableUtils:IndexOf(self.selectedSpells.spells, function(value)
					return value.spellName == spellItem.UserData.spellName
				end)
				if not index then
					table.insert(spellHandles, spellItem.UserData)
				end

				if self.selectedSpells.context ~= "Main" then
					for _, handle in pairs(self.selectedSpells.handles) do
						handle:SetColor("Button", { 1, 1, 1, 0 })
					end
				end

				self.selectedSpells.handles = {}
				self.selectedSpells.spells = {}
			else
				spellHandles = { spellItem.UserData }
			end

			--[[
				spellImage.UserData = {
					spellName = spellName,
					subListName = subListName,
					level = level
				}]]
			spellList.levels[group.UserData] = spellList.levels[group.UserData] or {}
			spellList.levels[group.UserData].selectedSpells = spellList.levels[group.UserData].selectedSpells or {}

			for _, spellHandle in pairs(spellHandles) do
				if not self:CheckIfSpellIsInSpellListLevel(spellList.levels[group.UserData], spellHandle.spellName, group.UserData) then
					spellList.levels[group.UserData].selectedSpells[spellHandle.subListName or "randomized"] =
						spellList.levels[group.UserData].selectedSpells[spellHandle.subListName or "randomized"] or {}

					table.insert(spellList.levels[group.UserData].selectedSpells[spellHandle.subListName or "randomized"], spellHandle.spellName)

					if spellHandle.subListName then
						local index = TableUtils:IndexOf(spellList.levels[spellHandle.level].selectedSpells[spellHandle.subListName], spellHandle.spellName)
						spellList.levels[spellHandle.level].selectedSpells[spellHandle.subListName][index] = nil
					end
				end
			end

			self:buildSpellListDesigner(spellList)
		end

		if #spellGroup.Children == 0 then
			spellGroup:AddDummy(56, 56)
		end

		listGroup:AddNewLine()
	end
end

---@param spellList SpellList
function SpellListDesigner:buildProgressionBrowser(spellList)
	self:buildProgressionIndex()
	Helpers:KillChildren(self.progressionBrowser)

	local searchBox = self.progressionBrowser:AddInputText("")
	searchBox.Hint = "Search Progressions"

	local resultsGroup = self.progressionBrowser:AddGroup("Results")

	local levelView = self.progressionBrowser:AddGroup("Levels")

	local timer
	searchBox.OnChange = function()
		if timer then
			Ext.Timer.Cancel(timer)
		end
		timer = Ext.Timer.WaitFor(200, function()
			Helpers:KillChildren(resultsGroup)
			resultsGroup.Visible = true

			local value = string.upper(searchBox.Text)

			for progressionName, list in TableUtils:OrderedPairs(self.progressions) do
				if progressionName:upper():find(value) then
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
								for level, spells in TableUtils:OrderedPairs(list, function(key)
									return tonumber(key)
								end) do
									spellList.levels[level] = spellList.levels[level] or {}
									local subLevelList = spellList.levels[level]
									subLevelList.selectedSpells = subLevelList.selectedSpells or
										TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.spellSubLists)

									local leveledSubList = subLevelList.selectedSpells
									leveledSubList.randomized = leveledSubList.randomized or {}

									for _, spell in pairs(spells) do
										if not self:CheckIfSpellIsInSpellListLevel(subLevelList, spell, level) then
											table.insert(leveledSubList.randomized, spell)
										end
									end
								end

								self:buildSpellListDesigner(spellList)
							end

							local tableUUID = self.progressionTranslation[progressionName]
							local hasProgression = TableUtils:IndexOf(spellList.levels, function(value)
								return value.linkedProgressions[tableUUID] ~= nil
							end)
							local linkButton = ele:AddButton(hasProgression and "Unlink" or "Link")
							linkButton.SameLine = true
							linkButton.OnClick = function()
								if hasProgression then
									for _, subList in TableUtils:OrderedPairs(spellList.levels) do
										if subList.linkedProgressions[tableUUID] then
											subList.linkedProgressions[tableUUID].delete = true
										end
									end
									linkButton.Label = "Link"
								else
									spellList.levels = spellList.levels or {}
									for level, spells in pairs(self.progressions[progressionName]) do
										spellList.levels[level] = spellList.levels[level] or {}
										spellList.levels[level].linkedProgressions = spellList.levels[level].linkedProgressions or {}
										spellList.levels[level].linkedProgressions[tableUUID] =
											TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.spellSubLists)
									end
									linkButton.Label = "Unlink"
								end
								hasProgression = not hasProgression
								self:buildSpellListDesigner(spellList)
							end
						end)

						local progTable = Styler:TwoColumnTable(levelView, progressionName)
						for level, spells in TableUtils:OrderedPairs(list, function(key)
							return tonumber(key)
						end) do
							local row = progTable:AddRow()
							row:AddCell():AddText(level)

							local spellCell = row:AddCell()
							for i, spellName in ipairs(spells) do
								---@type SpellData
								local spell = Ext.Stats.Get(spellName)

								local spellImage = spellCell:AddImageButton(spellName .. i, spell.Icon, { 48, 48 })
								spellImage.SameLine = (i - 1) % (math.floor(self.progressionBrowser.LastSize[1] / 58)) ~= 0
								spellImage.CanDrag = true
								spellImage.DragDropType = "SpellReorder"
								spellImage.UserData = {
									spellName = spellName
								} --[[@as SpellHandle]]

								for l = 1, 30 do
									if spellList.levels and spellList.levels[l] and self:CheckIfSpellIsInSpellListLevel(spellList.levels[l], spellName, l) then
										spellImage.Tint = { 1, 1, 1, 0.2 }
										break
									end
								end

								---@param spellImage ExtuiImageButton
								---@param preview ExtuiTreeParent
								spellImage.OnDragStart = function(spellImage, preview)
									if self.selectedSpells.context == "Browser" and #self.selectedSpells.spells > 0 then
										preview:AddText("Moving:")
										for _, spellName in pairs(self.selectedSpells.spells) do
											preview:AddText(spellName.spellName)
										end
									else
										preview:AddText("Moving " .. spellName)
									end
								end

								spellImage.OnClick = function()
									if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
										if self.selectedSpells.context ~= "Browser" then
											self.selectedSpells.context = "Browser"
											self.selectedSpells.spells = {}
											for _, handle in pairs(self.selectedSpells.handles) do
												if handle.UserData.subListName then
													handle:SetColor("Button", self.subListIndex[handle.UserData.subListName].colour)
												else
													handle:SetColor("Button", { 1, 1, 1, 0 })
												end
											end
											self.selectedSpells.handles = {}
										end
										table.insert(self.selectedSpells.spells, spellImage.UserData)
										table.insert(self.selectedSpells.handles, spellImage)
										spellImage:SetColor("Button", { 0, 1, 0, .8 })
									elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Alt" then
										if self.selectedSpells.context == "Browser" then
											local index = TableUtils:IndexOf(self.selectedSpells.spells, spellName)
											if index then
												table.remove(self.selectedSpells.spells, index)
												table.remove(self.selectedSpells.handles, index)

												spellImage:SetColor("Button", { 1, 1, 1, 0 })
											end
										end
									elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
										local window = Ext.IMGUI.NewWindow(spellName)
										window.Closeable = true
										window.AlwaysAutoResize = true

										window.OnClose = function()
											window:Destroy()
											window = nil
										end
										ResourceManager:RenderDisplayWindow(spellData, window)
									end
								end


								ResourceManager:RenderDisplayWindow(spell, spellImage:Tooltip())
							end
						end
					end
				end
			end
		end)
	end
	searchBox.OnActivate = searchBox.OnChange
end

---@param spellList SpellList
function SpellListDesigner:buildSpellBrowser(spellList)
	Helpers:KillChildren(self.spellBrowser)

	SpellBrowser:Render(self.spellBrowser,
		function(parent, results)
			Styler:MiddleAlignedColumnLayout(parent, function(ele)
				parent.Size = { 0, 0 }

				local copyAllButton = ele:AddButton("Copy All")

				copyAllButton.OnClick = function()
					for _, spellName in ipairs(results) do
						---@type SpellData
						local spell = Ext.Stats.Get(spellName)

						local level = (spell.Level ~= "" and spell.Level > 0) and spell.Level or 1
						spellList.levels[level] = spellList.levels[level] or {}
						local subLevelList = spellList.levels[level]

						if not self:CheckIfSpellIsInSpellListLevel(subLevelList, spellName, level) then
							subLevelList.selectedSpells = subLevelList.selectedSpells or
								TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.spellSubLists)

							local leveledSubList = subLevelList.selectedSpells
							leveledSubList.randomized = leveledSubList.randomized or {}

							table.insert(leveledSubList.randomized, spellName)
						end
					end

					self:buildSpellListDesigner(spellList)
				end
			end)
		end,
		function(pos)
			return pos % (math.floor(self.spellBrowser.LastSize[1] / 58)) ~= 0
		end,
		function()
			for l = 1, 30 do
				if spellList.levels and spellList.levels[l] and self:CheckIfSpellIsInSpellListLevel(spellList.levels[l], spellName, l) then
					return true
				end
			end
		end,
		function(spellImage, spellName)
			spellImage.CanDrag = true
			spellImage.DragDropType = "SpellReorder"
			spellImage.UserData = {
				spellName = spellName
			} --[[@as SpellHandle]]

			---@param preview ExtuiTreeParent
			spellImage.OnDragStart = function(_, preview)
				if self.selectedSpells.context == "Browser" and #self.selectedSpells.spells > 0 then
					preview:AddText("Moving:")
					for _, spellName in pairs(self.selectedSpells.spells) do
						preview:AddText(spellName.spellName)
					end
				else
					preview:AddText("Moving " .. spellName)
				end
			end
		end,
		function(spellImage, spellName)
			if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
				if self.selectedSpells.context ~= "Browser" then
					self.selectedSpells.context = "Browser"
					self.selectedSpells.spells = {}
					for _, handle in pairs(self.selectedSpells.handles) do
						if handle.UserData.subListName then
							handle:SetColor("Button", self.subListIndex[handle.UserData.subListName].colour)
						else
							handle:SetColor("Button", { 1, 1, 1, 0 })
						end
					end
					self.selectedSpells.handles = {}
				end
				table.insert(self.selectedSpells.spells, spellImage.UserData)
				table.insert(self.selectedSpells.handles, spellImage)
				spellImage:SetColor("Button", { 0, 1, 0, .8 })
			elseif Ext.ClientInput.GetInputManager().PressedModifiers == "Alt" then
				if self.selectedSpells.context == "Browser" then
					local index = TableUtils:IndexOf(self.selectedSpells.spells, spellName)
					if index then
						table.remove(self.selectedSpells.spells, index)
						table.remove(self.selectedSpells.handles, index)

						spellImage:SetColor("Button", { 1, 1, 1, 0 })
					end
				end
			end
		end)
end

---@param leveledSubList LeveledSubList
---@param spellName string
---@param level number
---@param ignoreProgressions boolean?
---@return boolean
function SpellListDesigner:CheckIfSpellIsInSpellListLevel(leveledSubList, spellName, level, ignoreProgressions)
	---@param value SpellSubLists
	---@return boolean?
	local predicate = function(value)
		for _, subList in pairs(value) do
			if TableUtils:IndexOf(subList, spellName) ~= nil then
				return true
			end
		end
	end

	if leveledSubList.selectedSpells and TableUtils:IndexOf({ leveledSubList.selectedSpells }, predicate) then
		return true
	elseif leveledSubList.linkedProgressions then
		if TableUtils:IndexOf(leveledSubList.linkedProgressions, predicate) then
			return true
		end

		if not ignoreProgressions then
			for progressionId, subLists in pairs(leveledSubList.linkedProgressions) do
				if TableUtils:IndexOf(self.progressions[self.progressionTranslation[progressionId]][level], spellName) then
					return true
				end
			end
		end
	end

	return false
end
