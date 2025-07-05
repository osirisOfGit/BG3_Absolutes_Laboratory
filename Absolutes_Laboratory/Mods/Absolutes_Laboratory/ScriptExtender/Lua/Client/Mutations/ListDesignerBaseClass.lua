---@class ListDesignerBaseClass
ListDesignerBaseClass = {
	name = "List Designer",
	---@type string
	configKey = nil,
	---@type ExtuiWindow
	formWindow = nil,
	---@type ExtuiWindow
	mainWindow = nil,
	---@type ExtuiTable
	layoutTable = nil,
	---@type ExtuiChildWindow
	listSection = nil,
	---@type ExtuiChildWindow
	designerSection = nil,
	---@type ExtuiChildWindow
	browserSection = nil,

	---@type string[]?
	progressionLinkedNodes = {},
	---@type ExtuiSelectable?
	activeListHandle = nil,
	---@type CustomList?
	activeList = nil,
}

---@param name string
---@return ListDesignerBaseClass
function ListDesignerBaseClass:new(name, configKey, progressionLinkedNodes)
	local instance = {}

	setmetatable(instance, self)
	self.__index = self
	self.name = name
	self.configKey = configKey
	self.progressionLinkedNodes = progressionLinkedNodes

	return instance
end

---@param activeListId Guid?
function ListDesignerBaseClass:launch(activeListId)
	if not self.mainWindow then
		self.mainWindow = Ext.IMGUI.NewWindow(self.name)
		self.mainWindow.Closeable = true
		self.mainWindow:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 150 * Styler:ScaleFactor())

		self.layoutTable = self.mainWindow:AddTable(self.name, 3)
		self.layoutTable.Resizable = true
		self.layoutTable.NoSavedSettings = true
		self.layoutTable:AddColumn("ListSection", "WidthFixed")
		self.layoutTable:AddColumn("", "WidthStretch")
		self.layoutTable:AddColumn("BrowserSection", "WidthFixed")
		self.layoutTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()
		self.layoutTable.ColumnDefs[3].Width = 400 * Styler:ScaleFactor()

		local row = self.layoutTable:AddRow()

		self.listSection = row:AddCell():AddChildWindow("List")
		self.designerSection = row:AddCell():AddChildWindow("Designer")
		self.browserSection = row:AddCell():AddChildWindow("Browser")

		self.formWindow = Ext.IMGUI.NewWindow("List Form")
		self.formWindow.Closeable = true
		self.formWindow.AlwaysAutoResize = true
	else
		Helpers:KillChildren(self.listSection, self.designerSection)
		self.activeListHandle = nil

		self.mainWindow.Open = true
		self.mainWindow:SetFocus()
	end

	self:buildLists(activeListId)
end

---@param activeListId Guid?
function ListDesignerBaseClass:buildLists(activeListId)
	---@type {[Guid]: CustomList}
	local listConfig = ConfigurationStructure.config.mutations[self.configKey]

	local headerTitle = self.listSection:AddSeparatorText("Your Lists ( ? )")
	headerTitle:Tooltip():AddText("\t Right-click on an entry to manage it")
	headerTitle:SetStyle("SeparatorTextAlign", 0.5)

	local popup = self.listSection:AddPopup("ListPopup")

	for guid, list in TableUtils:OrderedPairs(listConfig, function(key)
		return listConfig[key].name
	end) do
		---@type ExtuiSelectable
		local listSelectable = self.listSection:AddSelectable(list.name)
		listSelectable.IDContext = guid
		if list.description and list.description ~= "" then
			listSelectable:Tooltip():AddText("\t " .. list.description)
		end
		listSelectable.UserData = guid

		listSelectable.OnRightClick = function()
			Helpers:KillChildren(popup)
			popup:Open()
			popup:AddSelectable("Edit").OnClick = function()
				self.formWindow.Open = true
				self.formWindow:SetFocus()

				FormBuilder:CreateForm(self.formWindow, function(formResults)
					list.name = formResults.Name
					list.description = formResults.Description

					self:launch(self.activeListHandle and self.activeListHandle.UserData)
					self.formWindow.Open = false
				end, {
					{
						label = "Name",
						type = "Text",
						errorMessageIfEmpty = "Required Field",
						defaultValue = list.name
					},
					{
						label = "Description",
						type = "Multiline",
						defaultValue = list.description
					}
				})
			end

			popup:AddSelectable("Delete").OnClick = function()
				list.delete = true
				self:launch(self.activeListHandle and self.activeListHandle.UserData)
			end
		end

		listSelectable.OnClick = function()
			if self.activeListHandle then
				self.activeListHandle.Selected = false
				Helpers:KillChildren(self.designerSection)
			end
			self.designerSection.Visible = true

			self.activeListHandle = listSelectable

			self.activeList = list

			self:buildBrowser()

			self:buildDesigner()
		end

		if guid == activeListId then
			listSelectable.Selected = true
			listSelectable:OnClick()
		end
	end

	self.listSection:AddNewLine()

	---@type ExtuiSelectable
	local createListButton = self.listSection:AddSelectable("Create a List")

	createListButton.OnClick = function()
		createListButton.Selected = false

		self.formWindow.Open = true
		self.formWindow:SetFocus()

		FormBuilder:CreateForm(self.formWindow, function(formResults)
			local list = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.customLeveledList)

			list.name = formResults.Name
			list.description = formResults.Description

			listConfig[FormBuilder:generateGUID()] = list
			self:launch(self.activeListHandle and self.activeListHandle.UserData)
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
	end
end

function ListDesignerBaseClass:buildModLists(activeListID)
	if MutationModProxy.ModProxy[self.configKey]() then
		---@type {[Guid]: Guid[]}
		local modLists = {}

		for modId, modCache in pairs(MutationModProxy.ModProxy[self.configKey]) do
			---@cast modCache LocalModCache

			if modCache[self.configKey] and next(modCache[self.configKey]) then
				modLists[modId] = {}
				for listId in pairs(modCache[self.configKey]) do
					table.insert(modLists[modId], listId)
				end
			end
		end

		if next(modLists) then
			self.listSection:AddSeparatorText("Mod-Added Lists"):SetStyle("SeparatorTextAlign", 0.5)

			for modId, spellLists in TableUtils:OrderedPairs(modLists, function(key)
				return Ext.Mod.GetMod(key).Info.Name
			end) do
				self.listSection:AddSeparatorText(Ext.Mod.GetMod(modId).Info.Name)

				for _, guid in TableUtils:OrderedPairs(spellLists, function(_, value)
					return MutationModProxy.ModProxy[self.configKey][value].name
				end) do
					local list = MutationModProxy.ModProxy[self.configKey][guid]

					---@type ExtuiSelectable
					local spellListSelect = self.listSection:AddSelectable(list.name)
					spellListSelect.IDContext = guid
					spellListSelect.UserData = guid
					if list.description and list.description ~= "" then
						spellListSelect:Tooltip():AddText("\t " .. list.description)
					end

					spellListSelect.OnClick = function()
						if self.activeListHandle then
							self.activeListHandle.Selected = false
							Helpers:KillChildren(self.designerSection)
						end
						self.designerSection.Visible = true

						self.activeListHandle = spellListSelect
						self.activeList = list

						self.browserSection.Visible = false
						self:buildBrowser()
						self:buildDesigner()
					end

					if guid == activeListID then
						spellListSelect.Selected = true
						spellListSelect:OnClick()
					end
				end
			end
		end
	end
end

function ListDesignerBaseClass:buildDesigner()

end

function ListDesignerBaseClass:buildBrowser()

end
