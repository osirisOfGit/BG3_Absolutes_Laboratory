Ext.Require("Client/Mutations/SpellList/SpellListDesigner.lua")

SpellListMutator = MutatorInterface:new("SpellList")

---@class SpellListMutator : Mutator
---@field values SpellListCriteriaEntry[]

---@param mutator SpellListMutator
function SpellListMutator:renderMutator(parent, mutator)
	parent:AddButton("Open SpellList Designer").OnClick = function()
		SpellListDesigner:buildSpellDesignerWindow(parent)
	end
end
