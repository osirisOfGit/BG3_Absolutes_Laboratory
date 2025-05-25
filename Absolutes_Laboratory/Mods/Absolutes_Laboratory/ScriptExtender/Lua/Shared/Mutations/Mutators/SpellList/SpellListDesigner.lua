SpellListDesigner = {}

---@class SpellSubListIndex
---@field name string
---@field colour number[]

---@type {[string] : SpellSubListIndex}
SpellListDesigner.subListIndex = {
	["guaranteed"] = { name = "Guaranteed", colour = {} },
	["randomized"] = { name = "Randomized", colour = {} },
	["startOfCombatOnly"] = { name = "Cast On Combat Start", colour = {} },
	["onLoadOnly"] = { name = "Cast On Level Load", colour = {} }
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
		colorSettings:AddText("Click A Color To Change It"):SetStyle("Alpha", 0.6)

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
	Styler:CheapTextAlign(spellList.name, self.designer):Tooltip():AddText("\t " .. spellList.description).TextWrapPos = 800 * Styler:ScaleFactor()

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

	for i = 1, 30 do
		local listGroup = leveledListGroup:AddGroup("list" .. i)
		listGroup:SetColor("Border", { 1, 0, 0, 1 })

		listGroup:AddText(tostring(i) .. (i < 10 and "  " or ""))

		local spellGroup = listGroup:AddGroup("spells")
		spellGroup.SameLine = true
		spellGroup.UserData = i

		local counter = 0
		for subListName, subList in TableUtils:OrderedPairs(spellList.subLists, function(key)
			return self.subListIndex[key].name
		end) do
			---@cast subList SpellName[][]
			if subList[i] then
				for sI, spellName in TableUtils:OrderedPairs(subList[i], function(key)
					return subList[i][key]
				end) do
					---@type SpellData
					local spellData = Ext.Stats.Get(spellName)

					local spellImage = spellGroup:AddImageButton(spellName .. "##" .. i, spellData.Icon, { 48, 48 })
					spellImage.SameLine = (counter) % math.floor((self.designer.LastSize[1]) / 60) ~= 0
					spellImage:SetColor("Button", self.subListIndex[subListName].colour)

					spellImage.OnClick = function()
						Helpers:KillChildren(popup)
						popup:Open()
						for subListCategory, index in TableUtils:OrderedPairs(self.subListIndex) do
							if subListCategory ~= subListName then
								popup:AddSelectable("Set As " .. index.name .. "##" .. i).OnClick = function()
									spellList.subLists[subListCategory] = spellList.subLists[subListCategory] or {}
									spellList.subLists[subListCategory][i] = spellList.subLists[subListCategory][i] or {}
									table.insert(spellList.subLists[subListCategory][i], spellName)
									subList[i][sI] = nil

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
						end
					end

					spellImage.OnHoverLeave = function()
						Helpers:KillChildren(tooltip)
						tooltip:AddText("\t " .. spellName)
						tooltip:AddText("\t " .. self.subListIndex[subListName].name)
					end

					counter = counter + 1
				end
			end
		end
		if #spellGroup.Children == 0 then
			spellGroup:AddDummy(56, 56)
		end
		listGroup:AddSeparatorText(""):SetStyle("SeparatorTextBorderSize", 10)
	end
end

---@type {[string]: SpellName[][]}
local progressions = {}

local progressionNameToTable = {}

---@param spellList SpellList
function SpellListDesigner:buildProgressionBrowser(spellList)
	if not next(progressions) then
		for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")
			if progression.AddSpells and next(Ext.Types.Serialize(progression.AddSpells))
				or progression.SelectSpells and next(Ext.Types.Serialize(progression.SelectSpells))
			then
				if not progressionNameToTable[progression.Name] then
					progressionNameToTable[progression.Name] = progression.TableUUID
				end

				progressions[progression.Name] = progressions[progression.Name] or {}
				progressions[progression.Name][progression.Level] = progressions[progression.Name][progression.Level] or {}

				for _, addSpellMeta in TableUtils:CombinedPairs(progression.AddSpells, progression.SelectSpells) do
					---@type ResourceSpellList
					local progSpellList = Ext.StaticData.Get(addSpellMeta.SpellUUID, "SpellList")

					for _, spellName in pairs(progSpellList.Spells) do
						if not TableUtils:IndexOf(progressions[progression.Name], function(value)
								return TableUtils:IndexOf(value, spellName) ~= nil
							end)
						then
							table.insert(progressions[progression.Name][progression.Level], spellName)
						end
					end
				end
				if progressions[progression.Name][progression.Level] and #progressions[progression.Name][progression.Level] == 0 then
					progressions[progression.Name][progression.Level] = nil
				end
			end
		end
	end

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

			for progressionName, list in TableUtils:OrderedPairs(progressions) do
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
										if not TableUtils:IndexOf(spellList.subLists.randomized[level], spell)
											and not TableUtils:IndexOf(spellList.subLists.guaranteed[level], spell)
											and not TableUtils:IndexOf(spellList.subLists.startOfCombatOnly[level], spell)
										then
											table.insert(spellList.subLists.randomized[level], spell)
										end
									end
								end

								self:buildSpellDesignerWindow(activeSpellList and activeSpellList.UserData)
							end

							local linkButton = ele:AddButton("Link")
							linkButton.SameLine = true
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
