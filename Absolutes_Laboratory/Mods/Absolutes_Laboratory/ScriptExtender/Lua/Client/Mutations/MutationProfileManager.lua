Ext.Vars.RegisterModVariable(ModuleUUID, "ActiveMutationProfile", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

MutationProfileManager = {
	---@type ExtuiGroup
	selectionParent = nil,
	---@type ExtuiGroup
	userFolderGroup = nil,
	---@type ExtuiGroup
	profileGroup = nil,
	---@type ExtuiWindow?
	formBuilderWindow = nil
}

Ext.Require("Client/Mutations/MutationDesigner.lua")

---@type string?
local activeProfileId

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
	--- @param tabHeader ExtuiTabItem
	function(tabHeader)
		MutationProfileManager:init(tabHeader)
		MutationProfileManager:BuildProfileView()
	end)

---@type ExtuiButton?
local activeMutationView

---@param parent ExtuiTreeParent
function MutationProfileManager:init(parent)
	if not self.userFolderGroup then
		local parentTable = Styler:TwoColumnTable(parent, "mutationsMain")
		parentTable.Borders = false
		parentTable.Resizable = false
		parentTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()

		local row = parentTable:AddRow()

		self.selectionParent = row:AddCell():AddChildWindow("selectionParent")

		local userMutSep = self.selectionParent:AddSeparatorText("Your Mutations ( ? )")
		userMutSep:SetStyle("SeparatorTextAlign", 0.5)
		userMutSep:Tooltip():AddText("\t Ctrl-click on mutations to edit their details or delete them - use the Manage Folder button to create mutations")

		self.userFolderGroup = self.selectionParent:AddGroup("User Folders")
		self.userFolderGroup.DragDropType = "MutationRules"
		self.userFolderGroup.OnDragDrop = function(group, dropped)
			for _, ele in pairs(group.Children) do
				---@cast ele ExtuiTree
				if ele.UserData == dropped.UserData.mutationFolderId then
					for _, mutation in pairs(ele.Children) do
						---@cast mutation ExtuiSelectable

						if mutation.UserData and mutation.UserData.mutationId == dropped.UserData.mutationId then
							mutation.SelectableDisabled = false

							for _, mutationRule in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles[activeProfileId].mutationRules) do
								if mutationRule.mutationId == dropped.UserData.mutationId and mutationRule.mutationFolderId == dropped.UserData.mutationFolderId then
									mutationRule.delete = true
									break
								end
							end

							activeMutationView = nil
							self:BuildRuleManager()
							return
						end
					end
				end
			end
		end

		local rightPanel = row:AddCell()
		local collapseExpandUserFoldersButton = rightPanel:AddButton("<<")
		collapseExpandUserFoldersButton.OnClick = function()
			Helpers:CollapseExpand(
				collapseExpandUserFoldersButton.Label == "<<",
				300 * Styler:ScaleFactor(),
				function(width)
					if width then
						parentTable.ColumnDefs[1].Width = width
					end
					return parentTable.ColumnDefs[1].Width
				end,
				self.selectionParent,
				function()
					if collapseExpandUserFoldersButton.Label == "<<" then
						collapseExpandUserFoldersButton.Label = ">>"
					else
						collapseExpandUserFoldersButton.Label = "<<"
					end
				end)
		end

		rightPanel:AddSeparator()
		self.profileRulesParent = Styler:TwoColumnTable(rightPanel)
		self.profileRulesParent.Borders = false
		self.profileRulesParent.Resizable = false
		self.profileRulesParent.ColumnDefs[1].Width = 400 * Styler:ScaleFactor()

		local profileRulesRow = self.profileRulesParent:AddRow()

		self.rulesOrderGroup = profileRulesRow:AddCell():AddChildWindow("RulesOrder")
		self.profileManagerParent = nil
		Styler:MiddleAlignedColumnLayout(self.rulesOrderGroup, function(ele)
			self.profileManagerParent = ele
		end).UserData = "keep"

		self.mutationDesigner = profileRulesRow:AddCell():AddChildWindow("MutationDesigner")
		local collapseExpandRulesOrderButton = self.mutationDesigner:AddButton("<<")
		collapseExpandRulesOrderButton.UserData = "keep"

		collapseExpandRulesOrderButton.OnClick = function()
			Helpers:CollapseExpand(
				collapseExpandRulesOrderButton.Label == "<<",
				400 * Styler:ScaleFactor(),
				function(width)
					if width then
						self.profileRulesParent.ColumnDefs[1].Width = width
					end
					return self.profileRulesParent.ColumnDefs[1].Width
				end,
				self.rulesOrderGroup,
				function()
					if collapseExpandRulesOrderButton.Label == "<<" then
						collapseExpandRulesOrderButton.Label = ">>"
					else
						collapseExpandRulesOrderButton.Label = "<<"
					end
				end)
		end

		self.formBuilderWindow = Ext.IMGUI.NewWindow("Create a Profile")
		self.formBuilderWindow:SetStyle("WindowMinSize", 250)
		self.formBuilderWindow.Open = false
		self.formBuilderWindow.Closeable = true
	end
end

function MutationProfileManager:BuildProfileView()
	activeMutationView = nil

	Helpers:KillChildren(self.userFolderGroup)

	local folders = ConfigurationStructure.config.mutations.folders

	for folderId, folder in TableUtils:OrderedPairs(folders) do
		local folderHeader = self.userFolderGroup:AddTree(folder.name)
		folderHeader.UserData = folderId
		folderHeader:SetColor("Header", { 1, 1, 1, 0 })
		if folder.description ~= "" then
			folderHeader:Tooltip():AddText("\t " .. folder.description)
		end

		local folderPopup = folderHeader:AddPopup(folderId)

		folderPopup:AddSelectable("Create a Mutation").OnClick = function(selectable)
			self.formBuilderWindow.Label = "Create a Mutation"
			Helpers:KillChildren(self.formBuilderWindow)
			self.formBuilderWindow.Open = true
			self.formBuilderWindow:SetFocus()

			FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
					folder.mutations[FormBuilder:generateGUID()] = {
						name = formResults.Name,
						description = formResults.Description,
						selectors = {},
						mutators = {}
					} --[[@as Mutation]]

					self.formBuilderWindow.Open = false
					self:BuildProfileView()
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
				}
			)
		end

		---@param selectable ExtuiSelectable
		folderPopup:AddSelectable("Edit Details").OnClick = function(selectable)
			self.formBuilderWindow.Label = "Edit Folder " .. folder.name
			Helpers:KillChildren(self.formBuilderWindow)
			self.formBuilderWindow.Open = true
			self.formBuilderWindow:SetFocus()

			FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
					folder.name = formResults.Name
					folder.description = formResults.Description

					self.formBuilderWindow.Open = false
					self:BuildProfileView()
				end,
				{
					{
						label = "Name",
						type = "Text",
						errorMessageIfEmpty = "Required Field",
						defaultValue = folder.name
					},
					{
						label = "Description",
						type = "Multiline",
						defaultValue = folder.description
					}
				}
			)
		end

		folderPopup:AddSelectable("Delete Folder (and Mutations)").OnClick = function()
			folder.delete = true

			for _, profile in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles) do
				for _, mutRule in TableUtils:OrderedPairs(profile.mutationRules) do
					if mutRule.mutationFolderId == folderId then
						mutRule.delete = true
					end
				end
			end

			self:BuildProfileView()
		end

		for mutationId, mutation in TableUtils:OrderedPairs(folder.mutations) do
			---@type ExtuiSelectable
			local mutationSelectable = folderHeader:AddSelectable(mutation.name)
			if mutation.description ~= "" then
				mutationSelectable:Tooltip():AddText("\t " .. mutation.description)
			end
			mutationSelectable.CanDrag = true
			mutationSelectable.DragDropType = "MutationRules"
			mutationSelectable.UserData = {
				mutationFolderId = folderId,
				mutationId = mutationId
			}

			local mutationPopup = folderHeader:AddPopup(mutationId)
			mutationPopup:AddSelectable("Delete").OnClick = function()
				mutation.delete = true

				for _, profile in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles) do
					for _, mutRule in TableUtils:OrderedPairs(profile.mutationRules) do
						if mutRule.mutationFolderId == folderId and mutRule.mutationId == mutationId then
							mutRule.delete = true
						end
					end
				end

				self:BuildProfileView()
			end

			mutationPopup:AddSelectable("Edit Details").OnClick = function()
				self.formBuilderWindow.Label = "Edit " .. mutation.name
				Helpers:KillChildren(self.formBuilderWindow)
				self.formBuilderWindow.Open = true
				self.formBuilderWindow:SetFocus()

				FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
						mutation.name = formResults.Name
						mutation.description = formResults.Description

						self.formBuilderWindow.Open = false
						self:BuildProfileView()
					end,
					{
						{
							label = "Name",
							type = "Text",
							errorMessageIfEmpty = "Required Field",
							defaultValue = mutation.name
						},
						{
							label = "Description",
							type = "Multiline",
							defaultValue = mutation.description
						}
					}
				)
			end

			if TableUtils:CountElements(folders) > 1 then
				local movePopup = mutationPopup:AddPopup(mutationId .. "Move")
				for otherfolderId, otherFolder in TableUtils:OrderedPairs(folders) do
					if otherfolderId ~= folderId then
						movePopup:AddSelectable(otherFolder.name).OnClick = function()
							otherFolder.mutations[mutationId] = mutation._real
							mutation.delete = true
							for _, profile in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles) do
								for _, mutRule in TableUtils:OrderedPairs(profile.mutationRules) do
									if mutRule.mutationFolderId == folderId and mutRule.mutationId == mutationId then
										mutRule.mutationFolderId = otherfolderId
									end
								end
							end
							self:BuildProfileView()
						end
					end
				end
				mutationPopup:AddSelectable("Move To Folder", "DontClosePopups").OnClick = function()
					movePopup:Open()
				end
			end

			mutationSelectable.OnClick = function()
				if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
					mutationPopup:Open()
				else
					Helpers:KillChildren(self.mutationDesigner)

					if activeMutationView then
						if activeMutationView.Handle then
							-- https://github.com/Norbyte/bg3se/blob/f8b982125c6c1997ceab2d65cfaa3c1a04908ea6/BG3Extender/Extender/Client/IMGUI/IMGUI.cpp#L1901C34-L1901C60
							activeMutationView:SetColor("Button", { 0.46, 0.40, 0.29, 0.5 })
						end
						activeMutationView = nil
					end

					Styler:MiddleAlignedColumnLayout(self.mutationDesigner, function(ele)
						ele:AddText(folder.name .. "/" .. mutation.name).Font = "Big"
					end)
					MutationDesigner:RenderMutationManager(self.mutationDesigner, mutation)
				end
			end

			---@param selectable ExtuiSelectable
			---@param preview ExtuiTreeParent
			mutationSelectable.OnDragStart = function(selectable, preview)
				preview:AddText(selectable.Label)
			end

			if activeProfileId and ConfigurationStructure.config.mutations.profiles[activeProfileId] then
				if TableUtils:IndexOf(ConfigurationStructure.config.mutations.profiles[activeProfileId].mutationRules, function(mutationRule)
						return mutationRule.mutationFolderId == folderId and mutationRule.mutationId == mutationId
					end)
				then
					mutationSelectable.SelectableDisabled = true
				end
			end
		end

		---@type ExtuiSelectable
		local manageFolderButton = folderHeader:AddSelectable("Manage Folder##" .. folderId)
		manageFolderButton:SetStyle("SelectableTextAlign", 0.5)

		manageFolderButton.OnClick = function()
			manageFolderButton.Selected = false
			folderPopup:Open()
		end

		self.userFolderGroup:AddNewLine()
	end
	self.userFolderGroup:AddNewLine()

	---@type ExtuiSelectable
	local createFolderButton = self.userFolderGroup:AddSelectable("Create Folder")
	createFolderButton:SetStyle("SelectableTextAlign", 0.5)

	createFolderButton.OnClick = function()
		createFolderButton.Selected = false

		self.formBuilderWindow.Label = "Create a Folder"
		Helpers:KillChildren(self.formBuilderWindow)
		self.formBuilderWindow.Open = true
		self.formBuilderWindow:SetFocus()

		FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
				ConfigurationStructure.config.mutations.folders[FormBuilder:generateGUID()] = {
					name = formResults.Name,
					description = formResults.Description,
					mutations = {}
				} --[[@as MutationFolder]]

				self.formBuilderWindow.Open = false
				self:BuildProfileView()
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
			}
		)
	end

	self:BuildProfileManager()
end

local triedOnce
function MutationProfileManager:BuildProfileManager()
	if not activeProfileId and not triedOnce then
		triedOnce = true
		Ext.Timer.WaitFor(1000, function()
			activeProfileId = Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile
			if not ConfigurationStructure.config.mutations.profiles[activeProfileId] then
				Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = nil
				activeProfileId = nil
			end
			self:BuildProfileView()
		end)
		return
	end

	local lastMutation = activeMutationView and activeMutationView.Label
	activeMutationView = nil
	local profiles = ConfigurationStructure.config.mutations.profiles
	Helpers:KillChildren(self.profileManagerParent, self.rulesOrderGroup, self.mutationDesigner)

	Styler:CheapTextAlign("Active Profile", self.profileManagerParent, "Large")

	local profileCombo = self.profileManagerParent:AddCombo("")
	profileCombo.WidthFitPreview = true

	local sIndex = -1
	local opt = {}
	for profileId, profile in TableUtils:OrderedPairs(profiles) do
		table.insert(opt, profile.name)
		if activeProfileId == profileId then
			sIndex = #opt
		end
	end
	profileCombo.Options = opt
	profileCombo.SelectedIndex = sIndex - 1
	profileCombo.OnChange = function()
		activeProfileId = TableUtils:IndexOf(profiles, function(value)
			return value.name == profileCombo.Options[profileCombo.SelectedIndex + 1]
		end)
		Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = activeProfileId

		Helpers:KillChildren(self.rulesOrderGroup, self.mutationDesigner)
		self:BuildProfileView()
	end

	local manageProfileButton = Styler:ImageButton(self.profileManagerParent:AddImageButton("Manage", "ico_edit_d", { 32, 32 }))
	manageProfileButton.SameLine = true
	local manageProfilePopup = self.profileManagerParent:AddPopup("Manage Profiles")

	manageProfilePopup:AddSelectable("Create Profile").OnClick = function()
		self.formBuilderWindow.Label = "Create a new Profile"
		Helpers:KillChildren(self.formBuilderWindow)
		self.formBuilderWindow.Open = true
		self.formBuilderWindow:SetFocus()

		FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
				local profileId = FormBuilder:generateGUID()
				profiles[profileId] = {
					name = formResults.Name,
					description = formResults.Description,
					defaultActive = formResults.defaultActive,
					mutationRules = {}
				} --[[@as MutationProfile]]

				if formResults.defaultActive then
					for name, profile in pairs(profiles) do
						if name ~= formResults.Name then
							profile.defaultActive = false
						end
					end
				end
				self.formBuilderWindow.Open = false

				activeProfileId = profileId
				Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = profileId

				self:BuildProfileManager()
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
				},
				{
					label = "Active By Default for New Games?",
					propertyField = "defaultActive",
					type = "Checkbox",
					defaultValue = false
				}
			}
		)
	end

	for profileId, profile in TableUtils:OrderedPairs(profiles) do
		---@type ExtuiMenu
		local profileMenu = manageProfilePopup:AddMenu(profile.name)
		profileMenu:AddItem("Edit").OnClick = function()
			self.formBuilderWindow.Label = "Edit " .. profileId
			Helpers:KillChildren(self.formBuilderWindow)
			self.formBuilderWindow.Open = true
			self.formBuilderWindow:SetFocus()
			FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
					profile.name = formResults.Name
					profile.description = formResults.Description
					profile.defaultActive = formResults.defaultActive

					if formResults.defaultActive then
						for id, profile in pairs(profiles) do
							if id ~= profileId then
								profile.defaultActive = false
							end
						end
					end

					self.formBuilderWindow.Open = false

					self:BuildProfileManager()
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
					},
					{
						label = "Active By Default for New Games?",
						propertyField = "defaultActive",
						type = "Checkbox",
						defaultValue = profile.defaultActive
					}
				}
			)
		end
		profileMenu:AddItem("Delete").OnClick = function()
			profile.delete = true
			if activeProfileId == profileId then
				activeProfileId = nil
				Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = activeProfileId
			end
			self:BuildProfileManager()
		end
	end

	manageProfileButton.OnClick = function()
		manageProfilePopup:Open()
	end

	self:BuildRuleManager(lastMutation)
end

---@param lastMutationActive string?
function MutationProfileManager:BuildRuleManager(lastMutationActive)
	Helpers:KillChildren(self.rulesOrderGroup, self.mutationDesigner)
	activeMutationView = nil

	---@type MutationProfile
	local activeProfile
	if activeProfileId then
		activeProfile = ConfigurationStructure.config.mutations.profiles[activeProfileId]
	else
		return
	end

	local counter = 0
	for _, mutationFolder in pairs(ConfigurationStructure.config.mutations.folders) do
		for _, _ in pairs(mutationFolder.mutations) do
			counter = counter + 1

			local row = self.rulesOrderGroup:AddGroup("MutationGroup" .. counter)
			row.UserData = counter
			row.DragDropType = "MutationRules"
			---@param row ExtuiGroup
			---@param dropped ExtuiSelectable|ExtuiButton
			row.OnDragDrop = function(row, dropped)
				if tonumber(dropped.ParentElement.UserData) then
					activeProfile.mutationRules[dropped.ParentElement.UserData].delete = true
					if activeProfile.mutationRules[row.UserData] then
						activeProfile.mutationRules[dropped.ParentElement.UserData] = activeProfile.mutationRules[row.UserData]._real
					end
				else
					dropped.SelectableDisabled = true

					if activeProfile.mutationRules[row.UserData] then
						local removeRule = activeProfile.mutationRules[row.UserData]
						for _, ele in pairs(self.userFolderGroup.Children) do
							---@cast ele ExtuiCollapsingHeader
							if ele.UserData == removeRule.mutationFolderId then
								for _, mutation in pairs(ele.Children) do
									---@cast mutation ExtuiSelectable

									if mutation.UserData and mutation.UserData.mutationId == removeRule.mutationId then
										mutation.SelectableDisabled = false
										goto continue
									end
								end
							end
						end
						::continue::
					end
				end

				if activeProfile.mutationRules[row.UserData] then
					activeProfile.mutationRules[row.UserData].delete = true
				end

				activeProfile.mutationRules[row.UserData] = {
					additive = dropped.UserData.additive,
					mutationFolderId = dropped.UserData.mutationFolderId,
					mutationId = dropped.UserData.mutationId,
				}

				self:BuildRuleManager(activeMutationView and activeMutationView.Label)
			end

			local orderNumberInput = row:AddInputInt("##" .. counter, counter)
			orderNumberInput.AutoSelectAll = true
			orderNumberInput.ItemWidth = 40

			if activeProfile and activeProfile.mutationRules[counter] then
				local mutationRule = activeProfile.mutationRules[counter]

				orderNumberInput.OnDeactivate = function()
					if orderNumberInput.Value[1] ~= row.UserData then
						if orderNumberInput.Value[1] <= counter and orderNumberInput.Value[1] > 0 then
							if activeProfile.mutationRules[orderNumberInput.Value[1]] then
								local ruletoRemove = activeProfile.mutationRules[orderNumberInput.Value[1]]

								for _, ele in pairs(self.userFolderGroup.Children) do
									---@cast ele ExtuiCollapsingHeader
									if ele.UserData == ruletoRemove.mutationFolderId then
										for _, mutation in pairs(ele.Children) do
											---@cast mutation ExtuiSelectable

											if mutation.UserData and mutation.UserData.mutationId == ruletoRemove.mutationId then
												mutation.SelectableDisabled = false
												goto continue
											end
										end
									end
								end
								::continue::

								ruletoRemove.delete = true
							end

							activeProfile.mutationRules[orderNumberInput.Value[1]] = mutationRule._real
							mutationRule.delete = true
						end

						self:BuildRuleManager(activeMutationView and activeMutationView.Label)
					end
				end

				local folders = ConfigurationStructure.config.mutations.folders

				local mutationButton = row:AddButton(folders[mutationRule.mutationFolderId].name ..
					"/" .. folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId].name)

				mutationButton.UserData = mutationRule._real
				mutationButton.SameLine = true
				mutationButton.CanDrag = true
				mutationButton.DragDropType = "MutationRules"

				local mutation = folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId]
				if not mutation.selectors() or not mutation.mutators() then
					mutationButton:SetColor("Button", { 1, 0.02, 0, 0.4 })
					mutationButton:Tooltip():AddText("Missing a defined selector or mutator!")
				end

				---@param button ExtuiButton
				---@param preview ExtuiTreeParent
				mutationButton.OnDragStart = function(button, preview)
					preview:AddText(button.Label)
				end

				mutationButton.OnClick = function()
					if Ext.ClientInput.GetInputManager().PressedModifiers == "Ctrl" then
						for _, ele in pairs(self.userFolderGroup.Children) do
							---@cast ele ExtuiCollapsingHeader
							if ele.UserData == mutationRule.mutationFolderId then
								for _, mutation in pairs(ele.Children) do
									---@cast mutation ExtuiSelectable

									if mutation.UserData and mutation.UserData.mutationId == mutationRule.mutationId then
										mutation:OnClick()
										return
									end
								end
							end
						end
					else
						Helpers:KillChildren(self.mutationDesigner)

						local mutation = folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId]

						if not mutation.selectors() or not mutation.mutators() then
							mutationButton:SetColor("Button", { 1, 0.02, 0, 0.4 })
						end

						if activeMutationView then
							if activeMutationView.Handle then
								---@type MutationProfileRule
								local activeMutationRule = activeMutationView.UserData
								local mutationConfig = folders[activeMutationRule.mutationFolderId].mutations[activeMutationRule.mutationId]

								if not mutationConfig.selectors() or not mutationConfig.mutators() then
									activeMutationView:SetColor("Button", { 1, 0.02, 0, 0.4 })
								else
									-- https://github.com/Norbyte/bg3se/blob/f8b982125c6c1997ceab2d65cfaa3c1a04908ea6/BG3Extender/Extender/Client/IMGUI/IMGUI.cpp#L1901C34-L1901C60
									activeMutationView:SetColor("Button", { 0.46, 0.40, 0.29, 0.5 })
								end

								if activeMutationView.Handle == mutationButton.Handle then
									activeMutationView = nil
									return
								end
							end
						end

						activeMutationView = mutationButton
						mutationButton:SetColor("Button", { 0.64, 0.40, 0.28, 0.5 })

						Styler:MiddleAlignedColumnLayout(self.mutationDesigner, function(ele)
							ele:AddText(folders[mutationRule.mutationFolderId].name ..
								"/" .. folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId].name).Font = "Big"
						end).SameLine = true

						MutationDesigner:RenderMutationManager(self.mutationDesigner, mutation)
					end
				end

				if mutationButton.Label == lastMutationActive then
					mutationButton:OnClick()
					activeMutationView = mutationButton
				end

				if TableUtils:IndexOf(mutation.mutators, function(value)
						return MutatorInterface.registeredMutators[value.targetProperty]:canBeAdditive(value)
					end)
				then
					local additiveCheckbox = row:AddCheckbox("", mutationRule.additive)
					additiveCheckbox:Tooltip():AddText(
						"\t If checked, relevant mutators under this mutation will be _additive_, meaning they will be combined with any mutators of the same type that are applicable from mutations earlier in the flow.\n If unchecked, mutators of the same type from earlier mutations will be replaced with these.")

					additiveCheckbox.SameLine = true
					additiveCheckbox.OnChange = function()
						mutationRule.additive = additiveCheckbox.Checked
					end
				end
			else
				orderNumberInput.Disabled = true

				local cell = row:AddButton((" "):rep(15) .. "##" .. counter)
				cell.SameLine = true
			end
		end
	end
end
