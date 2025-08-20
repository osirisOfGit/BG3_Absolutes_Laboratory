---@class MutationsConfig
ConfigurationStructure.config.mutations = {}

---@class MutationSettings
ConfigurationStructure.config.mutations.settings = {
	defaultProfile = nil,
	---@class StatBrowserSettings
	statBrowser = {
		onlyIcons = true,
		sort = {
			---@type "displayName"|"spellName"
			name = "displayName",
			direction = "Descending"
		}
	},
	mutationDesigner = {
		---@type "Sidebar"|"Infinite"
		mutatorStyle = "Sidebar"
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

--#region Lists
---@alias EntryName string

---@class CustomSubList
ConfigurationStructure.DynamicClassDefinitions.customSubList = {
	---@type EntryName[]?
	guaranteed = nil,
	---@type EntryName[]?
	randomized = nil,
	---@type EntryName[]?
	startOfCombatOnly = nil,
	---@type EntryName[]?
	onLoadOnly = nil,
	---@type EntryName[]?
	blackListed = nil
}

---@class LeveledSubList
---@field linkedProgressions {[Guid]: CustomSubList}?
---@field manuallySelectedEntries CustomSubList

---@class CustomList
ConfigurationStructure.DynamicClassDefinitions.customLeveledList = {
	name = "",
	description = "",
	---@type Guid?
	modId = nil,
	---@type LeveledSubList[]?
	levels = nil,
	---@type Guid[]?
	spellListDependencies = nil,
	---@type ModDependencies
	modDependencies = nil,
}

ConfigurationStructure.config.mutations.settings.customLists = {
	subListColours = {
		guaranteed = { 0, 138, 172, 0.8 },
		randomized = { 124, 14, 43, 0 },
		startOfCombatOnly = { 217, 118, 6, 0.8 },
		onLoadOnly = { 217, 179, 6, 0.8 },
		blackListed = { .5, .5, .5, 1 },
	},
	---@type "Icon"|"Text"
	iconOrText = "Icon"
}

---@class AbilityPriorities
---@field primaryStat AbilityId
---@field secondaryStat AbilityId
---@field tertiaryStat AbilityId
---@field fourth AbilityId
---@field fifth AbilityId
---@field sixth AbilityId

---@class SpellList : CustomList
---@field abilityPriorities AbilityPriorities

---@type {[Guid]: SpellList}
ConfigurationStructure.config.mutations.spellLists = {}

---@type {[Guid]: CustomList}
ConfigurationStructure.config.mutations.passiveLists = {}

---@type {[Guid]: CustomList}
ConfigurationStructure.config.mutations.statusLists = {}

--#endregion
