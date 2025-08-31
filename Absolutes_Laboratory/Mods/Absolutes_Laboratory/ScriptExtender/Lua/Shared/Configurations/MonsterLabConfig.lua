---@class MonsterLabConfig
ConfigurationStructure.config.monsterLab = {
	---@type {[Guid] : MonsterLabProfile}
	profiles = {},
	---@type {[Guid]: MonsterLabFolder}
	folders = {}
}

---@class MonsterLabDynamicDefinitions
ConfigurationStructure.DynamicClassDefinitions.monsterLab = {}

---@class MonsterLabProfile
ConfigurationStructure.DynamicClassDefinitions.monsterLab.profile = {
	name = "",
	---@type string?
	description = nil,
	---@type {[Guid]: MonsterLabFolder}
	folders = {},
	---@type Guid?
	modId = nil
}

---@class MonsterLabFolder
ConfigurationStructure.DynamicClassDefinitions.monsterLab.folder = {
	name = "",
	---@type string?
	description = nil,
	---@type {[Guid] : MonsterLabEncounter}
	encounters = {},
	---@type Guid?
	modId = nil
}

---@class MonsterLabEncounter
ConfigurationStructure.DynamicClassDefinitions.monsterLab.encounter = {
	name = "",
	---@type string?
	description = nil,
	---@type Guid?
	existingCombatGroupId = nil,
	entities = {},
	---@type Guid?
	modId = nil
}

---@class MonsterLabEntity
ConfigurationStructure.DynamicClassDefinitions.monsterLab.entities = {
	displayName = "",
	title = "",
	---@type Guid
	template = nil,
	---@type number[] x,y,z
	coordinates = {}
}
