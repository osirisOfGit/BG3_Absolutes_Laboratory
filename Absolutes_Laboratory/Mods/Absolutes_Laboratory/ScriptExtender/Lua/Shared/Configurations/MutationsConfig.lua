---@class MutationsConfig
ConfigurationStructure.config.mutations = {}

---@class MutationSettings
ConfigurationStructure.config.mutations.settings = {}

--#region Selectors
---@class Selector
ConfigurationStructure.DynamicClassDefinitions.selector = {
	inclusive = true,
	criteriaCategory = nil,
	criteriaValue = nil,
	---@type SelectorQuery
	subSelectors = {}
}

---@alias SelectorGrouper "AND"|"OR"

---@alias SelectorQuery (SelectorGrouper|Selector)[]

--#endregion

--#region Mutators

---@class MutationModifier
ConfigurationStructure.DynamicClassDefinitions.modifier = {
	value = "",
	extraData = {}
}

---@class Mutator
ConfigurationStructure.DynamicClassDefinitions.mutator = {
	targetProperty = "",
	values = nil,
	---@type {[string]: MutationModifier}?
	modifiers = nil
}

--#endregion

---@class Mutation
ConfigurationStructure.DynamicClassDefinitions.mutations = {
	description = "",
	---@type SelectorQuery
	selectors = {},
	---@type Mutator[]
	mutators = {}
}

---@alias MutationName string

---@class MutationFolder
ConfigurationStructure.DynamicClassDefinitions.folders = {
	description = "",
	---@type {[MutationName]: Mutation}
	mutations = {}
}

---@alias FolderName string

---@type {[FolderName] : MutationFolder}
ConfigurationStructure.config.mutations.folders = {}


--#region Profiles

---@class MutationProfile
ConfigurationStructure.DynamicClassDefinitions.profile = {
	description = "",
	defaultActive = false,
	---@type MutationProfileRule[]
	mutationRules = {},
}

---@class MutationProfileRule
ConfigurationStructure.DynamicClassDefinitions.profileMutationRule = {
	---@type FolderName
	mutationFolder = "",
	---@type MutationName
	mutationName = "",
	---@type string?
	modId = nil,
	---@type string?
	modName = nil,
	---@type boolean
	additive = false
}

---@type {[string]: MutationProfile}
ConfigurationStructure.config.mutations.profiles = {}
--#endregion

--#region SpellList
---@type {[Guid]: SpellList}
ConfigurationStructure.config.mutations.spellLists = {}

---@alias SpellName string

---@class SpellListAbilityScoreCondition
---@field comparator "gte"|"lte"
---@field abilityId AbilityId
---@field value number

---@class SpellListCriteriaEntry
---@field isOneOfClasses string[]?
---@field abilityCondition SpellListAbilityScoreCondition[]?

---@class SpellList
ConfigurationStructure.DynamicClassDefinitions.leveledSpellList = {
	name = "",
	description = "",
	---@type Guid?
	modId = nil,
	---@type {[Guid]: SpellSubLists}?
	progressions = nil,
	---@class SpellSubLists
	subLists = {
		---@type SpellName[][]?
		guaranteed = {},
		---@type SpellName[][]?
		randomized = {},
		---@type SpellName[][]?
		startOfCombatOnly = {},
		---@type SpellName[][]?
		onLoadOnly = {},
		---@type SpellName[][]?
		blackListed = {}
	},
	---@type SpellListCriteriaEntry?
	criteria = {}
}

ConfigurationStructure.config.mutations.settings.spellLists = {
	subListColours  = {
		guaranteed = {0, 138, 172, 0.8},
		randomized = {124, 14, 43, 0},
		startOfCombatOnly = {217, 118, 6, 0.8},
		onLoadOnly = {217, 179, 6, 0.8},
		blackListed = {0, 0, 0, 1},
	}
}

--#endregion
