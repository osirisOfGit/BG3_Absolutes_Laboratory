Ext.Vars.RegisterModVariable(ModuleUUID, "ActiveMutationProfile", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true,
	SyncOnWrite = true
})

Ext.Vars.RegisterModVariable(ModuleUUID, "HasDisabledProfiles", {
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
	modFolderGroup = nil,
	---@type ExtuiGroup
	profileGroup = nil,
	---@type ExtuiPopup
	popup = nil
}

Ext.Require("Client/Mutations/MutationDesigner.lua")

---@type string?
local activeProfileId

if Ext.Mod.IsModLoaded("755a8a72-407f-4f0d-9a33-274ac0f0b53d") then
	Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
		--- @param tabHeader ExtuiTabItem
		function(tabHeader)
			MutationProfileManager:init(tabHeader)
			MutationProfileManager:BuildFolderManager()
		end)
end

---@type ExtuiButton?
local activeMutationView

---@param parent ExtuiTreeParent
function MutationProfileManager:init(parent)
	if not self.userFolderGroup then
		self.popup = parent:AddPopup("ProfileManager")
		self.popup:SetColor("PopupBg", { 0, 0, 0, 1 })
		self.popup:SetColor("Border", { 1, 0, 0, 0.5 })
		self.popup.AutoClosePopups = true
		self.popup.UserData = "closeOnSubmit"

		local parentTable = Styler:TwoColumnTable(parent, "mutationsMain")
		parentTable.Borders = false
		parentTable.Resizable = false
		parentTable.ColumnDefs[1].Width = 300 * Styler:ScaleFactor()

		local row = parentTable:AddRow()

		self.selectionParent = row:AddCell():AddChildWindow("selectionParent")

		local userMutSep = self.selectionParent:AddSeparatorText("Your Mutations ( ? )")
		userMutSep:SetStyle("SeparatorTextAlign", 0.5)
		userMutSep:Tooltip():AddText(
			"\t Right-click on mutations to edit their details or delete them - use the Manage Folder button to create mutations. Drag and Drop mutations into the profile section to add them to a profile")

		self.userFolderGroup = self.selectionParent:AddGroup("User Folders")
		self.userFolderGroup.DragDropType = "MutationRules"
		self.userFolderGroup.OnDragDrop = function(group, dropped)
			for _, ele in TableUtils:CombinedPairs(self.userFolderGroup.Children, self.modFolderGroup.Children) do
				---@cast ele ExtuiTree
				if ele.UserData == dropped.UserData.mutationFolderId then
					for _, mutation in pairs(ele.Children) do
						---@cast mutation ExtuiSelectable

						if mutation.UserData and mutation.UserData.mutationId == dropped.UserData.mutationId then
							mutation.CanDrag = true
							mutation:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })

							for _, mutationRule in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles[activeProfileId].mutationRules) do
								if mutationRule.mutationId == dropped.UserData.mutationId and mutationRule.mutationFolderId == dropped.UserData.mutationFolderId then
									mutationRule.delete = true
									break
								end
							end

							for _, mutationRule in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles[activeProfileId].prepPhaseMutations) do
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

		if MutationModProxy.ModProxy.folders() > 0 then
			self.selectionParent:AddSeparatorText("Mod-Added Mutations"):SetStyle("SeparatorTextAlign", 0.5)
			self.modFolderGroup = self.selectionParent:AddGroup("ModFolders")
			self.modFolderGroup.DragDropType = "MutationRules"
			self.modFolderGroup.OnDragDrop = self.userFolderGroup.OnDragDrop
		else
			self.modFolderGroup = self.selectionParent:AddGroup("ModFolders")
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
	end
end

function MutationProfileManager:BuildFolderManager()
	activeMutationView = nil

	Helpers:KillChildren(self.userFolderGroup)

	local folders = ConfigurationStructure.config.mutations.folders

	for folderId, folder in TableUtils:OrderedPairs(folders, function(key, value)
		return value.name
	end) do
		local folderHeader = self.userFolderGroup:AddTree(folder.name)
		folderHeader.UserData = folderId
		folderHeader.IDContext = folderId

		folderHeader:SetColor("Header", { 1, 1, 1, 0 })
		if folder.description ~= "" then
			folderHeader:Tooltip():AddText("\t " .. folder.description)
		end

		local folderPopup = folderHeader:AddPopup(folderId)
		folderPopup:AddSelectable("Create a Mutation").OnClick = function(selectable)
			Helpers:KillChildren(self.popup)
			self.popup:Open()

			FormBuilder:CreateForm(self.popup, function(formResults)
					folder.mutations[FormBuilder:generateGUID()] = {
						name = formResults.Name,
						description = formResults.Description,
						selectors = {},
						mutators = {}
					} --[[@as Mutation]]

					self:BuildFolderManager()
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
			Helpers:KillChildren(self.popup)
			self.popup:Open()

			FormBuilder:CreateForm(self.popup, function(formResults)
					folder.name = formResults.Name
					folder.description = formResults.Description

					self:BuildFolderManager()
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
				local largestIndex = 0

				local toDelete = {}
				for i, mutRule in TableUtils:OrderedPairs(profile.mutationRules) do
					largestIndex = i > largestIndex and i or largestIndex

					if mutRule.mutationFolderId == folderId then
						toDelete[#toDelete + 1] = i - #toDelete
					end
				end

				for _, indexToDelete in ipairs(toDelete) do
					for x = indexToDelete, largestIndex do
						if profile.mutationRules[x] then
							profile.mutationRules[x].delete = true
						end
						profile.mutationRules[x] = TableUtils:DeeplyCopyTable(profile.mutationRules._real[x + 1])
					end
				end
			end

			self:BuildFolderManager()
		end

		for mutationId, mutation in TableUtils:OrderedPairs(folder.mutations, function(key, value)
			return value.name
		end) do
			---@type ExtuiSelectable
			local mutationSelectable = folderHeader:AddSelectable(("%s%s"):format(mutation.prepPhase and "(P) " or "", mutation.name))
			mutationSelectable.IDContext = mutationId

			if mutation.description ~= "" then
				mutationSelectable:Tooltip():AddText("\t " .. mutation.description)
			end
			mutationSelectable.CanDrag = true
			mutationSelectable.DragDropType = mutation.prepPhase and "PrepMutationRules" or "MutationRules"
			mutationSelectable.UserData = {
				mutationFolderId = folderId,
				mutationId = mutationId
			}

			local mutationPopup = folderHeader:AddPopup(mutationId)

			mutationPopup:AddSelectable("Copy").OnClick = function()
				---@type Mutation
				local mut = TableUtils:DeeplyCopyTable(mutation._real)
				mut.name = mut.name .. "COPY"

				folder.mutations[FormBuilder:generateGUID()] = mut
				self:BuildFolderManager()
			end

			---@type ExtuiSelectable
			local select = mutationPopup:AddSelectable(mutation.prepPhase and "Unmark As Prep Mutation (?)" or "Mark As Prep Mutation (?)", "DontClosePopups")
			select:Tooltip():AddText(
				"\t A Prep Mutation is a mutation that is run before all others, assigning specified categories to the selected entities so they can be reused by Selectors in main mutations, greatly simplifying regular mutators. Prep mutations are marked via (P) in their button name")
			select.OnClick = function()
				mutation.prepPhase = not mutation.prepPhase
				mutation.mutators.delete = true
				mutation.mutators = mutation.prepPhase and { {
						targetProperty = "Prep Phase Marker"
					} --[[@as Mutator]] }
					or {}

				mutationSelectable.Label = ("%s%s"):format(mutation.prepPhase and "(P) " or "", mutation.name)

				if not mutation.prepPhase then
					for _, mutationRule in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles[activeProfileId].prepPhaseMutations) do
						if mutationRule.mutationId == mutationSelectable.UserData.mutationId and mutationRule.mutationFolderId == mutationSelectable.UserData.mutationFolderId then
							mutationRule.delete = true
							break
						end
					end
				else
					for _, mutationRule in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles[activeProfileId].mutationRules) do
						if mutationRule.mutationId == mutationSelectable.UserData.mutationId and mutationRule.mutationFolderId == mutationSelectable.UserData.mutationFolderId then
							mutationRule.delete = true
							break
						end
					end
				end
				mutationSelectable:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })

				mutationSelectable:OnClick()
				for _, profile in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles) do
					TableUtils:ReindexNumericTable(profile.mutationRules)
					TableUtils:ReindexNumericTable(profile.prepPhaseMutations)
				end
				self:BuildFolderManager()
			end
			mutationPopup:AddSelectable("Edit Details").OnClick = function()
				Helpers:KillChildren(self.popup)
				self.popup:Open()
				FormBuilder:CreateForm(self.popup, function(formResults)
						mutation.name = formResults.Name
						mutation.description = formResults.Description

						self:BuildFolderManager()
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

			---@param selectable ExtuiSelectable
			mutationPopup:AddSelectable("Delete", "DontClosePopups").OnClick = function(selectable)
				if selectable.Label ~= "Delete" then
					mutation.delete = true

					for _, profile in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.profiles) do
						local largestIndex = 0

						local toDelete = {}
						for i, mutRule in TableUtils:OrderedPairs(profile.mutationRules) do
							largestIndex = i > largestIndex and i or largestIndex

							if mutRule.mutationFolderId == folderId and mutRule.mutationId == mutationId then
								toDelete[#toDelete + 1] = i - #toDelete
							end
						end

						for _, indexToDelete in ipairs(toDelete) do
							for x = indexToDelete, largestIndex do
								if profile.mutationRules[x] then
									profile.mutationRules[x].delete = true
								end
								profile.mutationRules[x] = TableUtils:DeeplyCopyTable(profile.mutationRules._real[x + 1])
							end
						end
					end

					self:BuildFolderManager()
				else
					selectable.Label = "Are You Sure? This Will Delete From All Profiles"
					Styler:Color(selectable, "ErrorText")
				end
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
							self:BuildFolderManager()
						end
					end
				end
				mutationPopup:AddSelectable("Move To Folder", "DontClosePopups").OnClick = function()
					movePopup:Open()
				end
			end

			mutationSelectable.OnRightClick = function()
				mutationPopup:Open()
			end
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
					ele:AddText(folder.name .. "/" .. mutation.name).Font = "Big"
					Styler:CheapTextAlign(mutation.description, ele)
				end).SameLine = true
				MutationDesigner:RenderMutationManager(self.mutationDesigner:AddGroup("designer"), mutation)
			end

			---@param selectable ExtuiSelectable
			---@param preview ExtuiTreeParent
			mutationSelectable.OnDragStart = function(selectable, preview)
				preview:AddText(selectable.Label)
			end

			if activeProfileId and MutationConfigurationProxy.profiles[activeProfileId] then
				local profile = MutationConfigurationProxy.profiles[activeProfileId]
				if TableUtils:IndexOf(profile.mutationRules, function(mutationRule)
						return mutationRule.mutationFolderId == folderId and mutationRule.mutationId == mutationId
					end)
					or TableUtils:IndexOf(profile.prepPhaseMutations or {}, function(mutationRule)
						return mutationRule.mutationFolderId == folderId and mutationRule.mutationId == mutationId
					end)
				then
					mutationSelectable:SetColor("Text", { 0.86, 0.79, 0.68, 0.28 })
					mutationSelectable.CanDrag = false
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

		Helpers:KillChildren(self.popup)
		self.popup:Open()

		FormBuilder:CreateForm(self.popup, function(formResults)
				ConfigurationStructure.config.mutations.folders[FormBuilder:generateGUID()] = {
					name = formResults.Name,
					description = formResults.Description,
					mutations = {}
				} --[[@as MutationFolder]]

				self:BuildFolderManager()
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

	self:BuildModFolders()
	self:BuildProfileManager()
end

function MutationProfileManager:BuildModFolders()
	if MutationModProxy.ModProxy.folders() > 0 then
		Helpers:KillChildren(self.modFolderGroup)

		---@type {[string]: {[Guid]: string}}
		local modFolders = {}

		for modId, modCache in pairs(MutationModProxy.ModProxy.folders) do
			---@cast modCache +LocalModCache

			local modInfo = Ext.Mod.GetMod(modId).Info
			if next(modCache.folders) then
				modFolders[modInfo.Name] = modCache.folders
			end
		end

		local modPopup = self.modFolderGroup:AddPopup("modPopup")

		for modName, folders in TableUtils:OrderedPairs(modFolders) do
			self.modFolderGroup:AddSeparatorText(modName)

			for folderId in TableUtils:OrderedPairs(folders, function(_, folderName)
				return folderName
			end) do
				local folder = MutationModProxy.ModProxy.folders[folderId]

				local folderHeader = self.modFolderGroup:AddTree(folder.name)
				folderHeader.IDContext = folderId
				folderHeader.UserData = folderId
				folderHeader:SetColor("Header", { 1, 1, 1, 0 })
				if folder.description ~= "" then
					folderHeader:Tooltip():AddText("\t " .. folder.description)
				end

				for mutationId, mutation in TableUtils:OrderedPairs(folder.mutations, function(_, value)
					return value.name
				end) do
					---@type ExtuiSelectable
					local mutationSelectable = folderHeader:AddSelectable(("%s%s"):format(mutation.prepPhase and "(P) " or "", mutation.name))
					if mutation.description ~= "" then
						mutationSelectable:Tooltip():AddText("\t " .. mutation.description)
					end
					mutationSelectable.CanDrag = true
					mutationSelectable.DragDropType = mutation.prepPhase and "PrepMutationRules" or "MutationRules"
					mutationSelectable.UserData = {
						mutationFolderId = folderId,
						mutationId = mutationId
					}

					---@param selectable ExtuiSelectable
					---@param preview ExtuiTreeParent
					mutationSelectable.OnDragStart = function(selectable, preview)
						preview:AddText(selectable.Label)
					end

					if activeProfileId and MutationConfigurationProxy.profiles[activeProfileId] then
						local profile = MutationConfigurationProxy.profiles[activeProfileId]
						if TableUtils:IndexOf(profile.mutationRules, function(mutationRule)
								return mutationRule.mutationFolderId == folderId and mutationRule.mutationId == mutationId
							end)
							or TableUtils:IndexOf(profile.prepPhaseMutations or {}, function(mutationRule)
								return mutationRule.mutationFolderId == folderId and mutationRule.mutationId == mutationId
							end)
						then
							mutationSelectable:SetColor("Text", { 0.86, 0.79, 0.68, 0.28 })
							mutationSelectable.CanDrag = false
						end
					end

					mutationSelectable.OnRightClick = function()
						modPopup:Open()
						Helpers:KillChildren(modPopup)

						---@type ExtuiMenu
						local copyMenu = modPopup:AddMenu("Copy Mutation To Folder")

						local mut = TableUtils:DeeplyCopyTable(mutation)
						mut.modId = nil

						for _, userFolder in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.folders, function(_, userFolder)
							return userFolder.name
						end) do
							copyMenu:AddSelectable(userFolder.name).OnClick = function()
								if TableUtils:IndexOf(userFolder.mutations, function(value)
										return value.name == mut.name
									end) then
									mut.name = mut.name .. " (COPY)"
								end

								userFolder.mutations[FormBuilder:generateGUID()] = mut
								self:BuildFolderManager()
							end
						end

						copyMenu:AddSelectable("Use Mod's Folder Name").OnClick = function()
							local folderCopy = {
								name = TableUtils:IndexOf(ConfigurationStructure.config.mutations.folders, function(value)
										return value.name == folder.name
									end)
									and (folder.name .. " (COPY)")
									or folder.name,
								description = folder.description,
								mutations = { [FormBuilder:generateGUID()] = mut }
							} --[[@as MutationFolder]]

							ConfigurationStructure.config.mutations.folders[FormBuilder:generateGUID()] = folderCopy
							self:BuildFolderManager()
						end

						modPopup:AddSelectable("Copy Whole Folder").OnClick = function()
							local folderCopy = {
								name = TableUtils:IndexOf(ConfigurationStructure.config.mutations.folders, function(value)
										return value.name == folder.name
									end)
									and (folder.name .. " (COPY)")
									or folder.name,
								description = folder.description,
								mutations = TableUtils:DeeplyCopyTable(folder.mutations)
							} --[[@as MutationFolder]]

							for _, mutation in pairs(folderCopy.mutations) do
								mutation.modId = nil
							end

							ConfigurationStructure.config.mutations.folders[FormBuilder:generateGUID()] = folderCopy
							self:BuildFolderManager()
						end
					end
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
							Styler:CheapTextAlign(folder.name .. "/" .. mutation.name, ele, "Big")
							Styler:CheapTextAlign(mutation.description, ele)

							Styler:CheapTextAlign("(" .. modName .. ")", ele)
						end).SameLine = true
						MutationDesigner:RenderMutationManager(self.mutationDesigner:AddGroup("designer"), mutation)
					end
				end
			end
		end
	end
end

local triedOnce
function MutationProfileManager:BuildProfileManager()
	if not activeProfileId and not triedOnce then
		triedOnce = true
		-- MCM seems to initialize the tab before the ModVars are loaded, so need to do a deferred load
		Ext.Timer.WaitFor(1000, function()
			activeProfileId = Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile
			if not MutationConfigurationProxy.profiles[activeProfileId] then
				Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = nil
				activeProfileId = nil
			end
			self:BuildFolderManager()
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
	if activeProfileId then
		table.insert(opt, "Disabled")
	end

	---@type {[Guid] : MutationProfile}
	local combinedProfiles = TableUtils:DeeplyCopyTable(profiles._real)

	for _, modCache in pairs(MutationModProxy.ModProxy.profiles) do
		---@cast modCache +LocalModCache
		for profileId in pairs(modCache.profiles) do
			combinedProfiles[profileId] = MutationModProxy.ModProxy.profiles[profileId]
		end
	end

	for profileId, profile in TableUtils:OrderedPairs(combinedProfiles, function(_, value)
		return value.name
	end) do
		table.insert(opt, profile.name .. (profile.modId and "(M)" or ""))
		if activeProfileId == profileId then
			sIndex = #opt
		end
	end

	profileCombo.Options = opt
	profileCombo.SelectedIndex = sIndex - 1
	profileCombo.OnChange = function()
		local selectedName = profileCombo.Options[profileCombo.SelectedIndex + 1]

		if selectedName == "Disabled" then
			activeProfileId = nil
			Ext.Vars.GetModVariables(ModuleUUID).HasDisabledProfiles = true
			Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = nil
		else
			local isModProfile = selectedName:sub(#selectedName - 2) == "(M)"

			activeProfileId = TableUtils:IndexOf(combinedProfiles, function(value)
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
			end)

			Ext.Vars.GetModVariables(ModuleUUID).HasDisabledProfiles = false
			Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = activeProfileId
		end

		Helpers:KillChildren(self.rulesOrderGroup, self.mutationDesigner)
		self:BuildFolderManager()
	end

	local manageProfileButton = Styler:ImageButton(self.profileManagerParent:AddImageButton("Manage", "ico_edit_d", { 32, 32 }))
	manageProfileButton.SameLine = true
	local manageProfilePopup = self.profileManagerParent:AddPopup("Manage Profiles")

	manageProfilePopup:AddSelectable("Create Profile").OnClick = function()
		Helpers:KillChildren(self.popup)
		self.popup:Open()

		FormBuilder:CreateForm(self.popup, function(formResults)
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
				}
			}
		)
	end

	local importSelect = manageProfilePopup:AddSelectable("Import Profile(s)", "DontClosePopups")

	local importGroup = manageProfilePopup:AddGroup("Import")
	importGroup.Visible = false

	importSelect.OnClick = function()
		if #importGroup.Children > 0 then
			Helpers:KillChildren(importGroup)
			importGroup.Visible = false
		else
			importGroup.Visible = true
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
				local importFunc, mods, failedDependencies, showDepWindowFunc = MutationExternalProfileUtility:importProfile(FileUtils:LoadTableFile(fileNameInput.Text))
				if not importFunc then
					self:BuildFolderManager()
				else
					errorGroup.Visible = true
					Helpers:KillChildren(errorGroup)

					errorGroup:AddSeparatorText("Missing Dependencies!"):SetColor("Separator", { 1, 0, 0, 0.4 })
					Styler:MiddleAlignedColumnLayout(errorGroup, function(ele)
						local continueButton = ele:AddButton("Continue")
						continueButton:Tooltip():AddText("\t This will remove all items that depend on a missing mod while importing - it will not affect the file")
						continueButton.OnClick = function()
							importFunc()
							self:BuildFolderManager()
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
		end
	end

	---@type ExtuiMenu
	local exportProfilesMenu = manageProfilePopup:AddMenu("Export Profile(s)")

	local sep = manageProfilePopup:AddSeparatorText("Profiles")
	sep:SetStyle("SeparatorTextAlign", 0.5)

	for profileId, profile in TableUtils:OrderedPairs(combinedProfiles, function(key, value)
		return (value.modId and ("Z" .. value.modId) or "") .. value.name
	end) do
		if not profile.modId then
			exportProfilesMenu:AddCheckbox(profile.name .. "##" .. profileId).UserData = profileId
		end

		local isDefault = ConfigurationStructure.config.mutations.settings.defaultProfile == profileId

		---@type ExtuiMenu
		local profileMenu = manageProfilePopup:AddMenu((isDefault and "(D) " or "") .. profile.name .. (profile.modId and " (M)" or "") .. "##" .. profileId)

		if profile.modId then
			profileMenu:AddSeparatorText("From " .. Ext.Mod.GetMod(profile.modId).Info.Name):SetStyle("Alpha", 0.5)
		end

		if not isDefault then
			profileMenu:AddItem("Set as Default Profile").OnClick = function()
				ConfigurationStructure.config.mutations.settings.defaultProfile = profileId
				self:BuildProfileManager()
			end
		else
			profileMenu:AddItem("Unset as Default Profile").OnClick = function()
				ConfigurationStructure.config.mutations.settings.defaultProfile = nil
				self:BuildProfileManager()
			end
		end

		profileMenu:AddItem("Copy").OnClick = function()
			local copiedProfile = TableUtils:DeeplyCopyTable(profile)
			copiedProfile.name = copiedProfile.name .. " (COPY)"
			copiedProfile.modId = nil

			profiles[FormBuilder:generateGUID()] = copiedProfile

			self:BuildProfileManager()
		end

		if not profile.modId then
			profileMenu:AddItem("Edit").OnClick = function()
				Helpers:KillChildren(self.popup)
				self.popup:Open()
				FormBuilder:CreateForm(self.popup, function(formResults)
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
						profiles[profileId].delete = true
						profiles[profileId] = profile

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

			if profile.mutationRules and next(profile.mutationRules) then
				profileMenu:AddItem("Export").OnClick = function()
					MutationExternalProfileUtility:exportProfile(false, profileId)
				end

				profileMenu:AddItem("Export For Mod").OnClick = function()
					MutationExternalProfileUtility:exportProfile(true, profileId)
				end
			end
			profileMenu:AddItem("Delete").OnClick = function()
				profiles[profileId].delete = true
				if activeProfileId == profileId then
					activeProfileId = nil
					Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile = activeProfileId
				end
				self:BuildProfileManager()
			end
		end
	end

	if #exportProfilesMenu.Children == 0 then
		exportProfilesMenu:Destroy()
	else
		Styler:MiddleAlignedColumnLayout(exportProfilesMenu, function(ele)
			local exportButton = ele:AddSelectable("Export")
			exportButton:SetStyle("SelectableTextAlign", 0.5)

			exportButton.OnClick = function()
				local profilesToExport = {}

				for _, child in pairs(exportProfilesMenu.Children) do
					if child.UserData and child.Checked then
						table.insert(profilesToExport, child.UserData)
					end
				end

				if next(profilesToExport) then
					MutationExternalProfileUtility:exportProfile(false, table.unpack(profilesToExport))
				end
			end

			local exportForModButton = ele:AddSelectable("Export For Mod")
			exportForModButton:SetStyle("SelectableTextAlign", 0.5)
			exportForModButton.OnClick = function()
				local profilesToExport = {}

				for _, child in pairs(exportProfilesMenu.Children) do
					if child.UserData and child.Checked then
						table.insert(profilesToExport, child.UserData)
					end
				end

				if next(profilesToExport) then
					MutationExternalProfileUtility:exportProfile(true, table.unpack(profilesToExport))
				end
			end
		end)
	end

	manageProfileButton.OnClick = function()
		manageProfilePopup:Open()
	end

	self:BuildRuleManager(lastMutation)
end

---@param lastMutationActive string?
function MutationProfileManager:BuildRuleManager(lastMutationActive)
	Helpers:KillChildren(self.rulesOrderGroup)
	activeMutationView = nil

	---@type MutationProfile
	local activeProfile
	if activeProfileId then
		activeProfile = MutationConfigurationProxy.profiles[activeProfileId]
	else
		return
	end

	local numOfMutations = 0
	local numOfPrepMutations = 0
	for _, mutationFolder in pairs(ConfigurationStructure.config.mutations.folders) do
		for _, mutation in pairs(mutationFolder.mutations) do
			if not mutation.prepPhase then
				numOfMutations = numOfMutations + 1
			else
				numOfPrepMutations = numOfPrepMutations + 1
			end
		end
	end

	for _, modCache in pairs(MutationModProxy.ModProxy.folders) do
		---@cast modCache +LocalModCache

		for folderId in pairs(modCache.folders) do
			for _, mutation in pairs(MutationModProxy.ModProxy.folders[folderId].mutations) do
				if not mutation.prepPhase then
					numOfMutations = numOfMutations + 1
				else
					numOfPrepMutations = numOfPrepMutations + 1
				end
			end
		end
	end

	local function buildSlots(numOfMutations, prepPhase)
		if prepPhase then
			self.rulesOrderGroup:AddSeparatorText("Prep Mutations"):SetStyle("SeparatorTextAlign", 0.5)
		else
			self.rulesOrderGroup:AddSeparatorText("Main Mutations"):SetStyle("SeparatorTextAlign", 0.5)
		end
		local hideButton = Styler:ImageButton(self.rulesOrderGroup:AddImageButton("hideLevel" .. (prepPhase and "prep" or "not"), "Action_Hide", Styler:ScaleFactor({ 28, 28 })))
		hideButton.Visible = true
		local showButton = Styler:ImageButton(self.rulesOrderGroup:AddImageButton("showLevel" .. (prepPhase and "prep" or "not"), "ico_concentration", Styler:ScaleFactor({ 28, 28 })))
		showButton.Visible = false

		local group = self.rulesOrderGroup:AddGroup("Mutations" .. (prepPhase and "prep" or "not prep"))

		hideButton.OnClick = function()
			group.Visible = not group.Visible
			hideButton.Visible = not hideButton.Visible
			showButton.Visible = not showButton.Visible
		end

		showButton.OnClick = hideButton.OnClick

		if prepPhase then
			activeProfile.prepPhaseMutations = activeProfile.prepPhaseMutations or {}
		end

		local rulesToUse = prepPhase and activeProfile.prepPhaseMutations or activeProfile.mutationRules
		for counter = 1, numOfMutations do
			local row = group:AddGroup("MutationGroup" .. counter .. (prepPhase and "prep" or "main"))

			row.UserData = counter
			if not activeProfile.modId then
				row.DragDropType = prepPhase and "PrepMutationRules" or "MutationRules"
				---@param row ExtuiGroup
				---@param dropped ExtuiSelectable|ExtuiButton
				row.OnDragDrop = function(row, dropped)
					if tonumber(dropped.ParentElement.UserData) then
						rulesToUse[dropped.ParentElement.UserData].delete = true
						if rulesToUse[row.UserData] then
							rulesToUse[dropped.ParentElement.UserData] = rulesToUse[row.UserData]._real
						end
					else
						dropped:SetColor("Text", { 0.86, 0.79, 0.68, 0.28 })
						dropped.CanDrag = false

						if rulesToUse[row.UserData] then
							local removeRule = rulesToUse[row.UserData]
							for _, ele in TableUtils:CombinedPairs(self.userFolderGroup.Children, self.modFolderGroup.Children) do
								---@cast ele ExtuiCollapsingHeader
								if ele.UserData == removeRule.mutationFolderId then
									for _, mutation in pairs(ele.Children) do
										---@cast mutation ExtuiSelectable

										if mutation.UserData and mutation.UserData.mutationId == removeRule.mutationId then
											mutation.CanDrag = true
											mutation:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })
											goto continue
										end
									end
								end
							end
							::continue::
						end
					end

					if rulesToUse[row.UserData] then
						rulesToUse[row.UserData].delete = true
					end

					rulesToUse[row.UserData] = {
						additive = dropped.UserData.additive,
						mutationFolderId = dropped.UserData.mutationFolderId,
						mutationId = dropped.UserData.mutationId,
					}

					self:BuildRuleManager(activeMutationView and activeMutationView.Label)
				end
			end

			local orderNumberInput = row:AddInputInt("##" .. counter .. (prepPhase and "prep" or "main"), counter)
			orderNumberInput.Disabled = activeProfile.modId ~= nil
			orderNumberInput.AutoSelectAll = true
			orderNumberInput.ItemWidth = 40

			if activeProfile and rulesToUse[counter] then
				local mutationRule = rulesToUse[counter]

				orderNumberInput.OnDeactivate = function()
					if orderNumberInput.Value[1] ~= row.UserData then
						if orderNumberInput.Value[1] <= counter and orderNumberInput.Value[1] > 0 then
							if rulesToUse[orderNumberInput.Value[1]] then
								local ruletoRemove = rulesToUse[orderNumberInput.Value[1]]

								for _, ele in TableUtils:CombinedPairs(self.userFolderGroup.Children, self.modFolderGroup.Children) do
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

							rulesToUse[orderNumberInput.Value[1]] = mutationRule._real
							mutationRule.delete = true
						end

						self:BuildRuleManager(activeMutationView and activeMutationView.Label)
					end
				end

				local folders = MutationConfigurationProxy.folders

				local mutationButton = row:AddButton(folders[mutationRule.mutationFolderId].name ..
					"/" .. folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId].name)

				if folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId].modId then
					mutationButton.Label = "(M) " .. mutationButton.Label
				end

				mutationButton.IDContext = mutationRule.mutationFolderId .. mutationRule.mutationId
				mutationButton.SameLine = true
				mutationButton.UserData = activeProfile.modId and mutationRule or mutationRule._real

				if not activeProfile.modId then
					mutationButton.CanDrag = true
					mutationButton.DragDropType = row.DragDropType
				end

				local mutation = folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId]
				if not mutation.modId and (not mutation.selectors() or not mutation.mutators()) then
					mutationButton:SetColor("Button", { 1, 0.02, 0, 0.4 })
					mutationButton:Tooltip():AddText("Missing a defined selector or mutator!")
				end

				---@param button ExtuiButton
				---@param preview ExtuiTreeParent
				mutationButton.OnDragStart = function(button, preview)
					preview:AddText(button.Label)
					self.userFolderGroup.DragDropType = prepPhase and "PrepMutationRules" or "MutationRules"
					self.modFolderGroup.DragDropType = prepPhase and "PrepMutationRules" or "MutationRules"
				end

				mutationButton.OnRightClick = function()
					for _, ele in TableUtils:CombinedPairs(self.userFolderGroup.Children, self.modFolderGroup.Children) do
						---@cast ele ExtuiCollapsingHeader
						if ele.UserData == mutationRule.mutationFolderId then
							for _, mutation in pairs(ele.Children) do
								---@cast mutation ExtuiSelectable

								if mutation.UserData and mutation.UserData.mutationId == mutationRule.mutationId then
									mutation:OnRightClick()
									return
								end
							end
						end
					end
				end
				mutationButton.OnClick = function()
					Helpers:KillChildren(self.mutationDesigner)

					local mutation = folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId]

					if not mutation.modId and (not mutation.selectors() or not mutation.mutators()) then
						mutationButton:SetColor("Button", { 1, 0.02, 0, 0.4 })
					end

					if activeMutationView then
						if activeMutationView.Handle then
							---@type MutationProfileRule
							local activeMutationRule = activeMutationView.UserData
							local mutationConfig = folders[activeMutationRule.mutationFolderId].mutations[activeMutationRule.mutationId]

							if not mutationConfig.modId and (not mutationConfig.selectors() or not mutationConfig.mutators()) then
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
						Styler:CheapTextAlign(folders[mutationRule.mutationFolderId].name ..
							"/" .. folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId].name, ele, "Big")

						local mut = folders[mutationRule.mutationFolderId].mutations[mutationRule.mutationId]

						if mut.modId then
							local modInfo = Ext.Mod.GetMod(mut.modId).Info
							Styler:CheapTextAlign("(" .. modInfo.Name .. ")", ele)
							Styler:CheapTextAlign(mut.description, ele)
						else
							Styler:CheapTextAlign(mut.description, ele)
						end
					end).SameLine = true

					MutationDesigner:RenderMutationManager(self.mutationDesigner:AddGroup("designer"), mutation)
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
					additiveCheckbox.Disabled = activeProfile.modId ~= nil
					additiveCheckbox:Tooltip():AddText(
						"\t If checked, relevant mutators under this mutation will be _additive_, meaning they will be combined with any mutators of the same type that are applicable from mutations earlier in the flow.\n If unchecked, mutators of the same type from earlier mutations will be replaced with these.")

					additiveCheckbox.SameLine = true
					additiveCheckbox.OnChange = function()
						mutationRule.additive = additiveCheckbox.Checked
					end
				end
			else
				orderNumberInput.Disabled = true

				local cell = row:AddButton((" "):rep(15) .. "##" .. counter .. (prepPhase and "prep" or "main"))
				cell.SameLine = true
			end
		end
	end

	buildSlots(numOfPrepMutations, true)
	buildSlots(numOfMutations)
end
