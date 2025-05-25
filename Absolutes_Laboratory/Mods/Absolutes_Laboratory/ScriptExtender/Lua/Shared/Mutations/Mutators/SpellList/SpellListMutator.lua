Ext.Require("Shared/Mutations/Mutators/SpellList/SpellListDesigner.lua")

SpellListMutator = MutatorInterface:new("SpellList")

---@class SpellListMutator : Mutator
---@field values SpellListCriteriaEntry[]

---@param mutator SpellListMutator
function SpellListMutator:renderMutator(parent, mutator)
	parent:AddButton("Open SpellList Designer").OnClick = function()
		SpellListDesigner:buildSpellDesignerWindow()
	end
end

function SpellListMutator:applyMutator(entity, mutator)
	
end

function SpellListMutator:undoMutator(entity, mutator)
	
end
