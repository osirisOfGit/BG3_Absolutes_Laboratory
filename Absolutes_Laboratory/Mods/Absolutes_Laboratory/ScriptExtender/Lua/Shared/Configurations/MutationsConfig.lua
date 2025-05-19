---@class MutationsConfig
ConfigurationStructure.config.mutations = {}

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
