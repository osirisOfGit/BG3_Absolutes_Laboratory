Ext.Require("Client/MonsterLab/EncounterDesigner.lua")
-- Ext.Require("Client/MonsterLab/ExistingEncounters.lua")

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
						entities = {},
						gameLevel = EntityRecorder.Levels[1],
						baseCoords = { 0, 0, 0 }
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

	Styler:CheapTextAlign(encounter.name, parent, "Big")
	if encounter.description then
		Styler:CheapTextAlign(encounter.description, parent)
	end

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		ele:AddButton("Launch Encounter Designer").OnClick = function()
			EncounterDesigner:buildDesigner(encounter)
		end
	end)

	local layoutTable = Styler:TwoColumnTable(parent, "layout")
	layoutTable.Resizable = false
	local layoutRow = layoutTable:AddRow()

	local entitySidebar = layoutRow:AddCell()
	local designerSection = layoutRow:AddCell()


	for id, entity in TableUtils:OrderedPairs(encounter.entities, function(key, value)
		return value.displayName
	end) do
		local entityGroup = entitySidebar:AddGroup(id)
		local deleteButton = Styler:ImageButton(entityGroup:AddImageButton("delete" .. id, "ico_red_x", Styler:ScaleFactor({ 16, 16 })))
		deleteButton.OnClick = function()
			encounter.entities[id].delete = true
			self:buildEncounterView(parent, encounter)
		end

		-- local settingsButton = Styler:ImageButton(entityGroup:AddImageButton("settings", "ico_edit_d", Styler:ScaleFactor({ 16, 16 })))
		-- settingsButton.SameLine = true
		-- settingsButton.OnClick = function()
		-- 	entity.mutators = entity.mutators or {}
		-- 	MutationDesigner:RenderMutatorsSidebarStyle(designerSection, entity.mutators)
		-- end

		---@type CharacterTemplate
		local characterTemplate = Ext.ClientTemplate.GetTemplate(entity.template)
		local icon = entityGroup:AddImage(characterTemplate.Icon, Styler:ScaleFactor({ 48, 48 }))
		if icon.ImageData.Icon == "" then
			icon:Destroy()
			icon = entityGroup:AddImage("Item_Unknown", Styler:ScaleFactor({ 48, 48 }))
		end
		icon.SameLine = true

		local nameGroup = entityGroup:AddGroup("entity")
		nameGroup.SameLine = true

		---@type ExtuiTextLink
		local name = Styler:Color(nameGroup:AddTextLink(entity.displayName), "PlainLink")
		local openPopupFunc = Styler:HyperlinkRenderable(name, entity.template, "Shift", true, nil, function(parent)
			CharacterWindow:BuildWindow(parent, entity.template)
		end)

		name.OnClick = function()
			if not openPopupFunc() then
				Helpers:KillChildren(designerSection)
				Styler:MiddleAlignedColumnLayout(designerSection, function(ele)
					Styler:MiddleAlignedColumnLayout(ele, function(ele)
						---@type CharacterTemplate
						local characterTemplate = Ext.ClientTemplate.GetTemplate(entity.template)
						local icon = ele:AddImage(characterTemplate.Icon, Styler:ScaleFactor({ 48, 48 }))
						if icon.ImageData.Icon == "" then
							icon:Destroy()
							icon = ele:AddImage("Item_Unknown", Styler:ScaleFactor({ 48, 48 }))
						end
						icon.SameLine = true
					end)

					ele:AddText(entity.displayName).Font = "Big"
				end)
				MutationDesigner:RenderMutatorsSidebarStyle(designerSection:AddGroup("DesignIt"), entity.mutators)
			end
		end

		if entity.title and entity.title ~= "" then
			nameGroup:AddText(entity.title)
		end
	end

	---@type ExtuiSelectable
	local createEntityButton = entitySidebar:AddSelectable("Create New Entity")
	createEntityButton:SetStyle("SelectableTextAlign", 0.5)
	createEntityButton.OnClick = function()
		createEntityButton.Selected = false

		self:buildCreateEntityForm(designerSection, encounter, function()
			self:buildEncounterView(parent, encounter)
		end)
	end
end

---@param parent ExtuiTreeParent
---@param encounter MonsterLabEncounter
---@param completedCallback fun()
function MonsterLab:buildCreateEntityForm(parent, encounter, completedCallback)
	TemplateSelector:init()

	Helpers:KillChildren(parent)

	Styler:CheapTextAlign("Choose A Character Template", parent, "Big")
	parent:AddText("Chosen Template: ")
	local chosenTemplateGroup = parent:AddGroup("template")
	chosenTemplateGroup.SameLine = true
	local chosenTemplateId

	local submit = parent:AddButton("Submit")

	local searchBox = parent:AddInputText("")
	searchBox.Hint = "Search Template Name or UUID"

	local templateSources = {}

	parent:AddText("From Mod: ")
	local modCombo = parent:AddCombo("")
	modCombo.SameLine = true
	modCombo.WidthFitPreview = true

	local templatesWindow = parent:AddChildWindow("Templates")
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
			FormBuilder:CreateForm(parent, function(formResults)
					local entity = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.entity)
					entity.displayName = formResults.displayName
					entity.title = formResults.Title
					entity.template = chosenTemplateId
					encounter.entities[FormBuilder:generateGUID()] = entity

					completedCallback()
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
