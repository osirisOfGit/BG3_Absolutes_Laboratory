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
	self:RenderSelectors(selectorColumn, existingMutation.selectors)

	local mutationColumn = row:AddCell()
end

---@param parent ExtuiTreeParent
---@param existingSelector SelectorQuery
function MutationManager:RenderSelectors(parent, existingSelector)
	Helpers:KillChildren(parent)

	local selectorQueryTable = parent:AddTable("selectorQuery", 2)
	selectorQueryTable:AddColumn("", "WidthFixed")
	selectorQueryTable:AddColumn("", "WidthStretch")
	selectorQueryTable.BordersInnerH = true
	selectorQueryTable.BordersInnerV = true

	for i, selectorEntry in TableUtils:OrderedPairs(existingSelector) do
		local row = selectorQueryTable:AddRow()

		local entrySwapperCell = row:AddCell()
		local entryCell = row:AddCell()

		local choiceCombo = entrySwapperCell:AddCombo("")
		choiceCombo.Options = { "And/Or", "Selector" }
		choiceCombo.SelectedIndex = type(selectorEntry) == "string" and 0 or 1

		choiceCombo.OnChange = function()
			if choiceCombo.SelectedIndex == 0 then
				existingSelector[i] = "AND"
			else
				existingSelector[i] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.selector)
			end
			self:RenderSelectors(parent, existingSelector)
		end

		local deleteButton = entrySwapperCell:AddButton("Delete")
		deleteButton.SameLine = true
		deleteButton.OnClick = function ()
			table.remove(existingSelector, i)
			self:RenderSelectors(parent, existingSelector)
		end

		if choiceCombo.SelectedIndex == 0 then
			local grouperCombo = entryCell:AddCombo("")
			grouperCombo.Options = { "AND", "OR" }
			grouperCombo.SelectedIndex = selectorEntry == "AND" and 0 or 1
			grouperCombo.WidthFitPreview = true

			grouperCombo.OnChange = function()
				existingSelector[i] = grouperCombo.Options[grouperCombo.SelectedIndex + 1]
			end
		else
			local selectorCombo = entryCell:AddCombo("")
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
				existingSelector[i] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.selector)

				existingSelector[i].criteriaCategory = selectorCombo.Options[selectorCombo.SelectedIndex + 1]
				self.selectors[selectorCombo.Options[selectorCombo.SelectedIndex + 1]]:renderSelector(selectorGroup, existingSelector[i], function(selector)
					existingSelector[i] = selector
				end)
			end

			if selectorEntry.criteriaCategory then
				self.selectors[selectorEntry.criteriaCategory]:renderSelector(selectorGroup, selectorEntry, function(selector)
					existingSelector[i] = selector
				end)

				self:RenderSelectors(selectorGroup, selectorEntry.subSelectors)
			end
		end
	end

	Styler:MiddleAlignedColumnLayout(parent, function (ele)
		local addNewEntryButton = ele:AddButton("Add New Entry")
		addNewEntryButton.OnClick = function ()
			table.insert(existingSelector, "AND")
			self:RenderSelectors(parent, existingSelector)
		end
	end)
end
