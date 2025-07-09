Ext.Require("Shared/Mutations/Mutators/PassiveList/PassiveListDesigner.lua")

---@class PassiveListMutatorClass : MutatorInterface
PassiveListMutator = MutatorInterface:new("PassiveList")

function PassiveListMutator:priority()
	return self:recordPriority(SpellListMutator:priority() + 1)
end

function PassiveListMutator:canBeAdditive()
	return true
end

---@class PassivePool
---@field passiveLists Guid[]
---@field passives CustomSubList?
---@field removePassives string[]

---@class PassiveMutator : Mutator
---@field values PassivePool

---@param mutator PassiveMutator
function PassiveListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	Helpers:KillChildren(parent)

	local passiveListDesignerButton = parent:AddButton("Open Passive List Designer")
	passiveListDesignerButton.UserData = "EnableForMods"
	passiveListDesignerButton.OnClick = function()
		PassiveListDesigner:launch()
	end
end
