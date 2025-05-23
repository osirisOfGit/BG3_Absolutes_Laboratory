---@type {[string]: SpellList[]}
ConfigurationStructure.config.spellLists = {}

---@alias SpellName string

---@class SpellList
ConfigurationStructure.DynamicClassDefinitions.leveledSpellList = {
	---@type SpellName[]
	guaranteed = {},
	---@type SpellName[]
	randomized = {},
	---@type SpellName[]
	startOfCombatOnly = {}
}
