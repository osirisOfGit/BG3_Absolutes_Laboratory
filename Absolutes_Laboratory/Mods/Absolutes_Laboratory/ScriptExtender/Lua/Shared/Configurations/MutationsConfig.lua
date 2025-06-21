---@class MutationsConfig
ConfigurationStructure.config.mutations = {}

---@class MutationSettings
ConfigurationStructure.config.mutations.settings = {
	---@class SpellBrowserSettings
	spellBrowser = {
		onlyIcons = true,
		sort = {
			---@type "displayName"|"spellName"
			name = "displayName",
			direction = "Descending"
		}
	}
}

---@alias ModDependencies {Guid : ModDependency}?

---@class ModDependency
ConfigurationStructure.DynamicClassDefinitions.modDependency = {
	---@type Guid
	modId = "",
	---@type integer[]
	modVersion = {},
	---@type string
	modAuthor = "",
	---@type string
	modName = "",
	---@type {string: string}
	packagedItems = {}
}

--#region Selectors
---@class Selector
ConfigurationStructure.DynamicClassDefinitions.selector = {
	inclusive = true,
	---@type string
	criteriaCategory = nil,
	criteriaValue = nil,
	---@type SelectorQuery
	subSelectors = {},
	---@type ModDependencies
	modDependencies = nil
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
	modifiers = nil,
	---@type ModDependencies
	modDependencies = nil,
}

--#endregion

---@class Mutation
ConfigurationStructure.DynamicClassDefinitions.mutations = {
	name = "",
	description = "",
	---@type SelectorQuery
	selectors = {},
	---@type Mutator[]
	mutators = {},
	---@type string?
	modId = nil,
}

---@class MutationFolder
ConfigurationStructure.DynamicClassDefinitions.folders = {
	name = "",
	description = "",
	---@type {[Guid]: Mutation}
	mutations = {},
	---@type Guid?
	modId = nil
}

---@type {[Guid] : MutationFolder}
ConfigurationStructure.config.mutations.folders = {}

--#region Profiles

---@class MutationProfile
ConfigurationStructure.DynamicClassDefinitions.profile = {
	name = "",
	description = "",
	defaultActive = false,
	---@type MutationProfileRule[]
	mutationRules = {},
	---@type Guid?
	modId = nil
}

---@class MutationProfileRule
ConfigurationStructure.DynamicClassDefinitions.profileMutationRule = {
	---@type Guid
	mutationFolderId = "",
	---@type Guid
	mutationId = "",
	---@type boolean
	additive = false
}

---@type {[Guid]: MutationProfile}
ConfigurationStructure.config.mutations.profiles = {}
--#endregion

--#region SpellList
---@type {[Guid]: SpellList}
ConfigurationStructure.config.mutations.spellLists = {}

---@alias SpellName string

---@class SpellSubLists
ConfigurationStructure.DynamicClassDefinitions.spellSubLists = {
	---@type SpellName[]?
	guaranteed = nil,
	---@type SpellName[]?
	randomized = nil,
	---@type SpellName[]?
	startOfCombatOnly = nil,
	---@type SpellName[]?
	onLoadOnly = nil,
	---@type SpellName[]?
	blackListed = nil
}

---@class LeveledSubList
---@field linkedProgressions {[Guid]: SpellSubLists}?
---@field selectedSpells SpellSubLists

---@class SpellList
ConfigurationStructure.DynamicClassDefinitions.leveledSpellList = {
	name = "",
	description = "",
	---@type Guid?
	modId = nil,
	---@type LeveledSubList[]?
	levels = nil,
	---@type ModDependencies
	modDependencies = nil
}

ConfigurationStructure.config.mutations.settings.spellLists = {
	subListColours = {
		guaranteed = { 0, 138, 172, 0.8 },
		randomized = { 124, 14, 43, 0 },
		startOfCombatOnly = { 217, 118, 6, 0.8 },
		onLoadOnly = { 217, 179, 6, 0.8 },
		blackListed = { .5, .5, .5, 1 },
	}
}

--#endregion
