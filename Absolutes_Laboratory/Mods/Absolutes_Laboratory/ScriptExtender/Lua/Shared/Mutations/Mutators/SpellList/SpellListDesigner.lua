SpellListDesigner = {}

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
	["guaranteed"] = { name = "Guaranteed", description = "Will always be assigned to an enemy that is assigned level or higher", colour = {} },
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
		self.spellListDesignerWindow = Ext.IMGUI.NewWindow("Spell List Designer")
		self.spellListDesignerWindow.Closeable = true
		self.spellListDesignerWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())

		self.formWindow = Ext.IMGUI.NewWindow("Spell List Form")
		self.formWindow.Closeable = true
		self.formWindow:SetStyle("WindowMinSize", 150 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())
		self.formWindow.Open = false

		SpellListDesigner.displayTable = self.spellListDesignerWindow:AddTable("SpellListDesigner", 3)
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

		SpellListDesigner.progressionBrowser = row:AddCell():AddChildWindow("progressionBrowser")
		self.progressionBrowser.NoSavedSettings = true
		self.progressionBrowser.Visible = false
		self.progressionBrowser.ChildAlwaysAutoResize = true

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

	self.lists:AddSeparatorText("Your SpellLists"):SetStyle("SeparatorTextAlign", 0.5)

	for guid, spellList in TableUtils:OrderedPairs(spellLists, function(key)
		return spellLists[key].name
	end) do
		---@type ExtuiSelectable
		local spellListSelect = self.lists:AddSelectable(spellList.name)
		spellListSelect.UserData = guid

		spellListSelect.OnClick = function()
			if activeSpellList then
				activeSpellList.Selected = false
				Helpers:KillChildren(self.designer)
			end
			self.designer.Visible = true

			activeSpellList = spellListSelect

			if spellList.progressions and next(spellList.progressions) then
				self:buildProgressionIndex()
			end

			self:buildSpellListDesigner(spellList)
		end

		if guid == activeList then
			spellListSelect:OnClick()
		end
	end

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
	local headerTitle = Styler:CheapTextAlign(spellList.name, self.designer)
	headerTitle.Font = "Big"
	headerTitle:Tooltip():AddText("\t " .. spellList.description).TextWrapPos = 800 * Styler:ScaleFactor()

	local criteriaSection = self.designer:AddCollapsingHeader("Entity Eligibility Criteria")

	local classCriteriaGroup = criteriaSection:AddGroup("classCriteria")
	local abilityCriteriaGroup = criteriaSection:AddGroup("abilityCriteria")

	local progressionBrowserButton = self.designer:AddButton("Open Progression Browser")
	progressionBrowserButton.OnClick = function()
		self.displayTable.ColumnDefs[3].Width = 400 * Styler:ScaleFactor()
		self.progressionBrowser.Visible = true
		self:buildProgressionBrowser(spellList)
		Ext.Timer.WaitFor(10, function()
			Helpers:KillChildren(self.designer)
			self:buildSpellListDesigner(spellList)
		end)
	end

	if self.designer.LastSize[1] == 0 then
		Ext.Timer.WaitFor(10, function()
			Helpers:KillChildren(self.designer)
			self:buildSpellListDesigner(spellList)
		end)
		return
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
		local counter = 0
		if progressionTableId and not subLists.randomized then
			subLists.randomized = {}
		end
		for subListName, subList in TableUtils:OrderedPairs(subLists._real, function(key)
			return self.subListIndex[key].name
		end) do
			if subListName == "randomized" and progressionTableId and self.progressions[self.progressionTranslation[progressionTableId]][level] then
				-- So additions to linked progressions don't get stored to the config
				subList = { [level] = {} }

				for _, spellName in pairs(self.progressions[self.progressionTranslation[progressionTableId]][level]) do
					if not self:CheckIfSpellIsInSpellListLevel(spellList, spellName, level) then
						if not TableUtils:IndexOf(spellCacheForProgressions[level], spellName) then
							table.insert(subList[level], spellName)
							spellCacheForProgressions[level] = spellCacheForProgressions[level] or {}
							table.insert(spellCacheForProgressions[level], spellName)
						end
					end
				end
			end

			---@cast subList SpellName[][]
			if subList[level] then
				for sI, spellName in TableUtils:OrderedPairs(subList[level], function(key)
					return subList[level][key]
				end) do
					---@type SpellData
					local spellData = Ext.Stats.Get(spellName)

					local spellImage = parentGroup:AddImageButton(spellName .. "##" .. level, spellData.Icon, { 48, 48 })
					spellImage.SameLine = (counter) % math.floor((self.designer.LastSize[1]) / 60) ~= 0
					spellImage:SetColor("Button", self.subListIndex[subListName].colour)

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
						else
							Helpers:KillChildren(popup)
							popup:Open()
							for subListCategory, index in TableUtils:OrderedPairs(self.subListIndex) do
								if subListCategory ~= subListName and (subListCategory ~= "blackListed" or progressionTableId) then
									popup:AddSelectable("Set As " .. index.name .. "##" .. level).OnClick = function()
										if subListCategory ~= "randomized" or not progressionTableId then
											subLists[subListCategory] = subLists[subListCategory] or {}
											subLists[subListCategory][level] = subLists[subListCategory][level] or {}
											table.insert(subLists[subListCategory][level], spellName)
										end
										if subList[level] then
											subList[level][sI] = nil
										end

										self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
									end
								end
							end

							if not progressionTableId then
								popup:AddSelectable("Remove").OnClick = function()
									subLists[subListName][level][sI] = nil
									self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
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
							tooltip:AddText("\t Linked from Progression: " .. self.progressionTranslation[progressionTableId])
						end
					end

					counter = counter + 1
				end
			end
		end
	end

	for i = 1, 30 do
		local listGroup = leveledListGroup:AddGroup("list" .. i)
		listGroup:SetColor("Border", { 1, 0, 0, 1 })

		listGroup:AddText(tostring(i) .. (i < 10 and "  " or ""))

		local spellGroup = listGroup:AddGroup("spells")
		spellGroup.SameLine = true
		spellGroup.UserData = i

		buildSpellListFromSubList(spellGroup, spellList.subLists, i)

		if spellList.progressions then
			for progressionTableId, subLists in TableUtils:OrderedPairs(spellList.progressions) do
				buildSpellListFromSubList(spellGroup, subLists, i, progressionTableId)
			end
		end

		if #spellGroup.Children == 0 then
			spellGroup:AddDummy(56, 56)
		end
		listGroup:AddSeparatorText(""):SetStyle("SeparatorTextBorderSize", 100)
	end
end

---@param spellList SpellList
function SpellListDesigner:buildProgressionBrowser(spellList)
	self:buildProgressionIndex()
	Helpers:KillChildren(self.progressionBrowser)

	local searchBox = self.progressionBrowser:AddInputText("")

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
									if not spellList.subLists.randomized[level] then
										spellList.subLists.randomized[level] = {}
									end
									for _, spell in pairs(spells) do
										if not self:CheckIfSpellIsInSpellListLevel(spellList, spell, level) then
											table.insert(spellList.subLists.randomized[level], spell)
										end
									end
								end

								self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
							end

							local tableUUID = self.progressionTranslation[progressionName]
							local hasProgression = (spellList.progressions and spellList.progressions[tableUUID]) ~= nil
							local linkButton = ele:AddButton(hasProgression and "Unlink" or "Link")
							linkButton.SameLine = true
							linkButton.OnClick = function()
								if hasProgression then
									spellList.progressions[tableUUID].delete = true
									linkButton.Label = "Link"
								else
									linkButton.Label = "Unlink"
									spellList.progressions = spellList.progressions or {}
									spellList.progressions[tableUUID] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.leveledSpellList.subLists)
								end
								hasProgression = not hasProgression
								self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
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

								local spellImage = spellCell:AddImage(spell.Icon, { 48, 48 })
								spellImage.SameLine = (i - 1) % (math.floor(self.progressionBrowser.LastSize[1] / 44)) ~= 0
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
---@param spellName string
---@param level number
---@return boolean
function SpellListDesigner:CheckIfSpellIsInSpellListLevel(spellList, spellName, level)
	local predicate = function(value)
		for _, subList in pairs(value) do
			if subList[level] and TableUtils:IndexOf(subList[level], spellName) ~= nil then
				return true
			end
		end
	end

	if TableUtils:IndexOf(spellList.subLists, predicate) then
		return true
	elseif spellList.progressions then
		if TableUtils:IndexOf(spellList.progressions, predicate) then
			return true
		end
	end

	return false
end
