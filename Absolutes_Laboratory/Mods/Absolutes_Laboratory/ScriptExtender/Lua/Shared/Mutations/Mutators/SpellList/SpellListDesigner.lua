SpellListDesigner = {}

---@type ExtuiWindow?
SpellListDesigner.self.spellListDesignerWindow = nil

---@type ExtuiWindow?
SpellListDesigner.formWindow = nil

function SpellListDesigner:buildSpellDesignerWindow(parent, activeList)
	if not self.spellListDesignerWindow then
		self.spellListDesignerWindow = Ext.IMGUI.NewWindow("Spell List Designer")
		self.spellListDesignerWindow.Closeable = true
		self.spellListDesignerWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())

		self.formWindow = Ext.IMGUI.NewWindow("Spell List Form")
		self.formWindow.Closeable = true
		self.formWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())
	else
		self.spellListDesignerWindow.Open = true
		self.spellListDesignerWindow:SetFocus()
	end

	local spellLists = ConfigurationStructure.config.mutations.spellLists

	local displayTable = Styler:TwoColumnTable(parent, "SpellListDesigner")
	local row = displayTable:AddRow()
	local lists = row:AddCell():AddChildWindow("lists")
	local designer = row:AddCell():AddChildWindow("designer")

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

		if guid == activeSpellList then
			spellListSelect:OnClick()
		end
	end

	---@type ExtuiSelectable
	local createListButton = lists:AddSelectable("Create a List")

	createListButton.OnClick = function()
		createListButton.Selected = false

		Helpers:KillChildren(self.formWindow)
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

function SpellListDesigner:buildSpellListDesigner(parent, spellList)

end
