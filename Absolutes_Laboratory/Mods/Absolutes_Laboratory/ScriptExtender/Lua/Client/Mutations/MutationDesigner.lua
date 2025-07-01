MutationDesigner = {}

Ext.Require("Shared/Mutations/Selectors/SelectorInterface.lua")
Ext.Require("Shared/Mutations/Mutators/MutatorInterface.lua")


---@param parent ExtuiTreeParent
---@param existingMutation Mutation
function MutationDesigner:RenderMutationManager(parent, existingMutation)
	if existingMutation.modId then
		Styler:CheapTextAlign("Mod-Added Mutation - You can browse, but not edit", parent, "Large"):SetColor("Text", { 1, 0, 0, 0.45 })
	end

	local managerTable = parent:AddTable("ManagerTable", 2)
	managerTable.Borders = true

	local row = managerTable:AddRow()

	local selectorColumn = row:AddCell()
	Styler:CheapTextAlign("Selectors", selectorColumn, "Big").UserData = "keep"
	Styler:MiddleAlignedColumnLayout(selectorColumn, function(ele)
		local dryRunButton = ele:AddButton("Dry Run Selectors")
		dryRunButton.Disabled = false
		dryRunButton.UserData = "keep"

		---@type ExtuiWindow
		local resultsWindow

		dryRunButton.OnClick = function()
			if not resultsWindow then
				resultsWindow = Ext.IMGUI.NewWindow("Dry Run Results###resultswindow")
				resultsWindow.Closeable = true
				resultsWindow.AlwaysAutoResize = true
			else
				resultsWindow.Open = true
				resultsWindow:SetFocus()
				Helpers:KillChildren(resultsWindow)
			end

			local predicate = SelectorInterface:createComposedPredicate(existingMutation.selectors._real)

			local maxCols = 10
			local resultCounter = 0
			for level, entities in pairs(EntityRecorder:GetEntities()) do
				local header = resultsWindow:AddCollapsingHeader(level)
				header:SetColor("Header", { 1, 1, 1, 0 })
				header.Font = "Large"
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
						group.Size = { 100, 100 }
						group.SameLine = columnCounter > 1 and columnCounter % maxCols ~= 1

						Styler:MiddleAlignedColumnLayout(group, function(ele)
							local image = ele:AddImage(record.Icon, { 64, 64 })
							if image.ImageData.Icon == "" then
								ele:AddImage("Item_Unknown", { 64, 64 })
							end
						end)

						Styler:MiddleAlignedColumnLayout(group, function(ele)
							local hyperlink = Styler:HyperlinkText(ele, record.Name, function(parent)
								CharacterWindow:BuildWindow(parent, entity)
							end)
							hyperlink.Font = "Small"
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
				resultsWindow:AddText("No Entities Selected").Font = "Large"
			end

			resultsWindow.Label = string.format("%s - %s Results###resultswindow", "Dry Run", resultCounter)
		end
	end).UserData = "keep"

	self:RenderSelectors(selectorColumn, existingMutation.selectors)

	local mutatorColumn = row:AddCell()
	Styler:CheapTextAlign("Mutators", mutatorColumn, "Big").UserData = "keep"
	mutatorColumn:AddDummy(16, 40)
	self:RenderMutators(mutatorColumn, existingMutation.mutators)

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

		disableNonNavigatableElements(selectorColumn)
		disableNonNavigatableElements(mutatorColumn)
	end
end

---@param parent ExtuiTreeParent
---@param existingSelector SelectorQuery
function MutationDesigner:RenderSelectors(parent, existingSelector)
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

		local delete = Styler:ImageButton(sideCell:AddImageButton("delete", "ico_red_x", { 16, 16 }))
		delete.OnClick = function()
			for x = i, TableUtils:CountElements(existingSelector), 2 do
				if x > 0 then
					existingSelector[x] = nil
					existingSelector[x] = existingSelector[x + 2]
				end

				existingSelector[x + 1].delete = true
				existingSelector[x + 1] = TableUtils:DeeplyCopyTable(existingSelector._real[x + 3])
			end

			Helpers:KillChildren(parent)
			self:RenderSelectors(parent, existingSelector)
		end

		local entryCell = row:AddCell()

		if andOrEntry then
			local andText = entryCell:AddButton("AND")
			andText.Disabled = true
			andText:SetColor("Button", { 0, 0, 0, 0 })
			andText.SameLine = true

			local andOrSlider = entryCell:AddSliderInt("", andOrEntry == "AND" and 0 or 1, 0, 1)
			andOrSlider:SetColor("Text", { 1, 1, 1, 0 })
			andOrSlider.SameLine = true
			andOrSlider.ItemWidth = 80 * Styler:ScaleFactor()

			local orText = entryCell:AddButton("OR")
			orText.Disabled = true
			orText:SetColor("Button", { 0.38, 0.26, 0.21, 0.78 })
			orText.SameLine = true

			if existingSelector[i] == "AND" then
				andText:SetColor("Button", { 0.38, 0.26, 0.21, 0.78 })
				orText:SetColor("Button", { 0, 0, 0, 0 })
			else
				andText:SetColor("Button", { 0, 0, 0, 0 })
				orText:SetColor("Button", { 0.38, 0.26, 0.21, 0.78 })
			end

			andOrSlider.OnActivate = function()
				-- Prevents the user from keeping hold of the grab, triggering the Deactivate instantly
				-- Slider Grab POS won't update if changed during an OnClick or OnActivate event
				andOrSlider.Disabled = true
			end

			andOrSlider.OnDeactivate = function()
				andOrSlider.Disabled = false

				existingSelector[i] = existingSelector[i] == "AND" and "OR" or "AND"
				local newValue = existingSelector[i] == "AND" and 0 or 1
				andOrSlider.Value = { newValue, newValue, newValue, newValue }

				if existingSelector[i] == "AND" then
					andText:SetColor("Button", { 0.38, 0.26, 0.21, 0.78 })
					orText:SetColor("Button", { 0, 0, 0, 0 })
				else
					andText:SetColor("Button", { 0, 0, 0, 0 })
					orText:SetColor("Button", { 0.38, 0.26, 0.21, 0.78 })
				end
			end
		end

		---@cast selectorEntry Selector

		local inclusiveBox = entryCell:AddCheckbox("Inclusive")
		inclusiveBox.Checked = selectorEntry.inclusive
		inclusiveBox.OnChange = function()
			selectorEntry.inclusive = inclusiveBox.Checked
		end

		local selectorCombo = entryCell:AddCombo("")
		selectorCombo.SameLine = true
		selectorCombo.WidthFitPreview = true
		local opts = {}
		for selectorName in TableUtils:OrderedPairs(SelectorInterface.registeredSelectors) do
			table.insert(opts, selectorName)
		end
		selectorCombo.Options = opts
		selectorCombo.SelectedIndex = selectorEntry.criteriaCategory and (TableUtils:IndexOf(opts, selectorEntry.criteriaCategory) - 1) or -1

		local selectorGroup = entryCell:AddGroup("selector")

		selectorCombo.OnChange = function()
			Helpers:KillChildren(selectorGroup)
			if selectorEntry.criteriaValue then
				selectorEntry.criteriaValue.delete = true
				selectorEntry.criteriaValue = nil
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
		if #existingSelector >= 1 then
			table.insert(existingSelector, "AND")
		end
		table.insert(existingSelector, TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.selector))

		Helpers:KillChildren(parent)
		self:RenderSelectors(parent, existingSelector)
	end
end

---@param parent ExtuiTreeParent
---@param mutators Mutator[]
function MutationDesigner:RenderMutators(parent, mutators)
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
			Helpers:KillChildren(parent)
			self:RenderMutators(parent, mutators)
		end

		local mutatorCell = row:AddCell()

		local mutatorCombo = mutatorCell:AddCombo("")
		mutatorCombo.Font = "Large"
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
			Helpers:KillChildren(parent)
			self:RenderMutators(parent, mutators)
		end

		if mutator.targetProperty and mutator.targetProperty ~= "" then
			MutatorInterface.registeredMutators[mutator.targetProperty]:renderMutator(mutatorGroup, mutator)
		end

		mutatorCell:AddNewLine()
	end

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		local addNewEntryButton = ele:AddButton("+")
		addNewEntryButton.OnClick = function()
			table.insert(mutators,
				TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.mutator))

			Helpers:KillChildren(parent)
			self:RenderMutators(parent, mutators)
		end
	end)
end
