---@class MonsterLabConfig
ConfigurationStructure.config.monsterLab = {
	---@type {[Guid] : MonsterLabProfile}
	profiles = {},
	---@type {[Guid]: MonsterLabFolder}
	folders = {},
	---@type {[Guid]: MonsterLab_Ruleset}
	rulesets = {},
	---@class MonsterLabSettings
	settings = {
		---@type Guid?
		defaultActiveProfile = nil
	}
}

---@alias Lab_RulesetName string

---@class MonsterLabDynamicDefinitions
ConfigurationStructure.DynamicClassDefinitions.monsterLab = {}

---@class MonsterLabProfile
ConfigurationStructure.DynamicClassDefinitions.monsterLab.profile = {
	name = "",
	---@type string?
	description = nil,
	---@type MonsterLabProfileEncounterEntry[]
	encounters = {},
	---@type Guid?
	modId = nil,
}

---@class MonsterLabProfileEncounterEntry
ConfigurationStructure.DynamicClassDefinitions.monsterLab.profileEncounter = {
	---@type Guid
	folderId = "",
	---@type Guid
	encounterId = "",
	---@type ModDependency
	sourceMod = nil
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
	---@type {[Guid]: MonsterLabEntity}
	entities = {},
	---@type GameLevel
	gameLevel = nil,
	---@type number[]
	baseCoords = {},
	---@type Guid
	faction = "",
	---@type Guid
	combatGroupId = "",
	---@type Guid?
	modId = nil,
	---@type ModDependencies
	modDependencies = nil
}

---@class MonsterLab_RulesetRule
ConfigurationStructure.DynamicClassDefinitions.monsterLab.rulesetModifiers = {
	shouldSpawn = true,
	---@type Mutator[]
	mutators = {},
	composable = true
}

---@class MonsterLabEntity
ConfigurationStructure.DynamicClassDefinitions.monsterLab.entity = {
	displayName = "",
	title = "",
	---@type Guid
	template = nil,
	---@type number[] x,y,z
	coordinates = {},
	---@type number
	rotation = 0,
	---@type {[Lab_RulesetName]: MonsterLab_RulesetRule}
	rulesetModifiers = {
		["Base"] = ConfigurationStructure.DynamicClassDefinitions.monsterLab.rulesetModifiers
	},
	animation = {
		simple = "",
		looping = {
			startAnimation = "",
			loopAnimation = "",
			endAnimation = "",
			loopVariation1 = "",
			loopVariation2 = "",
			loopVariation3 = "",
			loopVariation4 = "",
		}
	}
}

---@class MonsterLab_Ruleset
ConfigurationStructure.DynamicClassDefinitions.monsterLab.ruleset = {
	---@type {[string]: (boolean)|(string[])}
	activeModifiers = {},
	name = "",
	description = "",
	modId = nil
}

---@enum Lab_RulesetModifiers
Lab_RulesetModifiers = {
	["AI_LETHALITY"] = "968ce114-d656-407c-88c2-0c071fe2181b",
	["CHARACTER_STATS_DIFFICULTY"] = "7d788f28-1df5-474b-b106-4f8d0b6de928",
	["HARD_MODE"] = "0bf382a5-e32a-4310-807c-6de89de471b2",
	["HIDE_NPC_HP"] = "9b349f94-e520-4c49-83e1-c0a8e0543710",
	["HONOUR_STATS"] = "ef0506df-da9f-40e2-903a-1349523c1ae4",
	["IRONMAN_MODE"] = "338450d9-d77d-4950-9e1e-0e7f12210bb3",
	["NO_DEATH_SAVING_THROWS "] = "8a26f431-6f20-4f62-9733-160c77fe4879",
	["NO_FREE_FIRST_STRIKE"] = "b2bf9487-6d94-4292-803f-1c2bdf0975c6",
	["NPC_CAN_CRITICAL_HIT"] = "ebb6a5ea-07d4-4176-b787-bbdab2758527",
	["NPC_LOADOUT"] = "4a8d7b18-b6ed-42f0-b542-c06ec11ceaea",
	["SCRIPTED_COMBAT_MECHANICS"] = "cac2d8bd-c197-4a84-9df1-f86f54ad4521",
	["SHORT_REST_FULLY_HEALS "] = "1d9a608a-3885-4d48-8816-458e40d1136e",
	["STABLE_RANDOMNESS"] = "c8234320-35f5-44ff-85a2-4e4366de02f2",
	["STORY_MODE "] = "1e8586e0-b957-4cf1-a0d4-aaf99f60d954",
	["968ce114-d656-407c-88c2-0c071fe2181b"] = "AI_LETHALITY",
	["7d788f28-1df5-474b-b106-4f8d0b6de928"] = "CHARACTER_STATS_DIFFICULTY",
	["0bf382a5-e32a-4310-807c-6de89de471b2"] = "HARD_MODE",
	["9b349f94-e520-4c49-83e1-c0a8e0543710"] = "HIDE_NPC_HP",
	["ef0506df-da9f-40e2-903a-1349523c1ae4"] = "HONOUR_STATS",
	["338450d9-d77d-4950-9e1e-0e7f12210bb3"] = "IRONMAN_MODE",
	["8a26f431-6f20-4f62-9733-160c77fe4879"] = "NO_DEATH_SAVING_THROWS",
	["b2bf9487-6d94-4292-803f-1c2bdf0975c6"] = "NO_FREE_FIRST_STRIKE",
	["ebb6a5ea-07d4-4176-b787-bbdab2758527"] = "NPC_CAN_CRITICAL_HIT",
	["4a8d7b18-b6ed-42f0-b542-c06ec11ceaea"] = "NPC_LOADOUT",
	["cac2d8bd-c197-4a84-9df1-f86f54ad4521"] = "SCRIPTED_COMBAT_MECHANICS",
	["1d9a608a-3885-4d48-8816-458e40d1136e"] = "SHORT_REST_FULLY_HEALS",
	["c8234320-35f5-44ff-85a2-4e4366de02f2"] = "STABLE_RANDOMNESS",
	["1e8586e0-b957-4cf1-a0d4-aaf99f60d954"] = "STORY_MODE",
}
