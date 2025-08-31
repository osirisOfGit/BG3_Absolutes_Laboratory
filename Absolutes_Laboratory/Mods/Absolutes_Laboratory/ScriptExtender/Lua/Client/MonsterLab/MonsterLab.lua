Ext.Require("Client/MonsterLab/ExistingEncounters.lua")

MonsterLab = {
	config = ConfigurationStructure.config.monsterLab
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
		header.UserData = folderId

		for encounterId, encounter in TableUtils:OrderedPairs(folder.encounters, function(key, value)
			return value.name
		end) do
			---@type ExtuiSelectable
			local encounterSelect = header:AddSelectable(encounter.name .. "##" .. encounterId)
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
						entities = {}
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
