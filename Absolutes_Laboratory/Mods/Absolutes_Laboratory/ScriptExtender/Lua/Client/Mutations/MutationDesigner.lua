MutationDesigner = {}

Ext.Require("Shared/Mutations/Selectors/SelectorInterface.lua")
Ext.Require("Shared/Mutations/Mutators/MutatorInterface.lua")

local activeButtonColor = { 0.38, 0.26, 0.21, 0.78 }
local disabledButtonColor = { 0, 0, 0, 0 }

---@type ExtuiPopup
local popup

local lastViewedMutator

---@param parent ExtuiTreeParent
---@param existingMutation Mutation
function MutationDesigner:RenderMutationManager(parent, existingMutation)
	lastViewedMutator = nil
	Helpers:KillChildren(parent)
	popup = Styler:Popup(parent)

	if existingMutation.modId then
		Styler:CheapTextAlign("Mod-Added Mutation - You can browse, but not edit", parent, "Large"):SetColor("Text", { 1, 0, 0, 0.45 })
	end

	---@type ExtuiTable
	local managerTable

	local buildDesignerFunc

	---@type ExtuiButton[]
	local focusButtons

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		Styler:ScaledFont(ele, "Small")
		Styler:CheapTextAlign("Focus:", ele)

		local focusSelectors = ele:AddButton("Selectors")
		focusSelectors:SetColor("Button", disabledButtonColor)

		local focusBoth = ele:AddButton("Both")
		focusBoth:SetColor("Button", activeButtonColor)
		focusBoth.UserData = true
		focusBoth.SameLine = true

		local focusMutators = ele:AddButton("Mutators")
		focusMutators:SetColor("Button", disabledButtonColor)
		focusMutators.SameLine = true

		focusButtons = { focusSelectors, focusBoth, focusMutators }
		---@param button ExtuiButton
		local function changeFocus(button)
			for _, focusButton in pairs(focusButtons) do
				if focusButton.Handle == button.Handle then
					focusButton:SetColor("Button", activeButtonColor)
					focusButton.UserData = true
				else
					focusButton:SetColor("Button", disabledButtonColor)
					focusButton.UserData = false
				end
			end

			buildDesignerFunc()
		end

		focusSelectors.OnClick = changeFocus
		focusBoth.OnClick = changeFocus
		focusMutators.OnClick = changeFocus
	end)

	buildDesignerFunc = function()
		if managerTable then
			managerTable:Destroy()
		end
		managerTable = parent:AddTable("ManagerTable", focusButtons[2].UserData and 2 or 1)
		managerTable.Borders = true

		local row = managerTable:AddRow()

		if focusButtons[2].UserData or focusButtons[1].UserData then
			local selectorColumn = row:AddCell()

			local title = Styler:CheapTextAlign("Selectors", selectorColumn, "Big")
			title.UserData = "keep"
			title.AllowOverlap = true

			local docs = MazzleDocs:addDocButton(selectorColumn)
			docs.AllowItemOverlap = true
			docs.UserData = "keep"
			docs.PositionOffset = Styler:ScaleFactor({ 0, -50 })

			Styler:MiddleAlignedColumnLayout(selectorColumn, function(ele)
				-- ele:AddText("Selectors").Font = "Big"
				local dryRunButton = ele:AddButton("Dry Run")
				dryRunButton.Disabled = false
				dryRunButton.UserData = "EnableForMods"

				---@type ExtuiWindow
				local resultsWindow

				dryRunButton.OnClick = function()
					if not resultsWindow then
						resultsWindow = Ext.IMGUI.NewWindow("Dry Run Results###resultswindow")
						resultsWindow.Closeable = true
						resultsWindow.AlwaysAutoResize = true
						resultsWindow.Scaling = "Scaled"
					else
						resultsWindow.Open = true
						resultsWindow:SetFocus()
						Helpers:KillChildren(resultsWindow)
					end

					local predicate = SelectorInterface:createComposedPredicate(existingMutation.selectors._real or existingMutation.selectors)

					local maxCols = 10
					local resultCounter = 0
					for level, entities in pairs(EntityRecorder:GetEntities()) do
						local header = resultsWindow:AddCollapsingHeader(level)
						header:SetColor("Header", { 1, 1, 1, 0 })
						Styler:ScaledFont(header, "Large")
						header.DefaultOpen = true

						local columnCounter = 0

						for entity, record in TableUtils:OrderedPairs(entities, function(key)
							return entities[key].Name
						end) do
							if predicate:Test(record) then
								resultCounter = resultCounter + 1
								columnCounter = columnCounter + 1

								local group = header:AddChildWindow(level .. entity)
								group.Font = "Medium"
								group.NoSavedSettings = true
								group.Size = Styler:ScaleFactor({ 100, 100 })
								group.SameLine = columnCounter > 1 and columnCounter % maxCols ~= 1

								Styler:MiddleAlignedColumnLayout(group, function(ele)
									local image = ele:AddImage(record.Icon, Styler:ScaleFactor({ 64, 64 }))
									if image.ImageData.Icon == "" then
										ele:AddImage("Item_Unknown", { 64, 64 })
									end
								end)

								Styler:MiddleAlignedColumnLayout(group, function(ele)
									local hyperlink = Styler:HyperlinkText(ele, record.Name, function(parent)
										CharacterWindow:BuildWindow(parent, entity)
									end)
									Styler:ScaledFont(hyperlink, "Small")
								end)
							end
						end
						if columnCounter == 0 then
							header:Destroy()
						else
							header.Label = string.format("%s - %s Results", header.Label, columnCounter)
						end
					end

					if resultCounter == 0 then
						Styler:ScaledFont(resultsWindow:AddText("No Entities Selected"), "Large")
					end

					resultsWindow.Label = string.format("%s - %s Results###resultswindow", "Dry Run", resultCounter)
				end
			end).UserData = "keep"

			self:RenderSelectors(selectorColumn, existingMutation.selectors, existingMutation.prepPhase)
		end
		if focusButtons[2].UserData or focusButtons[3].UserData then
			local setting = ConfigurationStructure.config.mutations.settings.mutationDesigner

			local mutatorColumn = row:AddCell()

			local title = Styler:CheapTextAlign(("%s"):format(existingMutation.prepPhase and "Prep Mutator" or "Mutators"), mutatorColumn, "Big")
			title.UserData = "keep"
			title.AllowOverlap = true

			local docs = MazzleDocs:addDocButton(mutatorColumn)
			docs.PositionOffset = Styler:ScaleFactor({ 0, -50 })
			docs.AllowItemOverlap = true
			docs.UserData = "keep"

			Styler:MiddleAlignedColumnLayout(mutatorColumn, function(ele)
				Styler:ScaledFont(ele, "Small")

				if not existingMutation.prepPhase then
					Styler:DualToggleButton(ele, "Sidebar", "Infinite Scroll", false, function(swap)
						if swap then
							setting.mutatorStyle = setting.mutatorStyle ~= "Sidebar" and "Sidebar" or "Infinite"
							buildDesignerFunc()
						end
						return setting.mutatorStyle == "Sidebar"
					end)
				else
					ele:AddNewLine()
				end
			end).UserData = "keep"

			if setting.mutatorStyle == "Infinite" or existingMutation.prepPhase then
				self:RenderMutatorsInfiniteScroll(mutatorColumn, existingMutation.mutators, existingMutation.prepPhase)
			else
				self:RenderMutatorsSidebarStyle(mutatorColumn, existingMutation.mutators, existingMutation.prepPhase)
			end
		end

		if existingMutation.modId then
			---@param parent ExtuiTreeParent
			local function disableNonNavigatableElements(parent)
				local success = pcall(function(...)
					for _, child in pairs(parent.Children) do
						disableNonNavigatableElements(child)
					end
				end)

				if success or parent.UserData == "EnableForMods" then
					parent.Disabled = false
				else
					parent.Disabled = true
				end
			end

			for _, cell in ipairs(row.Children) do
				disableNonNavigatableElements(cell)
			end
		end
	end
	buildDesignerFunc()
end

---@param parent ExtuiTreeParent
---@param existingSelector SelectorQuery
---@param prepPhase boolean?
function MutationDesigner:RenderSelectors(parent, existingSelector, prepPhase)
	Helpers:KillChildren(parent)

	local selectorQueryTable = Styler:TwoColumnTable(parent, "selectorQuery")
	selectorQueryTable.Resizable = false
	selectorQueryTable.Borders = false
	selectorQueryTable.BordersV = false
	selectorQueryTable.BordersH = true

	for i = 0, #existingSelector, 2 do
		local andOrEntry = existingSelector[i]
		local selectorEntry = existingSelector[i + 1]

		if not selectorEntry then
			break
		end

		local row = selectorQueryTable:AddRow()
		local sideCell = row:AddCell()

		local delete = Styler:ImageButton(sideCell:AddImageButton("delete", "ico_red_x", Styler:ScaleFactor({ 16, 16 })))
		delete.UserData = i
		delete.OnClick = function()
			selectorEntry.delete = true
			if andOrEntry == nil then
				existingSelector[i + 2] = nil
			else
				existingSelector[i] = nil
			end

			TableUtils:ReindexNumericTable(existingSelector)

			self:RenderSelectors(parent, existingSelector, prepPhase)
		end

		if i > 0 then
			local upArrow = Styler:ImageButton(sideCell:AddImageButton("moveup", "scroll_up_d", Styler:ScaleFactor({ 16, 16 })))
			upArrow.OnClick = function()
				local currentSelector = TableUtils:DeeplyCopyTable(selectorEntry._real)
				selectorEntry.delete = true

				if i ~= 2 then
					existingSelector[i] = existingSelector[i - 2]
					existingSelector[i - 2] = andOrEntry
				end
				existingSelector[i + 1] = TableUtils:DeeplyCopyTable(existingSelector[i - 1]._real)
				existingSelector[i - 1].delete = true
				existingSelector[i - 1] = currentSelector

				self:RenderSelectors(parent, existingSelector, prepPhase)
			end
		end

		if i + 1 < #existingSelector then
			local downArrow = Styler:ImageButton(sideCell:AddImageButton("movedown", "scroll_down_d", Styler:ScaleFactor({ 16, 16 })))
			downArrow.OnClick = function()
				local currentSelector = TableUtils:DeeplyCopyTable(selectorEntry._real)
				selectorEntry.delete = true

				if i ~= 0 then
					existingSelector[i] = existingSelector[i + 2]
					existingSelector[i + 2] = andOrEntry
				end

				existingSelector[i + 1] = TableUtils:DeeplyCopyTable(existingSelector[i + 3]._real)
				existingSelector[i + 3].delete = true
				existingSelector[i + 3] = currentSelector

				self:RenderSelectors(parent, existingSelector, prepPhase)
			end
		end

		local entryCell = row:AddCell()

		if andOrEntry then
			Styler:DualToggleButton(entryCell, "AND", "OR", false, function(swap)
				if swap then
					existingSelector[i] = existingSelector[i] == "AND" and "OR" or "AND"
					andOrEntry = existingSelector[i]
				end
				return existingSelector[i] == "AND"
			end)
		end

		---@cast selectorEntry Selector

		local inclusiveBox = entryCell:AddCheckbox("Inclusive")
		inclusiveBox.Checked = selectorEntry.inclusive or false
		inclusiveBox.OnChange = function()
			selectorEntry.inclusive = inclusiveBox.Checked
		end

		local selectorCombo = entryCell:AddCombo("")
		selectorCombo.SameLine = true
		selectorCombo.WidthFitPreview = true
		local opts = {}
		for selectorName in TableUtils:OrderedPairs(SelectorInterface.registeredSelectors) do
			if not prepPhase or selectorName ~= PrepMarkerSelector.name then
				table.insert(opts, selectorName)
			end
		end
		selectorCombo.Options = opts
		selectorCombo.SelectedIndex = selectorEntry.criteriaCategory and (TableUtils:IndexOf(opts, selectorEntry.criteriaCategory) - 1) or -1

		local selectorGroup = entryCell:AddGroup("selector")

		selectorCombo.OnChange = function()
			Helpers:KillChildren(selectorGroup)
			if selectorEntry.criteriaValue then
				selectorEntry.criteriaValue.delete = true
			end

			selectorEntry.criteriaCategory = selectorCombo.Options[selectorCombo.SelectedIndex + 1]
			SelectorInterface.registeredSelectors[selectorEntry.criteriaCategory]:renderSelector(selectorGroup, selectorEntry)
			self:RenderSelectors(selectorGroup:AddGroup("SubSelectors"), selectorEntry.subSelectors)
		end

		if selectorEntry.criteriaCategory then
			SelectorInterface.registeredSelectors[selectorEntry.criteriaCategory]:renderSelector(selectorGroup, selectorEntry)
			self:RenderSelectors(selectorGroup:AddGroup("SubSelectors"), selectorEntry.subSelectors)
		end
	end

	local addNewEntryButton = parent:AddButton("Add New Entry")
	addNewEntryButton.OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		for selectorName in TableUtils:OrderedPairs(SelectorInterface.registeredSelectors) do
			if not existingSelector._parent_proxy.prepPhase or selectorName ~= PrepMarkerSelector.name then
				popup:AddSelectable(selectorName).OnClick = function()
					if #existingSelector >= 1 then
						table.insert(existingSelector, "AND")
					end
					table.insert(existingSelector, {
						criteriaCategory = selectorName,
						inclusive = true,
						subSelectors = {},
					} --[[@as Selector]])

					self:RenderSelectors(parent, existingSelector, prepPhase)
				end
			end
		end
	end

	local managePresetsButton = parent:AddButton("Manage Presets")
	managePresetsButton.SameLine = true
	managePresetsButton.OnClick = function()
		local presets = ConfigurationStructure.config.mutations.settings.mutationPresets.selectors

		Helpers:KillChildren(popup)
		popup:Open()

		for presetName, preset in TableUtils:OrderedPairs(presets) do
			---@type ExtuiMenu
			local presetMenu = popup:AddMenu(presetName)
			---@type ExtuiMenu
			local loadMenu = presetMenu:AddMenu("Load")

			loadMenu:AddSelectable("Add To Active Selectors").OnClick = function()
				existingSelector[#existingSelector + 1] = "AND"
				table.move(TableUtils:DeeplyCopyTable(preset), 1, #preset, #existingSelector + 1, existingSelector)
				if type(existingSelector[1]) == "string" then
					existingSelector[1] = nil
					TableUtils:ReindexNumericTable(existingSelector)
				end
				self:RenderSelectors(parent, existingSelector, prepPhase)
			end

			loadMenu:AddSelectable("Replace Active Selectors").OnClick = function()
				for i, entry in ipairs(existingSelector) do
					if type(entry) == "string" then
						existingSelector[i] = nil
					else
						entry.delete = true
					end
				end
				for i, entry in ipairs(preset) do
					existingSelector[i] = entry._real and TableUtils:DeeplyCopyTable(entry._real) or entry
				end

				if type(existingSelector[1]) == "string" then
					existingSelector[1] = nil
					TableUtils:ReindexNumericTable(existingSelector)
				end
				self:RenderSelectors(parent, existingSelector, prepPhase)
			end

			---@param selectable ExtuiSelectable
			presetMenu:AddSelectable("Overwrite Preset with Current Selectors", "DontClosePopups").OnClick = function(selectable)
				if selectable.Label ~= "Overwrite Preset with Current Selectors" then
					preset.delete = true
					presets[presetName] = TableUtils:DeeplyCopyTable(existingSelector._real)
					popup:SetCollapsed(true)
				else
					selectable.Label = "Are you sure?"
					selectable:SetColor("Text", { 1, 0.2, 0, 1 })
				end
			end
		end

		---@type ExtuiMenu
		local saveMenu = popup:AddMenu("Save Current Selectors")
		local nameInput = saveMenu:AddInputText("")
		---@param saveButton ExtuiButton
		saveMenu:AddButton("Save").OnClick = function(saveButton)
			if not presets[nameInput.Text] or saveButton.Label ~= "Save" then
				presets[nameInput.Text] = TableUtils:DeeplyCopyTable(existingSelector._real)
				managePresetsButton:OnClick()
			else
				saveButton.Label = "Overwrite Existing Preset?"
				saveButton:SetColor("Text", { 1, 0.2, 0, 1 })
			end
		end
	end
end

---@param managePresetsButton ExtuiButton
---@param mutators Mutator[]
---@param callback fun()
local function buildManageMutationPreset(managePresetsButton, mutators, callback)
	managePresetsButton.OnClick = function()
		local presets = ConfigurationStructure.config.mutations.settings.mutationPresets.mutators

		Helpers:KillChildren(popup)
		popup:Open()

		for presetName, preset in TableUtils:OrderedPairs(presets) do
			---@type ExtuiMenu
			local presetMenu = popup:AddMenu(presetName)
			---@type ExtuiMenu
			local loadMenu = presetMenu:AddMenu("Load")

			loadMenu:AddSelectable("Add Missing Mutators").OnClick = function()
				for _, mutator in ipairs(preset) do
					if not TableUtils:IndexOf(mutators, function(value)
							return value.targetProperty == mutator.targetProperty
						end) then
						table.insert(mutators, TableUtils:DeeplyCopyTable(mutator._real))
					end
				end
				callback()
			end

			loadMenu:AddSelectable("Replace Mutators With Same Property").OnClick = function()
				for _, mutator in ipairs(preset) do
					local existingIndex = TableUtils:IndexOf(mutators, function(value)
						return value.targetProperty == mutator.targetProperty
					end)

					if existingIndex then
						mutators[existingIndex].delete = true
						mutators[existingIndex] = TableUtils:DeeplyCopyTable(mutator._real)
					else
						table.insert(mutators, TableUtils:DeeplyCopyTable(mutator._real))
					end
				end
				callback()
			end

			loadMenu:AddSelectable("Replace All Mutators").OnClick = function()
				for i, existingMutator in ipairs(mutators) do
					existingMutator.delete = true
				end

				for _, mutator in ipairs(preset) do
					table.insert(mutators, TableUtils:DeeplyCopyTable(mutator._real))
				end
				callback()
			end

			---@param selectable ExtuiSelectable
			presetMenu:AddSelectable("Overwrite Preset with Current Mutators", "DontClosePopups").OnClick = function(selectable)
				if selectable.Label ~= "Overwrite Preset with Current Mutators" then
					preset.delete = true
					presets[presetName] = TableUtils:DeeplyCopyTable(mutators._real)
				else
					selectable.Label = "Are you sure?"
					selectable:SetColor("Text", { 1, 0.2, 0, 1 })
					selectable.DontClosePopups = false
				end
			end
		end

		---@type ExtuiMenu
		local saveMenu = popup:AddMenu("Save Current Mutators")
		local nameInput = saveMenu:AddInputText("")
		---@param saveButton ExtuiButton
		saveMenu:AddButton("Save").OnClick = function(saveButton)
			if not presets[nameInput.Text] or saveButton.Label ~= "Save" then
				presets[nameInput.Text] = TableUtils:DeeplyCopyTable(mutators._real)
				managePresetsButton:OnClick()
			else
				saveButton.Label = "Overwrite Existing Preset?"
				saveButton:SetColor("Text", { 1, 0.2, 0, 1 })
			end
		end
	end
end

---@param parent ExtuiTreeParent
---@param mutators Mutator[]
---@param prepPhase boolean?
function MutationDesigner:RenderMutatorsInfiniteScroll(parent, mutators, prepPhase)
	Helpers:KillChildren(parent)

	local mutatorTable = Styler:TwoColumnTable(parent, "Mutators")
	mutatorTable.ColumnDefs[1].Width = 20
	mutatorTable.BordersV = false
	mutatorTable.Resizable = false
	mutatorTable.Borders = false
	mutatorTable.BordersH = true

	for i, mutator in TableUtils:OrderedPairs(mutators, function(key, value)
		return MutatorInterface.registeredMutators[value.targetProperty]
			and MutatorInterface.registeredMutators[value.targetProperty]:priority()
			or MutatorInterface:priority() * 2 -- just making sure unconfigured mutators are shown last
	end) do
		local row = mutatorTable:AddRow()
		local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", { 16, 16 }))
		delete.OnClick = function()
			for x = i, TableUtils:CountElements(mutators) do
				mutators[x].delete = true
				mutators[x] = TableUtils:DeeplyCopyTable(mutators._real[x + 1])
			end

			self:RenderMutatorsInfiniteScroll(parent, mutators, prepPhase)
		end

		local mutatorCell = row:AddCell()


		local mutatorCombo = mutatorCell:AddCombo("")
		mutatorCombo.Visible = not prepPhase
		Styler:ScaledFont(mutatorCombo, "Large")
		mutatorCombo.WidthFitPreview = true
		local opts = {}
		local selectedIndex = -1
		for mutatorName in TableUtils:OrderedPairs(MutatorInterface.registeredMutators) do
			if mutatorName == mutator.targetProperty or not TableUtils:IndexOf(mutators, function(value)
					return value.targetProperty == mutatorName
				end)
			then
				table.insert(opts, mutatorName)
				if mutatorName == mutator.targetProperty then
					selectedIndex = #opts - 1
				end
			end
		end
		mutatorCombo.Options = opts
		mutatorCombo.SelectedIndex = selectedIndex

		local mutatorGroup = mutatorCell:AddGroup(mutator.targetProperty)
		mutatorCombo.OnChange = function()
			mutator.targetProperty = mutatorCombo.Options[mutatorCombo.SelectedIndex + 1]
			mutator.modifiers = {}
			mutator.values = nil
			MutatorInterface.registeredMutators[mutator.targetProperty]:renderMutator(mutatorGroup, mutator)

			self:RenderMutatorsInfiniteScroll(parent, mutators, prepPhase)
		end

		if mutator.targetProperty and mutator.targetProperty ~= "" then
			MutatorInterface.registeredMutators[mutator.targetProperty]:renderMutator(mutatorGroup, mutator)
		end

		mutatorCell:AddNewLine()
	end
	if not prepPhase then
		Styler:MiddleAlignedColumnLayout(parent, function(ele)
			local addNewEntryButton = ele:AddButton("+")
			addNewEntryButton.OnClick = function()
				Helpers:KillChildren(popup)
				popup:Open()

				for mutatorName in TableUtils:OrderedPairs(MutatorInterface.registeredMutators) do
					if not TableUtils:IndexOf(mutators, function(value)
							return value.targetProperty == mutatorName
						end)
						and mutatorName ~= PrepPhaseMarkerMutator.name
					then
						popup:AddSelectable(mutatorName).OnClick = function()
							table.insert(mutators, {
								targetProperty = mutatorName
							} --[[@as Mutator]])

							self:RenderMutatorsInfiniteScroll(parent, mutators, prepPhase)
						end
					end
				end
			end

			local managePresetsButton = ele:AddButton("Manage Presets")
			managePresetsButton.SameLine = true
			buildManageMutationPreset(managePresetsButton, mutators, function()
				self:RenderMutatorsInfiniteScroll(parent, mutators, prepPhase)
			end)
		end)
	end
end

---@param parent ExtuiTreeParent
---@param mutators Mutator[]
---@param activeMutator string?
---@param prepPhase boolean?
function MutationDesigner:RenderMutatorsSidebarStyle(parent, mutators, activeMutator, prepPhase, popupToUse)
	Helpers:KillChildren(parent)
	popupToUse = popupToUse or popup

	local mutatorTable = Styler:TwoColumnTable(parent, "mutators")
	mutatorTable.Resizable = false
	local row = mutatorTable:AddRow()
	local sideBar = row:AddCell()
	local designer = row:AddCell()

	---@type ExtuiSelectable?
	local activeMutatorHandle

	for i, mutator in TableUtils:OrderedPairs(mutators, function(key, value)
		return MutatorInterface.registeredMutators[value.targetProperty]:priority()
	end) do
		local delete = Styler:ImageButton(sideBar:AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", Styler:ScaleFactor({ 16, 16 })))
		delete.OnClick = function()
			for x = i, TableUtils:CountElements(mutators) do
				mutators[x].delete = true
				mutators[x] = TableUtils:DeeplyCopyTable(mutators._real[x + 1])
			end

			self:RenderMutatorsSidebarStyle(parent, mutators, activeMutatorHandle and activeMutatorHandle.Label, prepPhase, popupToUse)
		end

		---@type ExtuiSelectable
		local select = sideBar:AddSelectable(mutator.targetProperty)
		select.SameLine = true
		select.UserData = "EnableForMods"
		select.OnClick = function()
			if activeMutatorHandle then
				activeMutatorHandle.Selected = false
				Helpers:KillChildren(designer)
			end

			activeMutatorHandle = select

			lastViewedMutator = mutator.targetProperty

			MutatorInterface.registeredMutators[mutator.targetProperty]:renderMutator(designer, mutator)
		end

		if mutator.targetProperty == activeMutator or mutator.targetProperty == lastViewedMutator or (not activeMutator and not activeMutatorHandle and not lastViewedMutator) then
			select.Selected = true
			select.OnClick()
		end
	end

	if not prepPhase then
		local addNewEntryButton = sideBar:AddButton("+")
		addNewEntryButton.OnClick = function()
			Helpers:KillChildren(popupToUse)
			popupToUse:Open()

			for mutatorName in TableUtils:OrderedPairs(MutatorInterface.registeredMutators) do
				if not TableUtils:IndexOf(mutators, function(value)
						return value.targetProperty == mutatorName
					end)
					and mutatorName ~= PrepPhaseMarkerMutator.name
				then
					popupToUse:AddSelectable(mutatorName).OnClick = function()
						table.insert(mutators, {
							targetProperty = mutatorName
						} --[[@as Mutator]])

						self:RenderMutatorsSidebarStyle(parent, mutators, activeMutatorHandle and activeMutatorHandle.Label, prepPhase, popupToUse)
					end
				end
			end
		end

		local managePresetsButton = sideBar:AddButton("MP")
		managePresetsButton:Tooltip():AddText("\t Manage Mutator Presets")
		managePresetsButton.SameLine = true
		buildManageMutationPreset(managePresetsButton, mutators, function()
			self:RenderMutatorsSidebarStyle(parent, mutators, activeMutatorHandle and activeMutatorHandle.Label, prepPhase, popupToUse)
		end)
	end
end
