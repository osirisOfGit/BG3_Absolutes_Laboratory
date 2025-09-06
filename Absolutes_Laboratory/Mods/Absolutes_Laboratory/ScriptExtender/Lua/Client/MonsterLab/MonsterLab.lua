Ext.Require("Client/MonsterLab/EncounterDesigner.lua")
-- Ext.Require("Client/MonsterLab/ExistingEncounters.lua")

MonsterLab = {
	config = ConfigurationStructure.config.monsterLab,
	activeRuleset = "Base"
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

	---@type fun()
	local buildEncounter

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		ele:AddButton("Launch Encounter Designer").OnClick = function()
			EncounterDesigner:buildDesigner(encounter)
		end
	end)

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		self:ManageRulesets(ele:AddGroup("Rulesets"), function()
			buildEncounter()
		end)
	end)

	local encounterGroup = parent:AddGroup("Encounter")

	buildEncounter = function()
		Helpers:KillChildren(encounterGroup)
		local layoutTable = Styler:TwoColumnTable(encounterGroup, "layout")
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
				self:buildEncounterView(encounterGroup, encounter)
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
				self:buildEncounterView(encounterGroup, encounter)
			end)
		end
	end
	buildEncounter()
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

---@param parent ExtuiTreeParent
---@param rulesetSelectCallback fun()
function MonsterLab:ManageRulesets(parent, rulesetSelectCallback)
	Helpers:KillChildren(parent)
	if not self.config.rulesets["Base"] then
		self.config.rulesets["Base"] = { negate = true, name = "Base", description = "Base Ruleset that will be activated if no other rulesets are eligible. Can't be modified.", activeModifiers = {} }
	end

	parent:AddSeparatorText("Rulesets ( ? )"):Tooltip():AddText([[
	These rulesets can be used to customize encounters without having to replicate them - left-click the button to customize the encounter according to that ruleset's criteria,
right-click to modify or delete that ruleset. The Base ruleset can't be modified or deleted - this is the default if there are no other eligible rulesets.
	]])

	---@type ExtuiButton
	local lastActiveButton

	local createdOne = false
	for rulesetId, ruleset in TableUtils:OrderedPairs(self.config.rulesets) do
		local rulesetButton = parent:AddButton(ruleset.name)
		rulesetButton.SameLine = createdOne
		createdOne = true

		rulesetButton.IDContext = rulesetId
		rulesetButton:Tooltip():AddText("\t" .. ruleset.description)
		if rulesetId == self.activeRuleset then
			Styler:Color(rulesetButton, "ActiveButton")
			lastActiveButton = rulesetButton
		else
			Styler:Color(rulesetButton, "DisabledButton")
		end

		rulesetButton.OnClick = function()
			if rulesetButton.Handle ~= lastActiveButton.Handle then
				Styler:Color(lastActiveButton, "DisabledButton")
				Styler:Color(rulesetButton, "ActiveButton")

				lastActiveButton = rulesetButton

				rulesetSelectCallback()
			end
		end

		rulesetButton.OnRightClick = function()
			if rulesetId == "Base" then
				return
			end

			Helpers:KillChildren(self.popup)
			self.popup:Open()

			---@type ExtuiMenu
			local editRulesetMetaMenu = self.popup:AddMenu("Edit Ruleset Name/Description")
			FormBuilder:CreateForm(editRulesetMetaMenu, function(formResults)
				ruleset.name = formResults.Name
				ruleset.description = formResults.Description
				self:ManageRulesets(parent, rulesetSelectCallback)
			end, {
				{
					label = "Name",
					type = "Text",
					defaultValue = ruleset.name,
					errorMessageIfEmpty = "A name is required"
				},
				{
					label = "Description",
					type = "Multiline",
					defaultValue = ruleset.description
				}
			})

			---@type ExtuiMenu
			local customizeModifiersMenu = self.popup:AddMenu("Customize Ruleset Modifiers")
			customizeModifiersMenu.IDContext = rulesetId

			for modifier, modifierId in TableUtils:OrderedPairs(Lab_RulesetModifiers) do
				---@type ResourceRulesetModifier
				local modifierResource = Ext.StaticData.Get(modifierId, "RulesetModifier")

				local enabledCheckbox = customizeModifiersMenu:AddCheckbox("", ruleset.activeModifiers[modifierId] ~= nil)
				local sep = customizeModifiersMenu:AddSeparatorText(modifierResource.DisplayName:Get() or modifier)
				sep:SetStyle("SeparatorTextAlign", 0.2)
				sep.SameLine = true


				local modifierGroup = customizeModifiersMenu:AddGroup(modifierId)
				modifierGroup.Disabled = not enabledCheckbox.Checked
				enabledCheckbox.OnChange = function()
					modifierGroup.Disabled = not enabledCheckbox.Checked
					if enabledCheckbox.Checked then
						ruleset.activeModifiers[modifierId] = {}
					else
						if type(ruleset.activeModifiers[modifierId]) == "table" then
							ruleset.activeModifiers[modifierId].delete = true
						else
							ruleset.activeModifiers[modifierId] = nil
						end
					end
				end

				if modifierResource.RulesetModifierType == 4 then
					Styler:ToggleButton(modifierGroup, "Disabled", "Enabled", false, function(swap)
						if swap then
							ruleset.activeModifiers[modifierId] = not ruleset.activeModifiers[modifierId] and true or false
						end
						return ruleset.activeModifiers[modifierId]
					end)
				elseif modifierResource.RulesetModifierType == 3 then
					local resourceModifierValues = {}
					for _, modifierValueId in pairs(Ext.StaticData.GetAll("RulesetModifierOption")) do
						---@type ResourceRulesetModifierOption
						local rulesetModifierValue = Ext.StaticData.Get(modifierValueId, "RulesetModifierOption")
						if rulesetModifierValue.Modifier == modifierId then
							table.insert(resourceModifierValues, rulesetModifierValue.DisplayName:Get())
						end
					end
					table.sort(resourceModifierValues)

					ruleset.activeModifiers[modifierId] = ruleset.activeModifiers[modifierId] or {}
					local selectedModifiers = ruleset.activeModifiers[modifierId]

					for i, modifierOption in ipairs(resourceModifierValues) do
						local box = modifierGroup:AddCheckbox(modifierOption, selectedModifiers[modifierOption] or false)
						box.SameLine = i > 1
						box.OnChange = function()
							selectedModifiers[modifierOption] = box.Checked
						end
					end
				end
			end
			self.popup:AddSelectable("Delete Ruleset").OnClick = function()
				self.config.rulesets[rulesetId].delete = true
				self:ManageRulesets(parent, rulesetSelectCallback)
			end
		end
	end

	local makeNewButton = parent:AddButton("+")
	makeNewButton:Tooltip():AddText("\t Create a new Ruleset")
	makeNewButton.SameLine = true
	makeNewButton.OnClick = function()
		self.popup:Open()
		FormBuilder:CreateForm(self.popup, function(formResults)
			local ruleset = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.ruleset)
			ruleset.name = formResults.Name
			ruleset.description = formResults.Description

			self.config.rulesets[FormBuilder:generateGUID()] = ruleset
			self:ManageRulesets(parent, rulesetSelectCallback)
		end, {
			{
				label = "Name",
				type = "Text",
				errorMessageIfEmpty = "A name is required"
			},
			{
				label = "Description",
				type = "Multiline",
			}
		})
	end
end
