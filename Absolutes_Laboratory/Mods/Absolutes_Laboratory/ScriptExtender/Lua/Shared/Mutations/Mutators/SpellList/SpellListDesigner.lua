SpellListDesigner = {}

---@type ExtuiWindow?
SpellListDesigner.spellListDesignerWindow = nil

---@type ExtuiWindow?
SpellListDesigner.formWindow = nil

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

	local displayTable = Styler:TwoColumnTable(self.spellListDesignerWindow, "SpellListDesigner")
	local row = displayTable:AddRow()
	local lists = row:AddCell():AddChildWindow("lists")
	local designer = row:AddCell():AddChildWindow("designer")
	displayTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()

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

			self:buildSpellListDesigner(designer, spellList)
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
			self:buildSpellDesignerWindow(parent, activeSpellList and activeSpellList.UserData)
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
---@param spellList SpellList
function SpellListDesigner:buildSpellListDesigner(parent, spellList)
	Styler:CheapTextAlign(spellList.name, parent):Tooltip():AddText("\t " .. spellList.description).TextWrapPos = 800 * Styler:ScaleFactor()

	local criteriaSection = parent:AddCollapsingHeader("Entity Eligibility Criteria")

	local classCriteriaGroup = criteriaSection:AddGroup("classCriteria")
	local abilityCriteriaGroup = criteriaSection:AddGroup("abilityCriteria")

	local copyFromProgressionButton = parent:AddButton("Copy From A Progression")

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

				local spellImage = spellGroup:AddImageButton(spellName, spellData.Icon, {32, 32})
				local tooltip = spellImage:Tooltip()

				spellImage.OnHoverEnter = function ()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Shift" then
						ResourceManager:RenderDisplayWindow(spellData, tooltip)
					end
				end

				spellImage.OnHoverLeave = function ()
					Helpers:KillChildren(tooltip)
					tooltip:AddText(spellName)
				end
			end
		end
	end
end
