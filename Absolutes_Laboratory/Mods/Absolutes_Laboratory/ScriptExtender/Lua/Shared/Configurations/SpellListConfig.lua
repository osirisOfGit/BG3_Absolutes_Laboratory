---@type {[Guid]: SpellList[]}
ConfigurationStructure.config.spellLists = {}

---@alias SpellName string

---@class SpellList
ConfigurationStructure.DynamicClassDefinitions.leveledSpellList = {
	name = "",
	---@type SpellName[]
	guaranteed = {},
	---@type SpellName[]
	randomized = {},
	---@type SpellName[]
	startOfCombatOnly = {}
}
