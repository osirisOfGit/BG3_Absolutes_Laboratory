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
		},
		showAllSpellLevels = false
	},
	mutationDesigner = {
		---@type "Sidebar"|"Infinite"
		mutatorStyle = "Sidebar"
	},
	mutationPresets = {
		---@type {[string]: Mutator[]}
		mutators = {},
		---@type {[string]: SelectorQuery[]}
		selectors = {}
	},
	actionResourceDistributionPresets = {
		["Default"] = {
			[1] = 1
		}
	},
	---@type {[string]: number[]}
	abilitiesDistributionPresets = {
		["Default"] = {
			[1] = 0
		}
	}
}

---@class PrepMarkerCategory
---@field name string
---@field description string?
---@field modId Guid?

---@type {[Guid]: PrepMarkerCategory}
ConfigurationStructure.config.mutations.prepPhaseMarkers = {
}

ConfigurationStructure.DynamicClassDefinitions.prepPhaseMarkers = {
	["a7e8e508-ee23-484d-ac49-67dfa78d2020"] = {
		name = "Boss",
		description = "Entities that are considered to be bosses (irrespective of their XPReward)",
	},
	["7bec1b31-0b70-445f-ae42-62ca8ac18ddc"] = {
		name = "MiniBoss",
		description = "Entities that are considered to be minibosses (irrespective of their XPReward)",
	},
	["0d0fea0e-6a01-42c2-bb76-efa6b41b9af8"] = { name = "Barbarian" },
	["bb06bab9-5b7d-4ec8-bc55-e4dd64afe74b"] = { name = "Bard" },
	["71efbd0c-10a6-41b8-9add-598eed11afc3"] = { name = "Cleric" },
	["6c3f19f2-6209-41ea-90d5-09978964378a"] = { name = "Druid" },
	["b0876cb8-ad50-42b8-affd-22c11349875e"] = { name = "Fighter" },
	["0f25fd8a-15c8-4a1a-b0f1-c435b9f78689"] = { name = "Monk" },
	["2910a1a8-ded1-4ead-a4fb-57c4f4918046"] = { name = "Paladin" },
	["f076b8a3-68b3-47e5-af20-ba93ecd1c1ad"] = { name = "Ranger" },
	["7293f1dc-b0a6-455d-975f-96b1e020fdb0"] = { name = "Rogue" },
	["94945836-3898-486b-95e1-2a62a07234a1"] = { name = "Sorcerer" },
	["f9d9b432-3671-4cfe-9187-92504bf2fbad"] = { name = "Wizard" },
	["fb2c85dd-12a4-43c1-9aae-5fe4f5230592"] = { name = "Warlock" },
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
	prepPhase = false,
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
	---@type MutationProfileRule[]
	prepPhaseMutations = {},
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
	additive = false,
	---@type ModDependency
	sourceMod = nil
}

---@type {[Guid]: MutationProfile}
ConfigurationStructure.config.mutations.profiles = {}
--#endregion

--#region Lists
---@class CustomListsSettings
ConfigurationStructure.config.mutations.settings.customLists = {
	subListColours = {
		guaranteed = { 0, 138, 172, 0.92 },
		randomized = { 124, 14, 43, 0 },
		startOfCombatOnly = { 217, 118, 6, 0.8 },
		onLoadOnly = { 217, 179, 6, 0.8 },
		blackListed = { 0.99, 0.96, 0.96, 0.80 },
		onDeathOnly = { 0.51, 0.24, 0.75, 1.0 },
	},
	autoCollapseFoldersSection = false,
	---@type "Icon"|"Text"
	iconOrText = "Icon",
	showSeperatorsInMain = true,
	defaultPool = {
		spellLists = "randomized",
		passiveLists = "guaranteed",
		statusLists = "guaranteed"
	},
	savedSpellListSpreads = {
		spellLists   = {
			["Default"] = {
				[1] = 2,
				[3] = 0,
				[5] = 1,
				[7] = 0,
				[10] = 1
			}
		},
		passiveLists = {
			["Default"] = {
				[1] = 1
			}
		},
		statusLists  = {
			["Default"] = {
				[1] = 1
			}
		}
	}
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
	blackListed = nil,
	---@type EntryName[]?
	onDeathOnly = nil
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
	---@type (LeveledSubList[]|{[GameLevel] : LeveledSubList})?
	levels = nil,
	---@type Guid[]
	linkedProgressionTableIds = {},
	---@type Guid[]
	linkedLists = {},
	---@type Guid[]?
	spellListDependencies = nil,
	---@type ModDependencies
	modDependencies = nil,
	useGameLevel = false,
	---@type string?
	defaultPool = nil,
	blacklistSameEntriesInHigherProgressionLevels = true
}

---@class MutationLists
ConfigurationStructure.config.mutations.lists = {
	---@class EntryReplacerDictionary
	entryReplacerDictionary = {
		---@type {[string]: string[]}
		spellLists = {},
		---@type {[string]: string[]}
		passiveLists = {},
		---@type {[string]: string[]}
		statusLists = {},
		---@type ModDependencies
		modDependencies = nil,
	},
	---@type {[Guid]: SpellList}
	spellLists = {},
	---@type {[Guid]: CustomList}
	passiveLists = {},
	---@type {[Guid]: CustomList}
	statusLists = {}
}

--#endregion
