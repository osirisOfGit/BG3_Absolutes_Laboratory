MutationProfileManager = {
	---@type ExtuiGroup
	selectionParent = nil,
	---@type ExtuiGroup
	userFolderGroup = nil,
	---@type ExtuiGroup
	profileGroup = nil
}

---@param parent ExtuiTreeParent
function MutationProfileManager:init(parent)
	if not self.userFolderGroup then
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

						if mutation.UserData.mutation == dropped.UserData.mutationName then
							mutation.SelectableDisabled = false
						end
					end
				end
			end
		end

		self.profileParent = row:AddCell()
	end
end

---@param parent ExtuiTreeParent
---@param activeProfileName string?
function MutationProfileManager:BuildProfileView(parent, activeProfileName)
	self:init(parent)
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
				folder = folderName,
				mutation = mutationName
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

	local profiles = ConfigurationStructure.config.mutations.profiles
	Helpers:KillChildren(self.profileParent)

	Styler:MiddleAlignedColumnLayout(self.profileParent, function(ele)
		ele:AddText("Active Profile")
		local profileCombo = ele:AddCombo("")
		profileCombo.SameLine = true
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
		profileCombo.SelectedIndex = sIndex
		profileCombo.OnChange = function()
			MutationProfileManager:BuildProfileManager(
				profiles[profileCombo.Options[profileCombo.SelectedIndex + 1]]
			)
		end

		if activeProfileName then
			MutationProfileManager:BuildProfileManager(profiles[activeProfileName])
		end

		local createProfileButton = ele:AddButton("+")
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
					self:BuildProfileManager(profiles[formResults.Name])
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
	end)
end

---@param activeProfle MutationProfile
function MutationProfileManager:BuildProfileManager(activeProfle)
	Helpers:KillChildren(self.profileParent)

	local counter = 0
	for _, mutationFolder in pairs(ConfigurationStructure.config.mutations.folders) do
		for _, _ in pairs(mutationFolder.mutations) do
			counter = counter + 1

			local row = self.profileParent:AddGroup("MutationGroup" .. counter)
			row.UserData = counter
			row.DragDropType = "MutationRules"
			row.OnDragDrop = function(cell, dropped)
				dropped.SelectableDisabled = true
				activeProfle.mutationRules[tonumber(cell.UserData)] = {
					additive = false,
					mutationFolder = dropped.UserData.folder,
					mutationName = dropped.UserData.mutation,
				}
				self:BuildProfileManager(activeProfle)
			end

			row:AddText(tostring(counter) .. ".")

			if activeProfle.mutationRules[counter] then
				local mutationRule = activeProfle.mutationRules[counter]

				local mutationCell = row:AddButton(mutationRule.mutationFolder .. "/" .. mutationRule.mutationName)
				mutationCell.UserData = mutationRule._real
				mutationCell.SameLine = true
				mutationCell.CanDrag = true
				mutationCell.DragDropType = "MutationRules"
				---@param button ExtuiButton
				---@param preview ExtuiTreeParent
				mutationCell.OnDragStart = function(button, preview)
					button.Disabled = true
					activeProfle.mutationRules[tonumber(row.UserData)].delete = true
				end
			else
				local cell = row:AddButton((" "):rep(15) .. "##" .. counter)
				cell.SameLine = true
			end
		end
	end
end
