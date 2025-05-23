SpellListMutator = MutatorInterface:new("SpellList")

---@class SpellListAbilityScoreCondition
---@field comparator "gte"|"lte"
---@field abilityId AbilityId
---@field value number

---@class SpellListMutatorEntry
---@field isOneOfClasses string[]?
---@field abilityCondition SpellListAbilityScoreCondition[]?
---@field spellLists Guid[]

---@class SpellListMutator : Mutator
---@field values SpellListMutatorEntry[]

function SpellListMutator:renderMutator(parent, mutator)

end

---@type ExtuiWindow?
local spellListDesignerWindow
