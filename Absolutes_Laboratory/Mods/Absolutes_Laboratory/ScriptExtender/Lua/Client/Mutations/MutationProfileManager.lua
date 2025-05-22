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

---@type string?
local activeProfileName

---@param parent ExtuiTreeParent?
function MutationProfileManager:init(parent)
	if not self.userFolderGroup then
		if not activeProfileName then
			activeProfileName = Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile
		end

		local parentTable = Styler:TwoColumnTable(parent, "mutationsMain")
		parentTable.Borders = false

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

							self:BuildRuleManager()
							return
						end
					end
				end
			end
		end

		local rightPanel = row:AddCell()
		self.profileManagerParent = nil
		Styler:MiddleAlignedColumnLayout(rightPanel, function(ele)
			self.profileManagerParent = ele
		end)

		self.profileRulesParent = Styler:TwoColumnTable(rightPanel)
		self.profileRulesParent.Borders = false
		self.profileRulesParent.Resizable = false
		self.profileRulesParent.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
		local profileRulesRow = self.profileRulesParent:AddRow()

		self.rulesOrderGroup = profileRulesRow:AddCell():AddChildWindow("RulesOrder")

		self.mutationDesigner = profileRulesRow:AddCell():AddChildWindow("MutationDesigner")
		self.formBuilderWindow = Ext.IMGUI.NewWindow("Create a Profile")
		self.formBuilderWindow:SetStyle("WindowMinSize", 250)
		self.formBuilderWindow.Open = false
		self.formBuilderWindow.Closeable = true
	end
end

---@type ExtuiButton?
local activeMutationView

---@param parent ExtuiTreeParent?
function MutationProfileManager:BuildProfileView(parent)
	self:init(parent)
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

function MutationProfileManager:BuildRuleManager()
	Helpers:KillChildren(self.rulesOrderGroup, self.mutationDesigner)
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
				self:BuildRuleManager()
			end

			row:AddText(tostring(counter) .. ".")

			if activeProfile.mutationRules[counter] then
				local mutationRule = activeProfile.mutationRules[counter]

				local mutationCell = row:AddButton(mutationRule.mutationFolder .. "/" .. mutationRule.mutationName)
				mutationCell.UserData = mutationRule._real
				mutationCell.SameLine = true
				mutationCell.CanDrag = true
				mutationCell.DragDropType = "MutationRules"
				---@param button ExtuiButton
				---@param preview ExtuiTreeParent
				mutationCell.OnDragStart = function(button, preview)
					preview:AddText(button.Label)
				end

				mutationCell.OnClick = function()
					Helpers:KillChildren(self.mutationDesigner)

					if activeMutationView then
						if activeMutationView.Handle then
							-- https://github.com/Norbyte/bg3se/blob/f8b982125c6c1997ceab2d65cfaa3c1a04908ea6/BG3Extender/Extender/Client/IMGUI/IMGUI.cpp#L1901C34-L1901C60
							activeMutationView:SetColor("Button", { 0.46, 0.40, 0.29, 0.5 })
							if activeMutationView.Handle == mutationCell.Handle then
								activeMutationView = nil
								return
							end
						end
					end

					activeMutationView = mutationCell
					mutationCell:SetColor("Button", { 0.64, 0.40, 0.28, 0.5 })

					local mutation = ConfigurationStructure.config.mutations.folders[mutationRule.mutationFolder].mutations[mutationRule.mutationName]
					MutationDesigner:RenderMutationManager(self.mutationDesigner, mutation)
				end
			else
				local cell = row:AddButton((" "):rep(15) .. "##" .. counter)
				cell.SameLine = true
			end
		end
	end
end
