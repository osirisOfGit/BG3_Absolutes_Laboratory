---@class MutationsConfig
ConfigurationStructure.config.mutations = {}

--#region Selectors
---@class Selector
ConfigurationStructure.DynamicClassDefinitions.selector = {
	inclusive = true,
	criteriaCategory = "",
	criteriaValue = "",
	---@type SelectorQuery
	subSelectors = {}
}

---@alias SelectorGrouper "AND"|"OR"

---@alias SelectorQuery {[SelectorGrouper] : Selector}

--#endregion

--#region Mutators

---@class MutationModifier
ConfigurationStructure.DynamicClassDefinitions.modifier = {
	criteriaKey = "",
	modifierValue = ""
}

---@class Mutator
ConfigurationStructure.DynamicClassDefinitions.mutator = {
	targetProperty = "",
	values = {},
	---@type MutationModifier?
	modifier = nil
}

--#endregion

---@class Mutation
ConfigurationStructure.DynamicClassDefinitions.mutations = {
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
