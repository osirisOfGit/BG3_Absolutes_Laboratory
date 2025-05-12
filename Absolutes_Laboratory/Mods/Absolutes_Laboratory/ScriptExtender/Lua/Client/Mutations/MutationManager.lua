MutationManager = {}

Ext.Require("Client/Mutations/Selectors/SelectorInterface.lua")

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

---@param parent ExtuiTreeParent
function MutationManager:RenderMutationManager(parent)
	local managerTable = Styler:TwoColumnTable(parent, "ManagerTable")

	local row = managerTable:AddRow()

	local selectorColumn = row:AddCell()

	local mutationColumn = row:AddCell()
end
