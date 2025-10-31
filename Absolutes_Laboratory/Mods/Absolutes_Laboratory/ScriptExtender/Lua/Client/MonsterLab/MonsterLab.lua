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

	local profileTable = Styler:MiddleAlignedColumnLayout(self.encounterFoldersSidebar, function(ele)
		Styler:CheapTextAlign("Profiles", ele, "Big").SamePosition = true

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

			---@type ExtuiMenu
			local importMenu = self.popup:AddMenu("Import Profile(s)")

			local importGroup = importMenu:AddGroup("Import")
			importGroup:AddText("Enter the full, EXACT (case-sensitive) file path + name relative to Lab's SE Folder")

			local fileNameInput = importGroup:AddInputText("")
			fileNameInput.Hint = "imported/otherProfile.json"
			fileNameInput:SetColor("Text", Styler:ConvertRGBAToIMGUI({ 1, 0, 0, 0.4 }))

			local importButton = importGroup:AddButton("Import")
			importButton.SameLine = true

			local errorGroup = importGroup:AddGroup("DepErrors")
			errorGroup.Visible = false

			local timer
			fileNameInput.OnChange = function()
				errorGroup.Visible = false

				if timer then
					Ext.Timer.Cancel(timer)
				end

				timer = Ext.Timer.WaitFor(200, function()
					if not FileUtils:LoadFile(fileNameInput.Text) then
						fileNameInput:SetColor("Text", Styler:ConvertRGBAToIMGUI({ 1, 0, 0, 0.4 }))
						importButton.Disabled = true
					else
						fileNameInput:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })
						importButton.Disabled = false
					end
				end)
			end

			importButton.OnClick = function()
				local importFunc, mods, failedDependencies, showDepWindowFunc = MonsterLabExportImport:importProfile(FileUtils:LoadTableFile(fileNameInput.Text))
				if not importFunc then
					self:buildFolderView()
					Styler:CheapTextAlign("Imported!", importGroup)
				else
					errorGroup.Visible = true
					Helpers:KillChildren(errorGroup)

					errorGroup:AddSeparatorText("Missing Dependencies!"):SetColor("Separator", { 1, 0, 0, 0.4 })
					Styler:MiddleAlignedColumnLayout(errorGroup, function(ele)
						local continueButton = ele:AddButton("Continue")
						continueButton:Tooltip():AddText("\t This will remove all items that depend on a missing mod while importing - it will not affect the file")
						continueButton.OnClick = function()
							importFunc()
							self:buildFolderView()
							Styler:CheapTextAlign("Imported!", importGroup)
						end

						local viewReport = ele:AddButton("View Report")
						viewReport.SameLine = true
						viewReport.OnClick = showDepWindowFunc
					end)

					local modTable = errorGroup:AddTable("Deps", 3)

					for modId, mod in TableUtils:OrderedPairs(mods, function(key, value)
						return value.modName
					end) do
						local row = modTable:AddRow()
						if failedDependencies[modId] then
							row:SetColor("Text", { 1, 0, 0, 0.6 })
						end

						row:AddCell():AddText(mod.modName)
						row:AddCell():AddText(table.concat(mod.modVersion, "."))
						row:AddCell():AddText(mod.modAuthor)
					end

					errorGroup:AddSeparatorText("Missing Dependencies!"):SetColor("Separator", { 1, 0, 0, 0.4 })
				end
			end

			if ConfigurationStructure.config.monsterLab.profiles() then
				---@type ExtuiMenu
				local exportMenu = self.popup:AddMenu("Export")
				local checkboxGroup = exportMenu:AddGroup("")
				for profileId, profile in TableUtils:OrderedPairs(ConfigurationStructure.config.monsterLab.profiles, function(key, value)
					return value.name
				end) do
					checkboxGroup:AddCheckbox(profile.name).UserData = profileId
				end

				exportMenu:AddSelectable("Export").OnClick = function()
					local profiles = {}
					for _, child in pairs(checkboxGroup.Children) do
						if child.Checked then
							table.insert(profiles, child.UserData)
						end
					end
					MonsterLabExportImport:exportProfile(false, table.unpack(profiles))
				end

				exportMenu:AddSelectable("Export For Mod").OnClick = function()
					local profiles = {}
					for _, child in pairs(checkboxGroup.Children) do
						if child.Checked then
							table.insert(profiles, child.UserData)
						end
					end
					MonsterLabExportImport:exportProfile(true, table.unpack(profiles))
				end
			end

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
							if self.activeProfile() == profileId then
								self.activeProfile(false)
							end

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
	MazzleDocs:addDocButton(profileTable.Children[1].Children[1])
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
		Ext.Timer.WaitFor(200, function()
			self:buildFolderView()
		end)
	end

	Helpers:KillChildren(self.encounterFoldersSidebar)

	self:buildProfileView()

	Styler:CheapTextAlign("Your Encounters", self.encounterFoldersSidebar, "Big")

	local longestText = 0

	for folderId, folder in TableUtils:OrderedPairs(self.config.folders, function(key, value)
		return value.name
	end) do
		local folderSelect = self.encounterFoldersSidebar:AddTree(folder.name)
		folderSelect.IDContext = folderId
		folderSelect:SetOpen(false, "Always")
		folderSelect.SpanFullWidth = true
		Styler:ScaledFont(folderSelect, "Big")

		self.encounterFoldersSidebar:AddDummy(50, 0)
		local header = self.encounterFoldersSidebar:AddGroup("encounters")
		header.SameLine = true
		header.Visible = folderSelect.Selected

		folderSelect.OnClick = function()
			header.Visible = not header.Visible
		end

		if not folder.modId then
			folderSelect.OnRightClick = function()
				Helpers:KillChildren(self.popup)
				self.popup:Open()

				FormBuilder:CreateForm(self.popup:AddMenu("Create Encounter"), function(formResults)
					local encounter = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.encounter)
					encounter.name = formResults.Name
					encounter.description = formResults.Description
					encounter.combatGroupId = FormBuilder:generateGUID()
					encounter.faction = "64321d50-d516-b1b2-cfac-2eb773de1ff6"
					folder.encounters[FormBuilder:generateGUID()] = encounter
					self:buildFolderView()
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
						self:buildFolderView()
					else
						select.DontClosePopups = false
						select.Label = "Are You Sure?"
						Styler:Color(select, "ErrorText")
					end
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
							self:buildFolderView()
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

			if not entity.rulesetModifiers[self.activeRuleset] then
				entity.rulesetModifiers[self.activeRuleset] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.rulesetModifiers)
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
	for rulesetId, ruleset in TableUtils:OrderedPairs(MonsterLabConfigurationProxy.rulesets, function(key, value)
		return key == "Base" and 1 or value.name
	end) do
		local rulesetButton = parent:AddButton(ruleset.name)
		rulesetButton.SameLine = createdOne
		createdOne = true

		rulesetButton.IDContext = rulesetId
		local tooltip = ""
		if ruleset.description ~= "" then
			tooltip = ("\t" .. ruleset.description)
		end

		if ruleset.modId then
			if #tooltip > 0 then
				tooltip = tooltip .. "\n"
			end
			tooltip = tooltip .. ("\t From Mod %s - Can't Be Modified"):format(Ext.Mod.GetMod(ruleset.modId).Info.Name)
		end

		if tooltip ~= "" then
			rulesetButton:Tooltip():AddText(tooltip)
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
				local selectModifiersMenu
				if not ruleset.modId then
					selectModifiersMenu = customizeModifiersMenu:AddMenu("Select Modifiers")
				end

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
							---@type ResourceRulesetModifierOption[]
							local resourceModifierValues = {}
							for _, modifierValueId in pairs(Ext.StaticData.GetAll("RulesetModifierOption")) do
								---@type ResourceRulesetModifierOption
								local rulesetModifierValue = Ext.StaticData.Get(modifierValueId, "RulesetModifierOption")
								if rulesetModifierValue.Modifier == modifierId then
									table.insert(resourceModifierValues, rulesetModifierValue)
								end
							end
							table.sort(resourceModifierValues, function(a, b)
								return (a.DisplayName:Get() or a.Name) < (b.DisplayName:Get() or b.Name)
							end)

							---@type string[]
							local selectedModifiers = ruleset.activeModifiers[modifierId]

							for i, modifierOption in ipairs(resourceModifierValues) do
								local box = modifierGroup:AddCheckbox(modifierOption.DisplayName:Get() or modifierOption.Name,
									TableUtils:IndexOf(selectedModifiers, modifierOption.Name) ~= nil)

								box.IDContext = modifierOption.Name
								box.SameLine = i > 1
								box.OnChange = function()
									if box.Checked then
										table.insert(selectedModifiers, box.IDContext)
									else
										selectedModifiers[TableUtils:IndexOf(selectedModifiers, box.IDContext)] = nil
										TableUtils:ReindexNumericTable(selectedModifiers)
									end
								end
							end
						end
					end
				end
				buildCustomizer()

				if not ruleset.modId then
					for modifierName, modifierId in TableUtils:OrderedPairs(Lab_RulesetModifiers, function(_, value)
							---@type ResourceRulesetModifier
							local modifierResource = Ext.StaticData.Get(value, "RulesetModifier")
							return tostring(modifierResource.RulesetModifierType) .. (modifierResource.DisplayName:Get() or modifierResource.Name)
						end,
						function(key, value)
							return #value == 36
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
				end

				---@param select ExtuiSelectable
				self.popup:AddSelectable("Delete Ruleset", "DontClosePopups").OnClick = function(select)
					if select.Label ~= "Delete Ruleset" then
						self.config.rulesets[rulesetId].delete = true
						for _, folder in pairs(self.config.folders) do
							if not folder.modId then
								for _, encounter in pairs(folder.encounters) do
									for _, entity in pairs(encounter.entities) do
										if entity.rulesetModifiers[rulesetId] then
											entity.rulesetModifiers[rulesetId].delete = true
										end
									end
								end
							end
						end
						self:ManageRulesets(parent, rulesetSelectCallback)
					else
						select.Label = "Are You Sure?"
						Styler:Color(select, "ErrorText")
						select.DontClosePopups = false
					end
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

---@return MazzleDocsDocumentation
function MonsterLab:generateDocs()
	return {
		{
			Topic = "Monster Lab (ML)",
			content = {
				{
					type = "Heading",
					text = "Encounters"
				},
				{
					type = "CallOut",
					prefix = "Tips",
					text = "Always right click on a discrete component, like a folder, encounter, ruleset, or entity, to manage their properties (i.e. edit/delete them)",
					prefix_color = "Green"
				} --[[@as MazzleDocsCallOut]],
				{
					type = "Content",
					text = [[
Encounters are exactly what you'd expect - groups of entities that are linked together to form one combat group, or encounter.

You can have as many entities in an encounter as you'd like - just keep basic engine limitations in mind.

You create encounters under a dedicated folder in the Monster Lab tab in MCM - folders are just superficial organizational tools, same as with Mutations.

Within an encounter, you create an entity by giving it a dedicated Template, Name, and Title; each entity is given an unique ID by Lab, so you can give the same properties to as many entities as you'd like (i.e. 36 cranium rats :D).

You can also set some properties and assign Mutators to them according to different rulesets, but that's covered in the "Rulesets" section.

As of this writing, only statically-placed encounters are supported, the process of which is documented in the "Encounter Designer" section - in the future, you'll be able to create encounters that:
- Are trigger based (with custom triggers)
- Ambush the player's party anywhere in a map based on specified rules
and maybe more, depending on what I think of/what feedback I get.]]
				}
			}
		},
		{
			Topic = "Monster Lab (ML)",
			content = {
				{
					type = "Heading",
					text = "Static Encounter Designer"
				},
				{
					type = "CallOut",
					prefix = "Tips",
					prefix_color = "Green",
					text = "When using a in-world picker, middle-click to save the value, left/right-click to cancel and use the existing value"
				} --[[@as MazzleDocsCallOut]],
				{
					type = "Section",
					text = "The Designer, in context of an encounter, will:"
				},
				{
					type = "Bullet",
					text = {
						"close MCM when opened and reopen it upon being closed, closing all windows related to the Designer at the same time",
						"spawn all entities that haven't already been spawned by an active Monster Lab profile on launch and despawn on close - if an entity was already spawned by a profile, their properties will be updated the same way as if it had been spawned by the designer. It will not resurrect dead entities.",
						"update the properties of the spawned entities whenever a change is made",
						"block entities ability to enter combat until closed, allowing you to set conflicting factions without watching them die",
						"default to blocking the player's (and party's) ability to enter combat and dialogue, controlled by the toggles in the top-left. Note that blocking dialogue doesn't prevent you from triggering Triggers placed in the game world, which will often start cutscenes or force dialogue. Teleporting directly to an entity will usually bypass these, deending on the trigger.",
						"not execute ruleset behavior during the designer phase (but it also won't clear any mutators applied by an active ML + Mutation profile)"
					}
				} --[[@as MazzleDoctsBullet]],
				{
					type = "SubHeading",
					text = "Encounter-Level Settings"
				},
				{
					type = "Section",
					text = "Game Level and Base Coordinates"
				},
				{
					type = "Content",
					text = [[
These two settings are core to your encounter: What Game Level is it active in, and where in that map is it placed?

An encounter can only be statically placed in one spot - if you want the same encounter in multiple places, you'll have to clone it and place them seperately (do this after you've configured the Ruleset properties, covered in the "Rulesets" section).

If you select a level you aren't currently in, most of the buttons will be hidden, and a new Teleport button will appear next to the Level Dropdown to teleport you to that level - once you're in the correct level, you can use the coordinate picker to choose the base coordinate.

The base coordinates serve as the default coordinates for your entities, spawning them in a tightly-clustered group, and as the destination for the Teleport button that appears below the dropdown if you're in the correct level. When choosing your coordinates, an orb and moonbeam effect will trigger to help show you that location (thanks to Mazzle_Lib!)

If you want to attach your encounter to an existing one, click on the Twin Daggers icon in the same row as the Teleport Button - if you've run the Entity Recorder (button in the Inspector) as of Lab Version 1.8.0 (Monster Lab release), you'll see every recorded entity grouped by their shared CombatGroupId if applicable, along with a teleport button that will take you to that encounter (you can also copy entities from any level in the game to your encounter via this combat group window)

Once you've chosen your level and base coordinates, you can move on to the next section.]]
				},
				{
					type = "Section",
					text = "Extra Settings: Combat Group ID and Faction"
				},
				{
					type = "Content",
					text = [[
These two settings are available under the Comment looking button in the row under the Dropdown.

CombatGroupId is a random identifier set in the entity's CombatParticipant.CombatGroupID component, ensuring that when one entity enters combat, every entity with that same ID enters combat at the same time, regardless of how far away they are.
Lab will enforce the presence of a UUID for an encounter and set it for all entities under that encounter, as individual sight/hearing-based engagement is incredibly unreliable.

Factions are set in the Faction component of each entity, and control who they're friendly, neutral, and hostile towards. There are 971 factions in the base game, with various hierarchal depths, so there isn't search/selector functionality for this - by default, Lab will use (and force, if the value is cleared) the "Evil NPC" faction, making your entities always hostile to the player.
Keep in mind that factions can swap to being hostile/friendly towards the player just based on triggers - for example, the captured civilians on the Nautaloid will only become hostile when the correct button is pressed, but they all share the same faction and CombatGroupId.

You can search for factions via https://bg3.norbyte.dev/search?q=type%3Afactions or use Lab's Inspector to see what faction a given entity belongs to, but if you're looking to integrate your encounter with an existing one, there's an easier way - click on the True Strike icon above the input boxes and you can copy both CombatGroupId and Faction from an entity in the game world just by middle clicking them.

You may see entities within the same encounter have different Factions - these are usually hierarchal, which Larian went really, really in-depth with for some reason, but they should all bubble up to the same parent faction, so don't be concerned about that]]
				},
				{
					type = "SubHeading",
					text = "Entity-Level Settings"
				},
				{
					type = "Content",
					text = [[Most of the settings here are self-explanatory, or behave similarily to above, so here're the highlights:]]
				},
				{
					type = "Section",
					text = "Animations"
				},
				{
					type = "Content",
					text = [[
Basic Animations are set on the entity via `Osi.PlayAnimation({entityId}, {provided UUID})` and looping ones are set via
Osi.PlayLoopingAnimation({entityId},
						{startAnimation},
						{loopAnimation},
						{endAnimation},
						{loopVariation1},
						{loopVariation2},
						{loopVariation3},
						{loopVariation4})

I genuinely don't know anything about how, when, why, and what values work - I just exposed the option for those who do. There's no validation around this, and Osi doesn't throw errors if the command doesn't work (as long as it's syntatically valid), so either know what you're doing or be prepared for a _lot_ of experimenting and research.
]]
				},
				{
					type = "Section",
					text = "Rotation"
				},
				{
					type = "Content",
					text =
					[[Rotation in this game is weird - I offload the computations and implementation of that to Mazzle_Lib, which has to spawn an invisible object and use Osi to force the entity to look at it; because of this, there really isn't sensible math around rotation - just play around with it and see what works.]]
				}
			}
		},
		{
			Topic = "Monster Lab (ML)",
			content = {
				{
					type = "Heading",
					text = "Rulesets"
				},
				{
					type = "Section",
					text = "Foreword"
				},
				{
					type = "Content",
					text = [[
Rulesets are an advanced bit of customization for each entity within an encounter, for those wanting their encounter difficulties to match the player's settings - you can create rulesets for any combination of BG3's difficulty settings, like enemy power and free first-strikes, and that ruleset will only activate when ALL of its specified criteria are met.

When processing a profile, only rulesets that have been configured for an entity will be considered - this generally always means that all entities in an encounter will share the same ruleset, as they'll be auto-configured with defaults for an existing ruleset, but this ultimately ensures the entity is processed in the context it was configured for.

If two rulesets have the same criteria, one is randomly chosen - if two rulesets have common criteria, the one with more matched criteria will be chosen.

There is always an immutable Base criteria present, allowing all mods creating encounters to have a guaranteed fallback. This ruleset has no criteria, and will always be chosen if no other ruleet qualifies for the campaign the profile is active within.

If a difficulty setting is changed by the player, they need only save and reload, and Lab will adjust the spawned encounter to meet the new ruleset, if applicable.]]
				},
				{
					type = "Section",
					text = "What's Controlled By A Ruleset"
				},
				{
					type = "Content",
					text = [[
There are two main properties that are set per Ruleset - Whether the entity will spawn, and what (if any) Mutators will apply to them.

Configuring whether or not an entity will spawn is as easy as clicking the toggle - if disabled, it'll clear and hide the mutators section for that entity, and the entity will either not spawn or be deleted next time the ML profile is executed.

The mutators work exactly as in the Mutations tab - the ruleset is treated as a Mutation, selecting the relevant entity and only that entity for the configured mutators.

If there is an active Mutation profile and the entity is selected by mutations within that profile, the mutators specified in ML will be processed last - if you enable the Composable setting, this only means that the Mutation profile can't overwrite your mutator with a non-composable Mutation, but if you disable Composability, that means your mutators will automatically override the same types of mutators from the selected Mutations.
Regardless of whether you enable or disable Composability, any mutators specified in the applicable Mutation profile that aren't configured in your Entity's Ruleset (i.e. you have a Health mutator in your mutation profile but not your entity's ruleset), that mutator will always apply - you can't enforce that only your mutators should apply for the entity.

Keep in mind that only one ruleset is chosen for the whole encounter - so if you have one entity configured for the chosen custom ruleset, but another is only configured for the Base ruleset, that entity just won't have anything beyond the defaults applied to it.

You can copy ruleset properties between entities by right-clicking on the entity link in the main MCM window.

These rulesets are exported along with your profile, and made available to users if you packaged the export into a mod, but they won't be able to change/delete them, ensuring your customizations always apply in the intended scenarios.]]
				}
			}
		},
		{
			Topic = "Monster Lab (ML)",
			content = {
				{
					type = "Heading",
					text = "Profiles"
				},
				{
					type = "Content",
					text = [[
Profiles are a simple set of Encounters that should be active in each Game Level - you can view/edit your active profile by clicking on the Eye icon to the left of the profile dropdown, or by selecting a different profile in that dropdown.

You can edit Encounters directly within the profile view by simply clicking on the encounter's name - click on it again to hide that section.

Profiles can be set as the default the same way Mutation Profiles can - just click the gear icon to the right of the dropdown, choose your Profile, and mark as default. Setting the dropdown to "Disabled" and saving will prevent the chosen default from activating within that campaign.

Monster Lab Profiles are always executed before Mutation profiles to ensure that the spawned entities are mutated by an active Mutation Profile, and are triggered after the `LevelGameplayReady` Osi event fires.

Exporting/Importing a profile works exactly the same as Mutations, so go read that section under "Mutations/Profiles/Exporting Profiles and Everything Associated" - the only difference to note is that ML exports for mods using a different name: AbsolutesLaboratory_MonsterLab_ProfilesAndMutations.json under the MonsterLab directory.

The reasoning for this is that while Mutations will affect MonsterLab entities, the two are conceptually and technically independent functions of Lab that can be mixed and matched at will, so there's actually nothing tying them together - this gives users the freedom to import and export any set of profiles independently of each other, crafting unique but cohesive experiences at will.]]
				}
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function MonsterLab:generateChangelog()
	return {
		["1.8.0"] = {
			type = "Bullet",
			text = "Initial Release"
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
