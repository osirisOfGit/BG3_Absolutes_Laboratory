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
	self.popup = Styler:Popup(parent)

	local layoutTable = Styler:TwoColumnTable(parent, "MonsterLab")
	layoutTable.Resizable = false
	layoutTable.Borders = false

	local layoutRow = layoutTable:AddRow()

	local encounterFolders = layoutRow:AddCell():AddChildWindow("folders")
	local encounterDesigner = layoutRow:AddCell()

	self:buildFolderView(encounterFolders, encounterDesigner)
end

function MonsterLab:buildProfileView(parent, designerSection)

end

---@param parent ExtuiChildWindow
---@param designerSection ExtuiTreeParent
function MonsterLab:buildFolderView(parent, designerSection)
	Helpers:KillChildren(parent)

	Styler:CheapTextAlign("Your Encounters", parent, "Big")
	parent:AddNewLine()

	local longestText = 0

	for folderId, folder in TableUtils:OrderedPairs(self.config.folders, function(key, value)
		return value.name
	end) do
		---@type ExtuiSelectable
		local folderSelect = parent:AddSelectable("")
		folderSelect.IDContext = folderId
		folderSelect:SetStyle("SelectableTextAlign", 0.5, 0)

		local sep = parent:AddSeparatorText(folder.name)
		sep.PositionOffset = Styler:ScaleFactor({ 0, -50 })

		local header = parent:AddGroup("encounters")
		header.Visible = folderSelect.Selected

		folderSelect.OnClick = function()
			header.Visible = not header.Visible
		end
		folderSelect.OnRightClick = function()
			Helpers:KillChildren(self.popup)
			self.popup:Open()

			FormBuilder:CreateForm(self.popup:AddMenu("Edit"), function(formResults)
					folder.name = formResults.Name
					folder.description = formResults.Description

					self:buildFolderView(parent, designerSection)
				end,
				{
					{
						label = "Name",
						type = "Text",
						errorMessageIfEmpty = "Name is required",
						defaultValue = folder.name
					},
					{
						label = "Description",
						type = "Multiline",
						defaultValue = folder.description
					}
				})

			---@param select ExtuiSelectable
			self.popup:AddSelectable("Delete", "DontClosePopups").OnClick = function(select)
				if select.Label ~= "Delete" then
					folder.delete = true
					self:buildFolderView(parent, designerSection)
				else
					select.DontClosePopups = false
					select.Label = "Are You Sure?"
					Styler:Color(select, "ErrorText")
				end
			end
		end

		local width = Styler:calculateTextDimensions(folder.name)
		longestText = width > longestText and width or longestText

		for encounterId, encounter in TableUtils:OrderedPairs(folder.encounters, function(key, value)
			return value.name
		end) do
			local width = Styler:calculateTextDimensions(folder.name)
			longestText = width > longestText and width or longestText

			---@type ExtuiSelectable
			local encounterSelect = header:AddSelectable(encounter.name .. "##" .. encounterId)
			encounterSelect.OnClick = function()
				encounterSelect.Selected = false
				self:buildEncounterView(designerSection, encounter)
			end

			encounterSelect.OnRightClick = function()
				Helpers:KillChildren(self.popup)
				self.popup:Open()

				---@type ExtuiMenu
				local editMenu = self.popup:AddMenu("Edit")

				FormBuilder:CreateForm(editMenu, function(formResults)
						encounter.name = formResults.Name
						encounter.description = formResults.Description

						self:buildFolderView(parent, designerSection)
					end,
					{
						{
							label = "Name",
							type = "Text",
							errorMessageIfEmpty = "Name is required",
							defaultValue = encounter.name
						},
						{
							label = "Description",
							type = "Multiline",
							defaultValue = encounter.description
						}
					})

				self.popup:AddSelectable("Copy").OnClick = function()
					---@type MonsterLabEncounter
					local encounterCopy = TableUtils:DeeplyCopyTable(encounter._real)
					encounterCopy.name = encounterCopy.name .. " (Copy)"

					folder.encounters[FormBuilder:generateGUID()] = encounterCopy
					self:buildFolderView(parent, designerSection)
				end

				if TableUtils:CountElements(self.config.folders) > 1 then
					---@type ExtuiMenu
					local moveMenu = self.popup:AddMenu("Move To Folder")
					for _, otherFolder in TableUtils:OrderedPairs(self.config.folders, function(key, value)
							return value.name
						end,
						function(key, value)
							return key ~= folderId
						end) do
						moveMenu:AddSelectable(otherFolder.name).OnClick = function()
							---@type MonsterLabEncounter
							local encounterCopy = TableUtils:DeeplyCopyTable(encounter._real)

							if TableUtils:IndexOf(otherFolder.encounters, function(value)
									return value.name == encounterCopy.name
								end) then
								encounterCopy.name = encounterCopy.name .. " (Copy)"
							end

							otherFolder.encounters[encounterId] = encounterCopy
							encounter.delete = true

							self:buildFolderView(parent, designerSection)
						end
					end
				end

				self.popup:AddSelectable("Delete", "DontClosePopups").OnClick =
				---@param select ExtuiSelectable
					function(select)
						if select.Label ~= "Delete" then
							encounter.delete = true
						else
							select.Label = "Are You Sure?"
							Styler:Color(select, "ErrorText")
							select.DontClosePopups = false
						end
					end
			end
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

	parent.Size = { math.max(300 * Styler:ScaleFactor(), longestText), 0 }
end

---@param parent ExtuiTreeParent
---@param encounter MonsterLabEncounter
function MonsterLab:buildEncounterView(parent, encounter)
	Helpers:KillChildren(parent)

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		Styler:CheapTextAlign(encounter.name, ele).Font = "Big"

		if encounter.description then
			Styler:CheapTextAlign(encounter.description, parent)
		end
	end)

	---@type fun()
	local buildEncounter

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		self:ManageRulesets(ele:AddGroup("Rulesets"), function(...)
			buildEncounter(...)
		end)
	end)

	local encounterGroup = parent:AddGroup("Encounter")

	local lastSelectedEntity
	---@type ExtuiImage?
	local activeSelectedIcon

	---@param rulesetToCopyTo string?
	---@param rulesetToCopyFrom string?
	buildEncounter = function(rulesetToCopyTo, rulesetToCopyFrom)
		activeSelectedIcon = nil

		Helpers:KillChildren(encounterGroup)
		local layoutTable = Styler:TwoColumnTable(encounterGroup, "layout")
		layoutTable.Resizable = false
		local layoutRow = layoutTable:AddRow()

		local entitySidebar = layoutRow:AddCell()
		entitySidebar:AddButton("Launch Designer Mode").OnClick = function()
			EncounterDesigner:buildDesigner(encounter)
		end
		local designerSection = layoutRow:AddCell()

		for id, entity in TableUtils:OrderedPairs(encounter.entities, function(key, value)
			return value.displayName
		end) do
			if rulesetToCopyTo and rulesetToCopyFrom then
				if entity.rulesetModifiers[rulesetToCopyFrom] then
					---@type MonsterLab_RulesetModifiers
					local rulesetCopy = TableUtils:DeeplyCopyTable(entity.rulesetModifiers[rulesetToCopyFrom]._real)

					if entity.rulesetModifiers[rulesetToCopyTo] then
						entity.rulesetModifiers[rulesetToCopyTo].delete = true
						entity.rulesetModifiers[rulesetToCopyTo] = nil
					end

					entity.rulesetModifiers[rulesetToCopyTo] = rulesetCopy
				end
			end

			local entityGroup = entitySidebar:AddGroup(id)
			local deleteButton = Styler:ImageButton(entityGroup:AddImageButton("delete" .. id, "ico_red_x", Styler:ScaleFactor({ 16, 16 })))
			deleteButton.OnClick = function()
				encounter.entities[id].delete = true
				Helpers:KillChildren(designerSection)
				buildEncounter()
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

			local nameGroup = entityGroup:AddGroup(id)
			nameGroup.SameLine = true

			local selectedIcon = entityGroup:AddImage("ico_concentration", Styler:ScaleFactor({ 36, 36 }))
			selectedIcon.Visible = false
			selectedIcon.SameLine = true

			---@type ExtuiTextLink
			local name = Styler:Color(nameGroup:AddTextLink(("%s (%s)"):format(entity.displayName, id:sub(#id - 5))), "PlainLink")
			name.IDContext = id
			name.OnRightClick = function()
				Helpers:KillChildren(self.popup)
				self.popup:Open()

				self.popup:AddSelectable("Edit Entity Details").OnClick = function()
					self:buildCreateEntityForm(designerSection, encounter, buildEncounter, entity)
				end

				---@type ExtuiMenu
				local copyEntityMutations = self.popup:AddMenu("Copy Entity Mutations From:")
				for rulesetId, ruleset in TableUtils:OrderedPairs(self.config.rulesets, function(key, value)
					return key == "Base" and 1 or value.name
				end) do
					---@type ExtuiMenu
					local rulesetMenu = copyEntityMutations:AddMenu(ruleset.name)
					rulesetMenu.IDContext = rulesetId

					for entityId, otherEntity in TableUtils:OrderedPairs(encounter.entities, function(key, value)
							return value.displayName
						end,
						function(key, value)
							return key ~= id and value.rulesetModifiers[rulesetId] and next(value.rulesetModifiers[rulesetId]._real)
						end)
					do
						rulesetMenu:AddSelectable(("%s (%s)"):format(otherEntity.displayName, entityId:sub(#entityId - 5))).OnClick = function()
							---@type MonsterLab_RulesetModifiers
							local copy = TableUtils:DeeplyCopyTable(otherEntity.rulesetModifiers[rulesetId]._real)

							if entity.rulesetModifiers[rulesetId] then
								entity.rulesetModifiers[rulesetId].delete = true
								entity.rulesetModifiers[rulesetId] = nil
							end
							entity.rulesetModifiers[rulesetId] = copy
							buildEncounter()
						end
					end

					if #rulesetMenu.Children == 0 then
						rulesetMenu:Destroy()
					end
				end

				self.popup:AddSelectable("Clone").OnClick = function()
					encounter.entities[FormBuilder:generateGUID()] = TableUtils:DeeplyCopyTable(entity._real)
					buildEncounter()
				end
			end

			local openPopupFunc = Styler:HyperlinkRenderable(name, entity.template, "Alt", true, nil, function(parent)
				CharacterWindow:BuildWindow(parent, entity.template)
			end)

			name.OnClick = function()
				if not openPopupFunc() then
					selectedIcon.Visible = true
					if activeSelectedIcon and activeSelectedIcon.Handle ~= selectedIcon.Handle then
						activeSelectedIcon.Visible = false
					end
					activeSelectedIcon = selectedIcon

					lastSelectedEntity = id
					Helpers:KillChildren(designerSection)

					entity.rulesetModifiers[self.activeRuleset] = entity.rulesetModifiers[self.activeRuleset]
						or TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.rulesetModifiers)

					local activeRuleset = entity.rulesetModifiers[self.activeRuleset]

					local mutatorGroup

					Styler:EnableToggleButton(designerSection, "Spawn", false, nil, function(swap)
						if swap then
							activeRuleset.shouldSpawn = not activeRuleset.shouldSpawn
							if not activeRuleset.shouldSpawn then
								Helpers:KillChildren(mutatorGroup)
							else
								activeRuleset.mutators = activeRuleset.mutators or {}

								MutationDesigner:RenderMutatorsSidebarStyle(mutatorGroup, activeRuleset.mutators, nil, nil, self.popup)
							end
						end
						return activeRuleset.shouldSpawn
					end)

					mutatorGroup = designerSection:AddGroup("DesignIt")

					if activeRuleset.shouldSpawn then
						activeRuleset.mutators = activeRuleset.mutators or {}

						MutationDesigner:RenderMutatorsSidebarStyle(mutatorGroup, activeRuleset.mutators, nil, nil, self.popup)
					end
				end
			end

			if lastSelectedEntity == id then
				name:OnClick()
			end
		end

		---@type ExtuiSelectable
		local createEntityButton = entitySidebar:AddSelectable("Create New Entity")
		createEntityButton:SetStyle("SelectableTextAlign", 0.5)
		createEntityButton.OnClick = function()
			createEntityButton.Selected = false

			self:buildCreateEntityForm(designerSection, encounter, function()
				buildEncounter()
			end)
		end
	end
	buildEncounter()
end

---@param parent ExtuiTreeParent
---@param encounter MonsterLabEncounter
---@param completedCallback fun()
---@param existingEntity MonsterLabEntity?
function MonsterLab:buildCreateEntityForm(parent, encounter, completedCallback, existingEntity)
	TemplateSelector:init()

	Helpers:KillChildren(parent)

	parent:AddText("Name: ")
	local nameInput = parent:AddInputText("", existingEntity and existingEntity.displayName)
	nameInput.SameLine = true
	nameInput.ItemWidth = 200

	parent:AddText("Title: ")
	local titleInput = parent:AddInputText("", existingEntity and existingEntity.title)
	titleInput.SameLine = true
	titleInput.ItemWidth = 200

	parent:AddText("Chosen Template: ")
	local chosenTemplateGroup = parent:AddGroup("template")
	chosenTemplateGroup.SameLine = true
	local chosenTemplateId = existingEntity and existingEntity.template

	local errorText = Styler:Color(parent:AddText("Name/Template fields are required!"), "ErrorText")
	errorText.Visible = false

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
				local templateSelect = cell:AddSelectable(characterTemplate.Name == "" and (characterTemplate.DisplayName:Get() or source)
					or characterTemplate.Name)
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
				if existingEntity and existingEntity.template == templateId then
					templateSelect:OnClick()
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
		if nameInput.Text == "" or not chosenTemplateId then
			errorText.Visible = true
		else
			errorText.Visible = false

			local entity = existingEntity or TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.entity)
			entity.displayName = nameInput.Text
			entity.title = titleInput.Text
			entity.template = chosenTemplateId
			entity.coordinates = existingEntity and existingEntity.coordinates or TableUtils:DeeplyCopyTable(encounter.baseCoords._real)

			if not existingEntity then
				encounter.entities[FormBuilder:generateGUID()] = entity
			end

			completedCallback()
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
right-click to modify or delete that ruleset. The Base ruleset can't be modified or deleted - this is the default if there are no other eligible rulesets.]])

	---@type ExtuiButton
	local lastActiveButton

	local createdOne = false
	for rulesetId, ruleset in TableUtils:OrderedPairs(self.config.rulesets, function(key, value)
		return key == "Base" and 1 or value.name
	end) do
		local rulesetButton = parent:AddButton(ruleset.name)
		rulesetButton.SameLine = createdOne
		createdOne = true

		rulesetButton.IDContext = rulesetId
		if ruleset.description ~= "" then
			rulesetButton:Tooltip():AddText("\t" .. ruleset.description)
		end

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

				self.activeRuleset = rulesetId

				rulesetSelectCallback()
			end
		end

		rulesetButton.OnRightClick = function()
			Helpers:KillChildren(self.popup)
			self.popup:Open()

			if rulesetId ~= "Base" then
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

				---@type ExtuiMenu
				local selectModifiersMenu = customizeModifiersMenu:AddMenu("Select Modifiers")

				local modGroup = customizeModifiersMenu:AddGroup("mods")

				local function buildCustomizer()
					modGroup.Visible = TableUtils:CountElements(ruleset.activeModifiers) ~= 0
					Helpers:KillChildren(modGroup)
					for modifierId in TableUtils:OrderedPairs(ruleset.activeModifiers, function(key)
						---@type ResourceRulesetModifier
						local modifierResource = Ext.StaticData.Get(key, "RulesetModifier")
						return tostring(modifierResource.RulesetModifierType) .. (modifierResource.DisplayName:Get() or modifierResource.Name)
					end) do
						---@type ResourceRulesetModifier
						local modifierResource = Ext.StaticData.Get(modifierId, "RulesetModifier")

						modGroup:AddSeparatorText(modifierResource.DisplayName:Get() or modifierResource.Name)

						local modifierGroup = modGroup:AddGroup(modifierId)
						modifierGroup.IDContext = modifierId

						if modifierResource.RulesetModifierType == 4 then
							Styler:DualToggleButton(modifierGroup, "Enabled", "Disabled", false, function(swap)
								if swap then
									ruleset.activeModifiers[modifierId] = not ruleset.activeModifiers[modifierId]
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

							local selectedModifiers = ruleset.activeModifiers[modifierId]

							for i, modifierOption in ipairs(resourceModifierValues) do
								local box = modifierGroup:AddCheckbox(modifierOption, TableUtils:IndexOf(selectedModifiers, modifierOption) ~= nil)
								box.IDContext = modifierId
								box.SameLine = i > 1
								box.OnChange = function()
									if box.Checked then
										table.insert(selectedModifiers, modifierOption)
									else
										selectedModifiers[TableUtils:IndexOf(selectedModifiers, modifierOption)] = nil
										TableUtils:ReindexNumericTable(selectedModifiers)
									end
								end
							end
						end
					end
				end
				buildCustomizer()

				for modifierName, modifierId in TableUtils:OrderedPairs(Lab_RulesetModifiers, function(_, value)
					---@type ResourceRulesetModifier
					local modifierResource = Ext.StaticData.Get(value, "RulesetModifier")
					return tostring(modifierResource.RulesetModifierType) .. (modifierResource.DisplayName:Get() or modifierResource.Name)
				end) do
					---@type ResourceRulesetModifier
					local modifierResource = Ext.StaticData.Get(modifierId, "RulesetModifier")

					---@type ExtuiSelectable
					local modSelect = selectModifiersMenu:AddSelectable(modifierResource.DisplayName:Get() or modifierResource.Name, "DontClosePopups")
					modSelect.Selected = ruleset.activeModifiers[modifierId] ~= nil
					modSelect.OnClick = function()
						if ruleset.activeModifiers[modifierId] ~= nil then
							if type(ruleset.activeModifiers[modifierId]) == "table" then
								ruleset.activeModifiers[modifierId].delete = true
							end
							ruleset.activeModifiers[modifierId] = nil
						else
							ruleset.activeModifiers[modifierId] = modifierResource.RulesetModifierType == 3 and {} or false
						end

						buildCustomizer()
					end
				end

				self.popup:AddSelectable("Delete Ruleset").OnClick = function()
					self.config.rulesets[rulesetId].delete = true
					self:ManageRulesets(parent, rulesetSelectCallback)
				end
			end

			---@type ExtuiMenu
			local copyMenu = self.popup:AddMenu("Copy Encounter Configs From: ")
			copyMenu:Tooltip():AddText("\t This will completely override the configs in this ruleset")

			for otherRulesetId, otherRuleset in TableUtils:OrderedPairs(self.config.rulesets, function(key, value)
					return key == "Base" and 1 or value.name
				end,
				function(key, value)
					return key ~= rulesetId
				end)
			do
				copyMenu:AddSelectable(otherRuleset.name).OnClick = function()
					rulesetSelectCallback(rulesetId, otherRulesetId)
				end
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
