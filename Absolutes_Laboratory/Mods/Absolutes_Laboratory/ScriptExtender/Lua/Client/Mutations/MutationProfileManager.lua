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
local activeProfileName

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
	--- @param tabHeader ExtuiTreeParent
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

		self.selectionParent:AddSeparatorText("Your Mutations"):SetStyle("SeparatorTextAlign", 0.5)

		self.userFolderGroup = self.selectionParent:AddGroup("User Folders")
		self.userFolderGroup.DragDropType = "MutationRules"
		self.userFolderGroup.OnDragDrop = function(group, dropped)
			for _, ele in pairs(group.Children) do
				---@cast ele ExtuiCollapsingHeader
				if ele.UserData == dropped.UserData.mutationFolder then
					for _, mutation in pairs(ele.Children) do
						---@cast mutation ExtuiSelectable

						if mutation.UserData.mutationName == dropped.UserData.mutationName then
							mutation.SelectableDisabled = false

							for _, mutationRule in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles[activeProfileName].mutationRules) do
								if mutationRule.mutationName == dropped.UserData.mutationName and mutationRule.mutationFolder == dropped.UserData.mutationFolder then
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

		self.profileManagerParent = nil
		Styler:MiddleAlignedColumnLayout(rightPanel, function(ele)
			self.profileManagerParent = ele
		end).SameLine = true

		rightPanel:AddSeparator()
		self.profileRulesParent = Styler:TwoColumnTable(rightPanel)
		self.profileRulesParent.Borders = false
		self.profileRulesParent.Resizable = false
		self.profileRulesParent.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()

		local profileRulesRow = self.profileRulesParent:AddRow()

		self.rulesOrderGroup = profileRulesRow:AddCell():AddChildWindow("RulesOrder")

		self.mutationDesigner = profileRulesRow:AddCell():AddChildWindow("MutationDesigner")
		local collapseExpandRulesOrderButton = self.mutationDesigner:AddButton("<<")
		collapseExpandRulesOrderButton.UserData = "keep"

		collapseExpandRulesOrderButton.OnClick = function()
			Helpers:CollapseExpand(
				collapseExpandRulesOrderButton.Label == "<<",
				300 * Styler:ScaleFactor(),
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
	if not activeProfileName then
		activeProfileName = Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile
	end

	activeMutationView = nil

	Helpers:KillChildren(self.userFolderGroup)

	local folders = ConfigurationStructure.config.mutations.folders

	for folderName, folder in TableUtils:OrderedPairs(folders) do
		local folderHeader = self.userFolderGroup:AddCollapsingHeader(folderName)
		folderHeader.UserData = folderName
		folderHeader:SetColor("Header", { 1, 1, 1, 0 })
		folderHeader:Tooltip():AddText("\t " .. folder.description)

		for mutationName, mutation in TableUtils:OrderedPairs(folder.mutations) do
			---@type ExtuiSelectable
			local mutationSelectable = folderHeader:AddSelectable(mutationName)
			mutationSelectable:Tooltip():AddText("\t " .. mutation.description)
			mutationSelectable.CanDrag = true
			mutationSelectable.DragDropType = "MutationRules"
			mutationSelectable.UserData = {
				mutationFolder = folderName,
				mutationName = mutationName
			}

			mutationSelectable.OnClick = function()
				Helpers:KillChildren(self.mutationDesigner)

				if activeMutationView then
					if activeMutationView.Handle then
						-- https://github.com/Norbyte/bg3se/blob/f8b982125c6c1997ceab2d65cfaa3c1a04908ea6/BG3Extender/Extender/Client/IMGUI/IMGUI.cpp#L1901C34-L1901C60
						activeMutationView:SetColor("Button", { 0.46, 0.40, 0.29, 0.5 })
					end
					activeMutationView = nil
				end

				Styler:MiddleAlignedColumnLayout(self.mutationDesigner, function(ele)
					ele:AddText(folderName .. "/" .. mutationName).Font = "Big"
				end)
				MutationDesigner:RenderMutationManager(self.mutationDesigner, mutation)
			end

			---@param selectable ExtuiSelectable
			---@param preview ExtuiTreeParent
			mutationSelectable.OnDragStart = function(selectable, preview)
				preview:AddText(selectable.Label)
			end

			if activeProfileName then
				if TableUtils:IndexOf(ConfigurationStructure.config.mutations.profiles[activeProfileName].mutationRules, function(mutationRule)
						return mutationRule.mutationFolder == folderName and mutationRule.mutationName == mutationName
					end) then
					mutationSelectable.SelectableDisabled = true
				end
			end
		end

		---@type ExtuiSelectable
		local createMutationButton = folderHeader:AddSelectable("Create Mutation")
		createMutationButton:SetStyle("SelectableTextAlign", 0.5)

		createMutationButton.OnClick = function()
			createMutationButton.Selected = false

			self.formBuilderWindow.Label = "Create a Mutation"
			Helpers:KillChildren(self.formBuilderWindow)
			self.formBuilderWindow.Open = true
			self.formBuilderWindow:SetFocus()

			FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
					folder.mutations[formResults.Name] = {
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
				ConfigurationStructure.config.mutations.folders[formResults.Name] = {
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

function MutationProfileManager:BuildProfileManager()
	local profiles = ConfigurationStructure.config.mutations.profiles
	Helpers:KillChildren(self.profileManagerParent, self.rulesOrderGroup, self.mutationDesigner)

	Styler:CheapTextAlign("Active Profile", self.profileManagerParent, "Large")
	local profileCombo = self.profileManagerParent:AddCombo("")
	profileCombo.WidthFitPreview = true

	local sIndex = -1
	local opt = {}
	for profileName in TableUtils:OrderedPairs(profiles) do
		table.insert(opt, profileName)
		if profileName == activeProfileName then
			sIndex = #opt
		end
	end
	profileCombo.Options = opt
	profileCombo.SelectedIndex = sIndex - 1
	profileCombo.OnChange = function()
		activeProfileName = profileCombo.Options[profileCombo.SelectedIndex + 1]

		Helpers:KillChildren(self.rulesOrderGroup, self.mutationDesigner)
		Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = activeProfileName
		self:BuildProfileView()
	end

	local createProfileButton = self.profileManagerParent:AddButton("+")
	createProfileButton.SameLine = true

	createProfileButton.OnClick = function()
		self.formBuilderWindow.Label = "Create a new Profile"
		Helpers:KillChildren(self.formBuilderWindow)
		self.formBuilderWindow.Open = true
		self.formBuilderWindow:SetFocus()

		FormBuilder:CreateForm(self.formBuilderWindow, function(formResults)
				profiles[formResults.Name] = {
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

				local profileName = formResults.Name
				activeProfileName = profileName
				Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = profileName

				self:BuildRuleManager()
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

	self:BuildRuleManager()
end

---@param lastMutationActive string?
function MutationProfileManager:BuildRuleManager(lastMutationActive)
	Helpers:KillChildren(self.rulesOrderGroup, self.mutationDesigner)
	activeMutationView = nil

	---@type MutationProfile
	local activeProfile
	if activeProfileName then
		activeProfile = ConfigurationStructure.config.mutations.profiles[activeProfileName]
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
							if ele.UserData == removeRule.mutationFolder then
								for _, mutation in pairs(ele.Children) do
									---@cast mutation ExtuiSelectable

									if mutation.UserData.mutationName == removeRule.mutationName then
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
					additive = false,
					mutationFolder = dropped.UserData.mutationFolder,
					mutationName = dropped.UserData.mutationName,
				}

				self:BuildRuleManager(activeMutationView and activeMutationView.Label)
			end

			local orderNumberInput = row:AddInputInt("##" .. counter, counter)
			orderNumberInput.AutoSelectAll = true
			orderNumberInput.ItemWidth = 40

			if activeProfile.mutationRules[counter] then
				local mutationRule = activeProfile.mutationRules[counter]

				orderNumberInput.OnDeactivate = function()
					if activeProfile.mutationRules[orderNumberInput.Value[1]] then
						local ruletoRemove = activeProfile.mutationRules[orderNumberInput.Value[1]]

						for _, ele in pairs(self.userFolderGroup.Children) do
							---@cast ele ExtuiCollapsingHeader
							if ele.UserData == ruletoRemove.mutationFolder then
								for _, mutation in pairs(ele.Children) do
									---@cast mutation ExtuiSelectable

									if mutation.UserData.mutationName == ruletoRemove.mutationName then
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

					self:BuildRuleManager(activeMutationView and activeMutationView.Label)
				end

				local mutationCell = row:AddButton(mutationRule.mutationFolder .. "/" .. mutationRule.mutationName)
				mutationCell.UserData = mutationRule._real
				mutationCell.SameLine = true
				mutationCell.CanDrag = true
				mutationCell.DragDropType = "MutationRules"

				local mutation = ConfigurationStructure.config.mutations.folders[mutationRule.mutationFolder].mutations[mutationRule.mutationName]
				if not mutation.selectors() or not mutation.mutators() then
					mutationCell:SetColor("Button", { 1, 0.02, 0, 0.4 })
					mutationCell:Tooltip():AddText("Missing a defined selector or mutator!")
				end

				---@param button ExtuiButton
				---@param preview ExtuiTreeParent
				mutationCell.OnDragStart = function(button, preview)
					preview:AddText(button.Label)
				end

				mutationCell.OnClick = function()
					Helpers:KillChildren(self.mutationDesigner)

					local mutation = ConfigurationStructure.config.mutations.folders[mutationRule.mutationFolder].mutations[mutationRule.mutationName]

					if activeMutationView then
						if activeMutationView.Handle then
							if not mutation.selectors() or not mutation.mutators() then
								mutationCell:SetColor("Button", { 1, 0.02, 0, 0.4 })
							else
								-- https://github.com/Norbyte/bg3se/blob/f8b982125c6c1997ceab2d65cfaa3c1a04908ea6/BG3Extender/Extender/Client/IMGUI/IMGUI.cpp#L1901C34-L1901C60
								activeMutationView:SetColor("Button", { 0.46, 0.40, 0.29, 0.5 })
							end

							if activeMutationView.Handle == mutationCell.Handle then
								activeMutationView = nil
								return
							end
						end
					end

					activeMutationView = mutationCell
					mutationCell:SetColor("Button", { 0.64, 0.40, 0.28, 0.5 })

					Styler:MiddleAlignedColumnLayout(self.mutationDesigner, function(ele)
						ele:AddText(mutationRule.mutationFolder .. "/" .. mutationRule.mutationName).Font = "Big"
					end).SameLine = true

					MutationDesigner:RenderMutationManager(self.mutationDesigner, mutation)
				end

				if mutationCell.Label == lastMutationActive then
					mutationCell:OnClick()
					activeMutationView = mutationCell
				end
			else
				orderNumberInput.Disabled = true

				local cell = row:AddButton((" "):rep(15) .. "##" .. counter)
				cell.SameLine = true
			end
		end
	end
end
