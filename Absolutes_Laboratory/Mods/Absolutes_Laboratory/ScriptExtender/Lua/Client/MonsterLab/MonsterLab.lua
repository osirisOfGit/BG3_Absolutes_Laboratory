Ext.Require("Client/MonsterLab/ExistingEncounters.lua")

MonsterLab = {
	config = ConfigurationStructure.config.monsterLab
}

local hasInitialized

if Ext.Mod.IsModLoaded("755a8a72-407f-4f0d-9a33-274ac0f0b53d") then
	Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Monster Lab",
		--- @param tabHeader ExtuiTabItem
		function(tabHeader)
			if not hasInitialized then
				MonsterLab:init(tabHeader)
				hasInitialized = true
			end
		end)
end

---@param parent ExtuiTreeParent
function MonsterLab:init(parent)
	self.popup = parent:AddPopup("")
	self.popup:SetColor("PopupBg", { 0, 0, 0, 1 })
	self.popup:SetColor("Border", { 1, 0, 0, 0.5 })
	self.popup.AutoClosePopups = true
	self.popup.UserData = "closeOnSubmit"

	local layoutTable = Styler:TwoColumnTable(parent, "MonsterLab"):AddRow()

	local encounterFolders = layoutTable:AddCell()

	local encounterDesigner = layoutTable:AddCell()

	self:buildFolderView(encounterFolders, encounterDesigner)
end

---@param parent ExtuiTreeParent
---@param designerSection ExtuiTreeParent
function MonsterLab:buildFolderView(parent, designerSection)
	Helpers:KillChildren(parent)

	for folderId, folder in TableUtils:OrderedPairs(self.config.folders, function(key, value)
		return value.name
	end) do
		local header = parent:AddCollapsingHeader(folder.name .. "##" .. folderId)
		header:SetColor("Header", { 1, 1, 1, 0 })
		header.UserData = folderId

		for encounterId, encounter in TableUtils:OrderedPairs(folder.encounters, function(key, value)
			return value.name
		end) do
			---@type ExtuiSelectable
			local encounterSelect = header:AddSelectable(encounter.name .. "##" .. encounterId)
			encounterSelect.OnClick = function()
				encounterSelect.Selected = false
				self:buildEncounterView(designerSection, encounter)
			end
		end

		---@type ExtuiSelectable
		local manageFolderButton = header:AddSelectable("Manage Folder")
		manageFolderButton:SetStyle("SelectableTextAlign", 0.5)

		manageFolderButton.OnClick = function()
			manageFolderButton.Selected = false

			Helpers:KillChildren(self.popup)
			self.popup:Open()
			FormBuilder:CreateForm(self.popup, function(formResults)
					folder.encounters[FormBuilder:generateGUID()] = {
						name = formResults.Name,
						description = formResults.Description,
						entities = {}
					}

					self:buildFolderView(parent, designerSection)
				end,
				{
					{
						label = "Name",
						type = "Text",
						errorMessageIfEmpty = "Name is required"
					},
					{
						label = "Description",
						type = "Multiline"
					}
				})
		end
	end

	parent:AddNewLine()

	---@type ExtuiSelectable
	local createFolderButton = parent:AddSelectable("Create Folder")
	createFolderButton:SetStyle("SelectableTextAlign", 0.5)

	createFolderButton.OnClick = function()
		createFolderButton.Selected = false

		Helpers:KillChildren(self.popup)
		self.popup:Open()
		FormBuilder:CreateForm(self.popup, function(formResults)
				self.config.folders[FormBuilder:generateGUID()] = {
					name = formResults.Name,
					description = formResults.Description,
					encounters = {}
				} --[[@as MonsterLabFolder]]

				self:buildFolderView(parent, designerSection)
			end,
			{
				{
					label = "Name",
					type = "Text",
					errorMessageIfEmpty = "Name is required"
				},
				{
					label = "Description",
					type = "Multiline"
				}
			})
	end
end

---@param parent ExtuiTreeParent
---@param encounter MonsterLabEncounter
function MonsterLab:buildEncounterView(parent, encounter)
	Helpers:KillChildren(parent)

	Styler:CheapTextAlign(encounter.name, parent)
	if encounter.description then
		Styler:CheapTextAlign(encounter.description, parent)
	end

	local layoutTable = Styler:TwoColumnTable(parent, "layout"):AddRow()

	local entitySidebar = layoutTable:AddCell()
	local entityTable = entitySidebar:AddTable("entities", 1)
	entityTable.BordersInnerH = true

	for id, entity in TableUtils:OrderedPairs(encounter.entities, function(key, value)
		return value.displayName
	end) do
		local cell = entityTable:AddRow():AddCell()
		---@type CharacterTemplate
		local characterTemplate = Ext.ClientTemplate.GetTemplate(entity.template)
		local icon = cell:AddImage(characterTemplate.Icon, Styler:ScaleFactor({ 32, 32 }))
		if icon.ImageData.Icon == "" then
			icon:Destroy()
			icon = cell:AddImage("Item_Unknown", Styler:ScaleFactor({ 32, 32 }))
		end

		local name = Styler:HyperlinkText(cell, entity.displayName, function(parent)
			CharacterWindow:BuildWindow(parent, entity.template)
		end)
		Styler:Color(name, "PlainLink")
		name.SameLine = true

		if entity.title and entity.title ~= "" then
			local title = cell:AddText(("- (%s)"):format(entity.title))
			title.SameLine = true
		end
	end

	---@type ExtuiSelectable
	local createEntityButton = entitySidebar:AddSelectable("Create New Entity")
	createEntityButton:SetStyle("SelectableTextAlign", 0.5)
	createEntityButton.OnClick = function()
		createEntityButton.Selected = false
		self:buildCreateEntityForm(parent, encounter)
	end
end

---@param parent ExtuiTreeParent
---@param encounter MonsterLabEncounter
function MonsterLab:buildCreateEntityForm(parent, encounter)
	TemplateSelector:init()

	Helpers:KillChildren(self.popup)
	self.popup:Open()

	Styler:CheapTextAlign("Choose A Character Template", self.popup, "Big")
	self.popup:AddText("Chosen Template: ")
	local chosenTemplateGroup = self.popup:AddGroup("template")
	chosenTemplateGroup.SameLine = true
	local chosenTemplateId

	local submit = self.popup:AddButton("Submit")

	local searchBox = self.popup:AddInputText("")
	searchBox.Hint = "Search Template Name or UUID"

	local templateSources = {}

	self.popup:AddText("From Mod: ")
	local modCombo = self.popup:AddCombo("")
	modCombo.SameLine = true
	modCombo.WidthFitPreview = true

	local templatesWindow = self.popup:AddChildWindow("Templates")
	templatesWindow.Size = Styler:ScaleFactor({ 0, 600 })
	local templatesTable = templatesWindow:AddTable("Templates", 3)
	local function buildResults()
		Helpers:KillChildren(templatesTable)
		local row = templatesTable:AddRow()

		local counter = 0
		local buildSources = not next(templateSources)

		---@type ExtuiSelectable?
		local lastSelect
		for _, templateId in ipairs(TemplateSelector.templates) do
			---@type CharacterTemplate
			local characterTemplate = Ext.ClientTemplate.GetTemplate(templateId)
			local source = characterTemplate.FileName:gsub("^.*[\\/]Mods[\\/]", ""):gsub("^.*[\\/]Public[\\/]", ""):match("([^/\\]+)")

			if buildSources then
				if not TableUtils:IndexOf(templateSources, source) then
					table.insert(templateSources, source)
				end
			end

			if (modCombo.SelectedIndex <= 0 or source == modCombo.Options[modCombo.SelectedIndex + 1])
				and (searchBox.Text == ""
					or TemplateSelector.translationMap[templateId]:upper():find(searchBox.Text:upper())
					or templateId:find(searchBox.Text))
			then
				counter = counter + 1

				local cell = row:AddCell()
				local icon = cell:AddImage(characterTemplate.Icon, Styler:ScaleFactor({ 32, 32 }))
				if icon.ImageData.Icon == "" then
					icon:Destroy()
					icon = cell:AddImage("Item_Unknown", Styler:ScaleFactor({ 32, 32 }))
				end

				---@type ExtuiSelectable
				local templateSelect = cell:AddSelectable(characterTemplate.Name)
				templateSelect.SameLine = true

				local openWindow = Styler:HyperlinkRenderable(templateSelect,
					templateId,
					"Shift",
					true,
					nil,
					function(parent)
						CharacterWindow:BuildWindow(parent, templateId)
					end)

				templateSelect.OnClick = function()
					if not openWindow() then
						if lastSelect and lastSelect.Handle ~= templateSelect.Handle then
							lastSelect.Selected = false
						end
						lastSelect = templateSelect

						Helpers:KillChildren(chosenTemplateGroup)
						chosenTemplateGroup:AddImage(icon.ImageData.Icon, Styler:ScaleFactor({ 32, 32 }))

						Styler:Color(Styler:HyperlinkText(chosenTemplateGroup, templateSelect.Label, function(parent)
							CharacterWindow:BuildWindow(parent, templateId)
						end), "PlainLink").SameLine = true

						chosenTemplateId = templateId
					end
				end
			end
		end

		if buildSources then
			table.sort(templateSources)
			table.insert(templateSources, 1, "All")
			modCombo.Options = templateSources
			modCombo.SelectedIndex = 0
		end
	end

	buildResults()
	local timer
	searchBox.OnChange = function()
		if timer then
			Ext.Timer.Cancel(timer)
		end
		timer = Ext.Timer.WaitFor(250, buildResults)
	end
	modCombo.OnChange = buildResults

	submit.OnClick = function()
		if chosenTemplateId then
			self.popup:Open()
			FormBuilder:CreateForm(self.popup, function(formResults)
					encounter.entities[FormBuilder:generateGUID()] = {
						displayName = formResults.displayName,
						title = formResults.Title,
						template = chosenTemplateId,
						coordinates = { 0, 0, 0 }
					} --[[@as MonsterLabEntity]]

					self:buildEncounterView(parent, encounter)
				end,
				{
					{
						label = "Name",
						defaultValue = TemplateSelector.translationMap[chosenTemplateId],
						propertyField = "displayName",
						type = "Text",
						errorMessageIfEmpty = "A name is required"
					},
					{
						label = "Title",
						type = "Text"
					},
					{
						label = "Template",
						type = "Text",
						disabled = true,
						defaultValue = TemplateSelector.translationMap[chosenTemplateId]
					}
				})
		end
	end
end
