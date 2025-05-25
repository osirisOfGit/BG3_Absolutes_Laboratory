SpellListDesigner = {}

---@type ExtuiWindow?
SpellListDesigner.spellListDesignerWindow = nil

---@type ExtuiWindow?
SpellListDesigner.formWindow = nil

---@type ExtuiTable
SpellListDesigner.displayTable = nil

function SpellListDesigner:buildSpellDesignerWindow(activeList)
	if not self.spellListDesignerWindow then
		self.spellListDesignerWindow = Ext.IMGUI.NewWindow("Spell List Designer")
		self.spellListDesignerWindow.Closeable = true
		self.spellListDesignerWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())

		self.formWindow = Ext.IMGUI.NewWindow("Spell List Form")
		self.formWindow.Closeable = true
		self.formWindow:SetStyle("WindowMinSize", 150 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())
		self.formWindow.Open = false
	else
		Helpers:KillChildren(self.spellListDesignerWindow)
		self.spellListDesignerWindow.Open = true
		self.spellListDesignerWindow:SetFocus()
	end

	local spellLists = ConfigurationStructure.config.mutations.spellLists

	SpellListDesigner.displayTable = self.spellListDesignerWindow:AddTable("SpellListDesigner", 3)
	self.displayTable.NoSavedSettings = true
	self.displayTable:AddColumn("SpellLists", "WidthFixed")
	self.displayTable:AddColumn("", "WidthStretch")
	self.displayTable:AddColumn("ProgressionBrowser", "WidthFixed")
	self.displayTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
	self.displayTable.ColumnDefs[3].Width = 0
	self.displayTable.Resizable = true

	local row = self.displayTable:AddRow()
	local lists = row:AddCell():AddChildWindow("lists")
	local designer = row:AddCell():AddChildWindow("designer")
	local progressionBrowser = row:AddCell():AddChildWindow("progressionBrowser")
	progressionBrowser.Visible = false

	---@type ExtuiSelectable?
	local activeSpellList

	lists:AddSeparatorText("Your SpellLists"):SetStyle("SeparatorTextAlign", 0.5)

	for guid, spellList in TableUtils:OrderedPairs(spellLists, function(key)
		return spellLists[key].name
	end) do
		---@type ExtuiSelectable
		local spellListSelect = lists:AddSelectable(spellList.name)
		spellListSelect.UserData = guid

		spellListSelect.OnClick = function()
			if activeSpellList then
				activeSpellList.Selected = false
				Helpers:KillChildren(designer)
			end

			activeSpellList = spellListSelect

			self:buildSpellListDesigner(designer, progressionBrowser, spellList)
		end

		if guid == activeList then
			spellListSelect:OnClick()
		end
	end

	---@type ExtuiSelectable
	local createListButton = lists:AddSelectable("Create a List")

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

---@param parent ExtuiTreeParent
---@param progressionBrowserParent ExtuiTreeParent
---@param spellList SpellList
function SpellListDesigner:buildSpellListDesigner(parent, progressionBrowserParent, spellList)
	Styler:CheapTextAlign(spellList.name, parent):Tooltip():AddText("\t " .. spellList.description).TextWrapPos = 800 * Styler:ScaleFactor()

	local criteriaSection = parent:AddCollapsingHeader("Entity Eligibility Criteria")

	local classCriteriaGroup = criteriaSection:AddGroup("classCriteria")
	local abilityCriteriaGroup = criteriaSection:AddGroup("abilityCriteria")

	local copyFromProgressionButton = parent:AddButton("Copy From A Progression")
	copyFromProgressionButton.OnClick = function()
		progressionBrowserParent.Visible = true
		self.displayTable.ColumnDefs[3].Width = 800 * Styler:ScaleFactor()
		self:buildProgressionBrowser(progressionBrowserParent, spellList)
	end

	local leveledListGroup = parent:AddGroup("leveledLists")

	for i = 1, 30 do
		local listGroup = leveledListGroup:AddGroup("list" .. i)
		listGroup:SetColor("Border", { 1, 0, 0, 1 })

		listGroup:AddText(tostring(i))

		local spellGroup = listGroup:AddGroup("spells")
		spellGroup.UserData = i

		if spellList.guaranteed then
			for _, spellName in TableUtils:OrderedPairs(spellList.guaranteed[i] or {}) do
				---@type SpellData
				local spellData = Ext.Stats.Get(spellName)

				local spellImage = spellGroup:AddImageButton(spellName, spellData.Icon, { 32, 32 })
				local tooltip = spellImage:Tooltip()

				spellImage.OnHoverEnter = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						ResourceManager:RenderDisplayWindow(spellData, tooltip)
					end
				end

				spellImage.OnHoverLeave = function()
					Helpers:KillChildren(tooltip)
					tooltip:AddText(spellName)
				end
			end
		end
	end
end

---@type {[string]: SpellName[][]}
local progressions = {}

---@param parent ExtuiChildWindow
---@param spellList SpellList
function SpellListDesigner:buildProgressionBrowser(parent, spellList)
	if not next(progressions) then
		for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")
			if progression.AddSpells and next(Ext.Types.Serialize(progression.AddSpells))
				or progression.SelectSpells and next(Ext.Types.Serialize(progression.SelectSpells))
			then
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
		_D(TableUtils:CountElements(progressions))
	end

	Helpers:KillChildren(parent)

	local searchBox = parent:AddInputText("")

	local resultsGroup = parent:AddGroup("Results")

	local levelView = parent:AddGroup("Levels")

	local timer
	searchBox.OnChange = function()
		if timer then
			Ext.Timer.Cancel(timer)
		end
		timer = Ext.Timer.WaitFor(500, function()
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
								spellImage.SameLine = (i - 1) % (math.floor(parent.LastSize[1] / 56)) ~= 0
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
