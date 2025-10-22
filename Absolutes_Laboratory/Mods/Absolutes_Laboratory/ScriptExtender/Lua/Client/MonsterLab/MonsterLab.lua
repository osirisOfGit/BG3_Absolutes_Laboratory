Ext.Vars.RegisterModVariable(ModuleUUID, "ActiveMonsterLabProfile", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

Ext.Vars.RegisterModVariable(ModuleUUID, "HasDisabledMonsterLabProfiles", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})


Ext.Require("Client/MonsterLab/EncounterDesigner.lua")
-- Ext.Require("Client/MonsterLab/ExistingEncounters.lua")

MonsterLab = {
	config = MonsterLabConfigurationProxy,
	activeRuleset = "Base",
	---@param newProfile (string|boolean)?
	---@return string?
	activeProfile = function(newProfile)
		if newProfile or newProfile == false then
			Ext.Vars.GetModVariables(ModuleUUID).ActiveMonsterLabProfile = (type(newProfile) == "string" and newProfile or nil)
			Ext.Vars.GetModVariables(ModuleUUID).HasDisabledMonsterLabProfiles = not type(newProfile) == "string"
		end

		return Ext.Vars.GetModVariables(ModuleUUID).ActiveMonsterLabProfile
	end
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

	self.encounterFoldersSidebar = layoutRow:AddCell():AddChildWindow("folders")
	self.designerSection = layoutRow:AddCell()

	self:buildFolderView()
end

function MonsterLab:buildProfileView()
	---@type fun()
	local renderProfile

	Styler:MiddleAlignedColumnLayout(self.encounterFoldersSidebar, function(ele)
		local sIndex = 1
		local opt = { "Disabled" }

		for profileId, profile in TableUtils:OrderedPairs(self.config.profiles, function(_, value)
			return value.name
		end) do
			table.insert(opt, profile.name .. (profile.modId and "(M)" or ""))
			if self.activeProfile() == profileId then
				sIndex = #opt
			end
		end

		Styler:CheapTextAlign("Profiles", ele, "Big")

		local viewProfileButton = Styler:ImageButton(ele:AddImageButton("seeProfile", "ico_concentration", Styler:ScaleFactor({ 32, 32 })))

		local profileCombo = ele:AddCombo("##profiles")
		profileCombo.SameLine = true
		profileCombo.Options = opt
		profileCombo.WidthFitPreview = true
		profileCombo.SelectedIndex = sIndex - 1

		local manageProfileButton = Styler:ImageButton(ele:AddImageButton("Manage", "ico_edit_d", Styler:ScaleFactor({ 32, 32 })))
		manageProfileButton.SameLine = true

		viewProfileButton.OnClick = function()
			renderProfile()
		end

		profileCombo.OnChange = function()
			local selectedName = profileCombo.Options[profileCombo.SelectedIndex + 1]

			if selectedName == "Disabled" then
				self.activeProfile(false)
				Helpers:KillChildren(self.designerSection)
			else
				local isModProfile = selectedName:sub(#selectedName - 2) == "(M)"

				local activeProfile = self.activeProfile()

				self.activeProfile(TableUtils:IndexOf(self.config.profiles, function(value)
					if isModProfile then
						if value.modId then
							return value.name == selectedName:sub(1, #selectedName - 3)
						else
							return false
						end
					elseif not value.modId then
						return value.name == selectedName
					end

					return false
				end))

				if self.activeProfile() ~= activeProfile then
					renderProfile()
				end
			end
		end

		manageProfileButton.OnClick = function()
			Helpers:KillChildren(self.popup)
			self.popup:Open()

			FormBuilder:CreateForm(self.popup:AddMenu("Create New Profile"), function(formResults)
					---@type MonsterLabProfile
					local profile = {
						name = formResults.Name,
						description = formResults.Description,
						encounters = {}
					}

					self.config.profiles[FormBuilder:generateGUID()] = profile
					self:buildFolderView()
				end,
				{
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

			local modGroups = {
				["user"] = self.popup:AddGroup("")
			}

			modGroups["user"]:AddSeparatorText("Your Profile(s)"):SetStyle("SeparatorTextAlign", 0.5)

			for profileId, profile in TableUtils:OrderedPairs(self.config.profiles, function(key, value)
				return (value.modId and Ext.Mod.GetMod(value.modId).Info.Name or "") .. value.name
			end) do
				if profile.modId and not modGroups[profile.modId] then
					modGroups[profile.modId] = self.popup:AddGroup(profile.modId)
					modGroups[profile.modId]:AddSeparatorText(Ext.Mod.GetMod(profile.modId).Info.Name):SetStyle("SeparatorTextAlign", 0.5)
				end

				---@type ExtuiMenu
				local profileMenu = modGroups[profile.modId or "user"]:AddMenu(("%s%s"):format(profile.name, self.config.settings.defaultActiveProfile == profileId and " (D)" or ""))
				-- If groups only contain a menu, they resize indefinitely. They need some non-parent element inside em with a concrete size
				-- Putting it once above wasn't working for some reason
				modGroups[profile.modId or "user"]:AddDummy(0, 0)

				profileMenu:AddSelectable(("%s As Default"):format(self.config.settings.defaultActiveProfile == profileId and "Unset" or "Set")).OnClick = function()
					if self.config.settings.defaultActiveProfile == profileId then
						self.config.settings.defaultActiveProfile = nil
					else
						self.config.settings.defaultActiveProfile = profileId
					end
				end
				profileMenu:AddSelectable("Clone").OnClick = function()
					local profileCopy = TableUtils:DeeplyCopyTable(profile._real or profile)
					if TableUtils:IndexOf(self.config.profiles, function(value)
							return value.name == profile.name and not value.modId
						end)
					then
						profileCopy.name = profileCopy.name .. " (Copy)"
					end

					self.config.profiles[FormBuilder:generateGUID()] = profileCopy
					self:buildFolderView()
				end

				if not profile.modId then
					FormBuilder:CreateForm(profileMenu:AddMenu("Edit"), function(formResults)
							profile.name = formResults.Name
							profile.description = formResults.Description

							self:buildFolderView()
						end,
						{
							{
								label = "Name",
								type = "Text",
								errorMessageIfEmpty = "Required Field",
								defaultValue = profile.name
							},
							{
								label = "Description",
								type = "Multiline",
								defaultValue = profile.description
							}
						})

					profileMenu:AddSelectable("Export").OnClick = function()
						MonsterLabExportImport:exportProfile(false, profileId)
					end

					---@param select ExtuiSelectable
					profileMenu:AddSelectable("Delete", "DontClosePopups").OnClick = function(select)
						if select.Label ~= "Delete" then
							profile.delete = true
							self:buildFolderView()
						else
							select.Label = "Are You Sure?"
							select.DontClosePopups = false
							Styler:Color(select, "ErrorText")
						end
					end
				end
			end
		end
	end)
	self.encounterFoldersSidebar:AddNewLine()

	renderProfile = function()
		Helpers:KillChildren(self.designerSection)

		if self.activeProfile() and self.config.profiles[self.activeProfile()] then
			---@type MonsterLabProfile
			local profile = self.config.profiles[self.activeProfile()]

			Styler:CheapTextAlign("Active Profile: " .. profile.name, self.designerSection, "Large")

			if profile.description and profile.description ~= "" then
				Styler:CheapTextAlign(profile.description, self.designerSection)
			end

			local levelTable = self.designerSection:AddTable("levels", 1)
			levelTable.NoSavedSettings = true
			levelTable.RowBg = true
			levelTable.Resizable = false
			levelTable:SetColor("TableRowBg", Styler:ConvertRGBAToIMGUI({ 34, 34, 34, 0.6 }))
			levelTable:SetColor("TableRowBgAlt", Styler:ConvertRGBAToIMGUI({ 22, 22, 22, 0.96 }))

			-- Only using this to determine the width of the container, as it keeps scaling the vertical dimension infinitely
			local cardsWindow = self.designerSection:AddChildWindow("Combat Group Cards")
			cardsWindow.AlwaysAutoResize = true
			cardsWindow.Size = { 0, 1 }

			local cardColours = {
				{ 255, 0,   0,   0.5 },
				{ 0,   255, 0,   0.5 },
				{ 0,   0,   255, 0.5 },
				{ 255, 0,   255, 0.5 },
				{ 255, 255, 0,   0.5 },
				{ 0,   255, 255, 0.5 },
			}

			-- Giving the cardsWindow time to resize itself
			Ext.Timer.WaitFor(50, function()
				for l, level in ipairs(EntityRecorder.Levels) do
					local row = levelTable:AddRow():AddCell()

					row:AddDummy(Styler:ScaleFactor() * 50, 0)
					local title = Styler:ScaledFont(row:AddText(level), "Large")
					title.SameLine = true

					---@class ML_CombatGroup
					---@field profileEncounter MonsterLabProfileEncounterEntry
					---@field encounter MonsterLabEncounter

					---@type ML_CombatGroup[]
					local combatGroups = {}

					for _, profileEncounter in pairs(profile.encounters) do
						local encounter = self.config.folders[profileEncounter.folderId]
							and self.config.folders[profileEncounter.folderId].encounters[profileEncounter.encounterId]

						if encounter and encounter.gameLevel == level then
							table.insert(combatGroups, {
								profileEncounter = profileEncounter,
								encounter = encounter
							})
						end
					end

					local maxRowSize = math.floor(cardsWindow.LastSize[1] / (Styler:ScaleFactor() * 300))
					local entriesPerColumn = math.floor(TableUtils:CountElements(combatGroups) / maxRowSize)
					entriesPerColumn = entriesPerColumn > 0 and entriesPerColumn or 1
					local layoutTable = row:AddTable("cards", maxRowSize)

					local encounterManagerGroup = row:AddGroup("encounterManager")
					encounterManagerGroup.Visible = false

					local cardRow = layoutTable:AddRow()

					for _ = 1, maxRowSize do
						cardRow:AddCell()
					end

					local counter = 0

					for index, combatGroup in TableUtils:OrderedPairs(combatGroups, function(key, value)
						return TableUtils:CountElements(value)
					end) do
						counter = counter + 1

						---@type ExtuiChildWindow
						local combatGroupCard = cardRow.Children[(counter % maxRowSize) > 0 and (counter % maxRowSize) or maxRowSize]:AddChildWindow(index)
						combatGroupCard.Size = Styler:ScaleFactor({ 300, (TableUtils:CountElements(combatGroup.encounter.entities) + 1.5) * 40 })

						local groupTable = combatGroupCard:AddTable("chlidTable", 1)
						groupTable.Borders = true
						groupTable:SetColor("TableBorderStrong", Styler:ConvertRGBAToIMGUI(cardColours[(counter % (#cardColours - (maxRowSize % 2 == 0 and 1 or 0))) + 1]))

						local headerCell = groupTable:AddRow():AddCell()

						local removeEncounterButton = Styler:ImageButton(headerCell:AddImageButton("delete" .. index, "ico_close_d", Styler:ScaleFactor({ 24, 24 })))
						removeEncounterButton:Tooltip():AddText("\t  Removes this encounter from this Profile - will not delete the encounter itself")
						removeEncounterButton.OnClick = function()
							local encounterProfileIndex = TableUtils:IndexOf(profile.encounters, function(value)
								return value.encounterId == combatGroup.profileEncounter.encounterId and value.folderId == combatGroup.profileEncounter.folderId
							end)
							profile.encounters[encounterProfileIndex].delete = true
							TableUtils:ReindexNumericTable(profile.encounters)
							renderProfile()
						end

						local modName = combatGroup.encounter.modId and Ext.Mod.GetMod(combatGroup.encounter.modId).Info.Name
						local titleText = headerCell:AddTextLink(("%s (%s)%s"):format(
							combatGroup.encounter.name,
							self.config.folders[combatGroup.profileEncounter.folderId].name,
							modName and ("\nMod: " .. modName:sub(0, 10)) or ""))
						titleText.SameLine = true

						titleText:SetColor("TextLink", { 0.86, 0.79, 0.68, 0.78 })
						titleText.OnClick = function()
							if encounterManagerGroup.Visible == false then
								encounterManagerGroup.Visible = true
								self:buildEncounterView(combatGroup.encounter, encounterManagerGroup, combatGroup.profileEncounter)
							else
								Helpers:KillChildren(encounterManagerGroup)
								encounterManagerGroup.Visible = false
							end
						end

						for entityId, entityRecord in TableUtils:OrderedPairs(combatGroup.encounter.entities, function(key, value)
							return value.displayName
						end) do
							local entityRow = groupTable:AddRow():AddCell()

							---@type CharacterTemplate
							local template = Ext.ClientTemplate.GetTemplate(entityRecord.template)

							local image = entityRow:AddImage(template and template.Icon or "", Styler:ScaleFactor({ 32, 32 }))
							if image.ImageData.Icon == "" then
								image:Destroy()
								entityRow:AddImage("Item_Unknown", Styler:ScaleFactor({ 32, 32 }))
							end

							entityRow:AddText(entityRecord.displayName).SameLine = true
						end
					end

					counter = counter + 1
					---@type ExtuiChildWindow
					local addGroupCard = cardRow.Children[(counter % maxRowSize) > 0 and (counter % maxRowSize) or maxRowSize]:AddGroup("Add Group")

					local groupTable = addGroupCard:AddTable("chlidTable", 1)
					groupTable.Borders = true
					groupTable:SetColor("TableBorderStrong", Styler:ConvertRGBAToIMGUI(cardColours[(counter % (#cardColours - (maxRowSize % 2 == 0 and 1 or 0))) + 1]))

					local addEncounterSelect = groupTable:AddRow():AddCell():AddSelectable("Add Encounter")
					addEncounterSelect:SetStyle("SelectableTextAlign", 0.5)
					addEncounterSelect.Selected = true
					addEncounterSelect.OnClick = function()
						addEncounterSelect.Selected = true
						Helpers:KillChildren(self.popup)
						self.popup:Open()

						for folderId, folder in TableUtils:OrderedPairs(self.config.folders,
							function(key, value)
								return value.name
							end,
							function(key, value)
								return TableUtils:IndexOf(value.encounters, function(value)
									return value.gameLevel == level
								end) ~= nil
							end)
						do
							local folderWindow = self.popup:AddChildWindow(folderId)
							folderWindow.NoSavedSettings = true

							Styler:CheapTextAlign(folder.name, folderWindow)

							local width, height = Styler:calculateTextDimensions(folder.name)
							height = height * 2

							for encounterId, encounter in TableUtils:OrderedPairs(folder.encounters,
								function(key, value)
									return value.name
								end,
								function(key, value)
									return value.gameLevel == level and not TableUtils:IndexOf(profile.encounters, function(value)
										return value.folderId == folderId and value.encounterId == key
									end)
								end)
							do
								local optWidth, optHeight = Styler:calculateTextDimensions(encounter.name)

								if optWidth > width then
									width = optWidth
								end
								height = height + optHeight
								folderWindow:AddSelectable(encounter.name, "DontClosePopups").OnClick = function()
									table.insert(profile.encounters, {
										encounterId = encounterId,
										folderId = folderId
									} --[[@as MonsterLabProfileEncounterEntry]])

									renderProfile()
								end
							end

							if #folderWindow.Children == 1 then
								folderWindow:Destroy()
							else
								folderWindow.Size = { width, height }
							end
						end

						if #self.popup.Children == 0 then
							Styler:Color(self.popup:AddText("No Encounters Available For Level " .. level), "ErrorText")
						end
					end
				end
			end)
		end
	end
end

local waitedOnce = false
function MonsterLab:buildFolderView()
	if not waitedOnce and not self.activeProfile() then
		waitedOnce = true
		Ext.Timer.WaitFor(100, function()
			self:buildFolderView()
		end)
	end

	Helpers:KillChildren(self.encounterFoldersSidebar)

	self:buildProfileView()

	Styler:CheapTextAlign("Your Encounters", self.encounterFoldersSidebar, "Big")
	self.encounterFoldersSidebar:AddNewLine()

	local longestText = 0

	for folderId, folder in TableUtils:OrderedPairs(self.config.folders, function(key, value)
		return value.name
	end) do
		---@type ExtuiSelectable
		local folderSelect = self.encounterFoldersSidebar:AddSelectable("")
		folderSelect.IDContext = folderId
		folderSelect:SetStyle("SelectableTextAlign", 0.5, 0)

		local sep = self.encounterFoldersSidebar:AddSeparatorText(">  " .. folder.name)
		sep.PositionOffset = Styler:ScaleFactor({ 0, -50 })

		local header = self.encounterFoldersSidebar:AddGroup("encounters")
		header.Visible = folderSelect.Selected

		folderSelect.OnClick = function()
			header.Visible = not header.Visible
			sep.Label = (header.Visible and "" or ">  ") .. folder.name
		end

		folderSelect.OnRightClick = function()
			Helpers:KillChildren(self.popup)
			self.popup:Open()

			FormBuilder:CreateForm(self.popup:AddMenu("Edit"), function(formResults)
					folder.name = formResults.Name
					folder.description = formResults.Description

					self:buildFolderView(self.encounterFoldersSidebar, self.designerSection)
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
					self:buildFolderView(self.encounterFoldersSidebar, self.designerSection)
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
				self:buildEncounterView(encounter, nil, {
					folderId = folderId,
					encounterId = encounterId
				})
			end

			encounterSelect.OnRightClick = function()
				Helpers:KillChildren(self.popup)
				self.popup:Open()

				---@type ExtuiMenu
				local editMenu = self.popup:AddMenu("Edit")

				FormBuilder:CreateForm(editMenu, function(formResults)
						encounter.name = formResults.Name
						encounter.description = formResults.Description

						self:buildFolderView()
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
					self:buildFolderView()
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

							self:buildFolderView()
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

	self.encounterFoldersSidebar:AddNewLine()

	---@type ExtuiSelectable
	local createFolderButton = self.encounterFoldersSidebar:AddSelectable("Create Folder")
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

				self:buildFolderView()
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

	self.encounterFoldersSidebar.Size = { math.max(300 * Styler:ScaleFactor(), longestText), 0 }
end

---@param encounter MonsterLabEncounter
---@param parent ExtuiTreeParent?
---@param encounterMeta MonsterLabProfileEncounterEntry
function MonsterLab:buildEncounterView(encounter, parent, encounterMeta)
	local parent = parent or self.designerSection
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
			EncounterDesigner:buildDesigner(encounter, encounterMeta._real or encounterMeta)
		end
		local designerSection = layoutRow:AddCell()

		for id, entity in TableUtils:OrderedPairs(encounter.entities, function(key, value)
			return value.displayName
		end) do
			if rulesetToCopyTo and rulesetToCopyFrom then
				if entity.rulesetModifiers[rulesetToCopyFrom] then
					---@type MonsterLab_RulesetRule
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
							---@type MonsterLab_RulesetRule
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
							mutatorGroup.Visible = activeRuleset.shouldSpawn
						end
						return activeRuleset.shouldSpawn
					end)

					mutatorGroup = designerSection:AddGroup("DesignIt")

					Styler:EnableToggleButton(mutatorGroup,
						"Composable",
						false,
						[[If enabled, these mutators will be _composable_, meaning they will be combined with any mutators of the same type that are applicable for this entity per the active Mutation Profile. See the documentation for each mutator to see when and how this applies.
	If unchecked, composable mutators of the same type from earlier mutations will be replaced with these - these mutators will always be processed last, so they are guaranteed to overwrite any conflicts from the Mutation Profile]],
						function(swap)
							if swap then
								activeRuleset.composable = not activeRuleset.composable
							end
							return activeRuleset.composable
						end).UserData = "keep"

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
					"Alt",
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
