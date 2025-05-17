MutationManager = {}

---@type {[string]: SelectorInterface}
MutationManager.selectors = {}
MutationManager.mutators = {}

---@param name string
---@param selector SelectorInterface
function MutationManager:registerSelector(name, selector)
	self.selectors[name] = selector
end

function MutationManager:registerMutator(name, mutator)
	self.mutators[name] = mutator
end

Ext.Require("Shared/Selectors/SelectorInterface.lua")

---@param parent ExtuiTreeParent
---@param existingMutation Mutation
function MutationManager:RenderMutationManager(parent, existingMutation)
	local managerTable = parent:AddTable("ManagerTable", 2)
	managerTable.Borders = true

	local row = managerTable:AddRow()

	local selectorColumn = row:AddCell()
	Styler:CheapTextAlign("Selectors", selectorColumn, "Big").UserData = "keep"
	Styler:MiddleAlignedColumnLayout(selectorColumn, function(ele)
		local dryRunButton = ele:AddButton("Dry Run Selectors")
		dryRunButton.UserData = "keep"

		---@type ExtuiWindow
		local resultsWindow

		dryRunButton.OnClick = function()
			if not resultsWindow then
				resultsWindow = Ext.IMGUI.NewWindow("Dry Run Results")
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
				header.IDContext = level .. "##x"
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
						group.Size = {100, 100}
						group.SameLine = columnCounter > 1 and columnCounter % maxCols ~= 1

						Styler:MiddleAlignedColumnLayout(group, function (ele)
							local image = ele:AddImage(record.Icon, { 64, 64 })
							if image.ImageData.Icon == "" then
								ele:AddImage("Item_Unknown", { 64, 64 })
							end
						end)

						local hyperlink = Styler:HyperlinkText(group, record.Name, function(parent)
							CharacterWindow:BuildWindow(parent, entity)
						end)
						hyperlink.Font = "Small"
						hyperlink:SetStyle("SelectableTextAlign", 0.5)
						hyperlink.Size = { 0, 0 }
					end
				end
				if columnCounter == 0 then
					header:Destroy()
				else
					header.Label = string.format("%s - %s Results", header.Label, columnCounter)
				end
			end

			resultsWindow.Label = string.format("%s - %s Results", "Dry Run", resultCounter)
		end
	end)

	self:RenderSelectors(selectorColumn, existingMutation.selectors)

	local mutationColumn = row:AddCell()
end

---@param parent ExtuiTreeParent
---@param existingSelector SelectorQuery
function MutationManager:RenderSelectors(parent, existingSelector)
	local selectorQueryTable = parent:AddTable("selectorQuery", 2)
	selectorQueryTable:AddColumn("", "WidthFixed")
	selectorQueryTable:AddColumn("", "WidthStretch")
	selectorQueryTable.Borders = true

	for i, selectorEntry in TableUtils:OrderedPairs(existingSelector) do
		local row = selectorQueryTable:AddRow()

		local entrySwapperCell = row:AddCell()
		local entryCell = row:AddCell()

		local choiceCombo = entrySwapperCell:AddCombo("")
		choiceCombo.Options = { "Selector", (i > 1 and type(existingSelector[i - 1]) ~= "string") and "And/Or" or nil }
		choiceCombo.SelectedIndex = type(selectorEntry) == "string" and 1 or 0

		choiceCombo.OnChange = function()
			existingSelector[i] = nil
			if choiceCombo.SelectedIndex == 1 then
				existingSelector[i] = "AND"
			else
				existingSelector[i] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.selector)
			end
			Helpers:KillChildren(parent)
			self:RenderSelectors(parent, existingSelector)
		end

		local deleteButton = entrySwapperCell:AddButton("Delete")
		deleteButton.SameLine = true
		deleteButton.OnClick = function()
			local nonproxyCopy = {}
			-- Pairs returns the non-proxy version of the configuration structure, but ipairs don't, so we do this nonsense to not
			-- insert the proxy tabls into the non-proxy backend
			for n, v in pairs(existingSelector) do
				nonproxyCopy[n] = v
			end
			table.remove(nonproxyCopy, i)
			if type(nonproxyCopy[1]) == "string" then
				table.remove(nonproxyCopy, 1)
			end

			for x in ipairs(existingSelector) do
				existingSelector[x] = nil
				existingSelector[x] = nonproxyCopy[x]
			end
			existingSelector[#existingSelector] = nil

			Helpers:KillChildren(parent)
			self:RenderSelectors(parent, existingSelector)
		end

		if choiceCombo.SelectedIndex == 1 then
			local grouperCombo = entryCell:AddCombo("")
			grouperCombo.Options = { "AND", "OR" }
			grouperCombo.SelectedIndex = selectorEntry == "AND" and 0 or 1
			grouperCombo.WidthFitPreview = true

			grouperCombo.OnChange = function()
				existingSelector[i] = nil
				existingSelector[i] = grouperCombo.Options[grouperCombo.SelectedIndex + 1]
			end
		else
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
			for selectorName in TableUtils:OrderedPairs(self.selectors) do
				table.insert(opts, selectorName)
			end
			selectorCombo.Options = opts
			selectorCombo.SelectedIndex = selectorEntry.criteriaCategory and (TableUtils:IndexOf(opts, selectorEntry.criteriaCategory) - 1) or -1

			local selectorGroup = entryCell:AddGroup("selector")

			selectorCombo.OnChange = function()
				Helpers:KillChildren(selectorGroup)
				selectorEntry.criteriaValue.delete = true
				selectorEntry.criteriaValue = nil

				selectorEntry.criteriaCategory = selectorCombo.Options[selectorCombo.SelectedIndex + 1]
				self.selectors[selectorEntry.criteriaCategory]:renderSelector(selectorGroup, selectorEntry)
				self:RenderSelectors(selectorGroup:AddGroup("SubSelectors"), selectorEntry.subSelectors)
			end

			if selectorEntry.criteriaCategory then
				self.selectors[selectorEntry.criteriaCategory]:renderSelector(selectorGroup, selectorEntry)
				self:RenderSelectors(selectorGroup:AddGroup("SubSelectors"), selectorEntry.subSelectors)
			end
		end
	end

	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		local addNewEntryButton = ele:AddButton("Add New Entry")
		addNewEntryButton.OnClick = function()
			table.insert(existingSelector,
				(#existingSelector <= 1 or type(existingSelector[#existingSelector]) == "string") and
				TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.selector) or "AND")
			Helpers:KillChildren(parent)
			self:RenderSelectors(parent, existingSelector)
		end
	end)
end
