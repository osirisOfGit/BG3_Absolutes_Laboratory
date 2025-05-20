MutationMain = {}

---@type "Designer"|"Profiles"
MutationMain.ActiveTab = "Designer"

Ext.Require("Client/Mutations/MutationDesigner.lua")
Ext.Require("Client/Mutations/MutationProfileManager.lua")

---@type ExtuiWindow?
MutationMain.formBuilderWindow = nil

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		local mutationTab = tabHeader:AddTabBar("Mutations")

		local designerTab = mutationTab:AddTabItem("Designer")
		designerTab.OnActivate = function()
			MutationMain.ActiveTab = "Designer"
			MutationMain:BuildUserFolders()
		end
		designerTab:Activate()
		mutationTab:AddTabItem("Profiles").OnActivate = function()
			MutationMain.ActiveTab = "Profiles"
			MutationMain:BuildUserFolders()
			MutationMain:BuildProfileManager()
		end

		local parentTable = Styler:TwoColumnTable(tabHeader, "mutationsMain")
		parentTable.Borders = false

		local row = parentTable:AddRow()

		MutationMain.selectionParent = row:AddCell():AddChildWindow("selectionParent")

		MutationMain.selectionParent:AddSeparatorText("Your Mutations"):SetStyle("SeparatorTextAlign", 0.5)
		MutationMain.userFolderGroup = MutationMain.selectionParent:AddGroup("User Folders")

		MutationMain.mutationParent = row:AddCell()

		MutationMain.formBuilderWindow = Ext.IMGUI.NewWindow("Create a Folder")
		MutationMain.formBuilderWindow:SetStyle("WindowMinSize", 250)
		MutationMain.formBuilderWindow.Open = false
		MutationMain.formBuilderWindow.Closeable = true

		MutationMain:BuildUserFolders()
	end)


function MutationMain:BuildUserFolders()
	Helpers:KillChildren(self.userFolderGroup)

	local folders = ConfigurationStructure.config.mutations.folders

	for folderName, folder in TableUtils:OrderedPairs(folders) do
		local folderHeader = self.userFolderGroup:AddCollapsingHeader(folderName)
		folderHeader:SetColor("Header", { 1, 1, 1, 0 })
		folderHeader:Tooltip():AddText("\t " .. folder.description)

		for mutationName, mutation in TableUtils:OrderedPairs(folder.mutations) do
			---@type ExtuiSelectable
			local mutationSelectable = folderHeader:AddSelectable(mutationName)
			mutationSelectable:Tooltip():AddText("\t " .. mutation.description)
			if self.ActiveTab == "Designer" then
				mutationSelectable.OnClick = function()
					self:BuildMutationDesigner(mutationName, mutation)
				end
			else
				mutationSelectable.CanDrag = true
				mutationSelectable.DragDropType = folderName .. "/" .. mutationName
				mutationSelectable.UserData = {
					folder = folderName,
					mutation = mutationName
				}
				mutationSelectable.OnDragStart = function (selectable, preview)
					_D("Started dragging" .. mutationName)
				end
			end
		end

		if self.ActiveTab == "Designer" then
			folderHeader:AddNewLine()

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
						self:BuildUserFolders()
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
	end

	if self.ActiveTab == "Designer" then
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
					self:BuildUserFolders()
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
end

---@param name string
---@param mutation Mutation
function MutationMain:BuildMutationDesigner(name, mutation)
	Helpers:KillChildren(self.mutationParent)

	Styler:MiddleAlignedColumnLayout(self.mutationParent, function(ele)
		Styler:CheapTextAlign(name, ele)
		ele:AddText(mutation.description):SetStyle("Alpha", 0.75)
	end)

	MutationManager:RenderMutationManager(self.mutationParent, mutation)
end

---@param activeProfileName string?
function MutationMain:BuildProfileManager(activeProfileName)
	local profiles = ConfigurationStructure.config.mutations.profiles
	Helpers:KillChildren(self.mutationParent)

	Styler:MiddleAlignedColumnLayout(self.mutationParent, function(ele)
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
				self.mutationParent,
				profiles[profileCombo.Options[profileCombo.SelectedIndex + 1]]
			)
		end

		if activeProfileName then
			MutationProfileManager:BuildProfileManager(self.mutationParent, profiles[activeProfileName])
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
					self:BuildProfileManager(formResults.Name)
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
