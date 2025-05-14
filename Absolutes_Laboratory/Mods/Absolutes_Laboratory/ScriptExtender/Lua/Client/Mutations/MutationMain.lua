MutationMain = {}

Ext.Require("Client/Mutations/MutationManager.lua")

---@type ExtuiWindow?
MutationMain.formBuilderWindow = nil

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		local parentTable = Styler:TwoColumnTable(tabHeader, "mutationsMain")

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

			mutationSelectable.OnClick = function ()
				self:BuildMutationDesigner(mutationName, mutation)
			end
		end

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

---@param name string
---@param mutation Mutation
function MutationMain:BuildMutationDesigner(name, mutation)
	Helpers:KillChildren(self.mutationParent)

	Styler:MiddleAlignedColumnLayout(self.mutationParent, function (ele)
		Styler:CheapTextAlign(name, ele)
		ele:AddText(mutation.description):SetStyle("Alpha", 0.75)
	end)

	MutationManager:RenderMutationManager(self.mutationParent, mutation)
end
