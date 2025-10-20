Ext.Require("Shared/MonsterLab/MonsterLabModProxy.lua")

local config = ConfigurationStructure.config

---@param target string
---@return metatable
local buildMeta = function(target)
	return {
		__index = function(t, k)
			return MonsterLabModProxy.ModProxy[target][k] or config.monsterLab[target][k]
		end,
		__newindex = function(t, k, v)
			config.monsterLab[target][k] = v
		end,
		__pairs = function(t)
			local combined = {}

			for id, profile in TableUtils:CombinedPairs(config.monsterLab[target], MonsterLabModProxy.ModProxy[target]) do
				combined[id] = profile
			end

			return pairs(combined)
		end
	}
end

---@type MonsterLabConfig
---@diagnostic disable-next-line: missing-fields
MonsterLabConfigurationProxy = {
	profiles = setmetatable({}, buildMeta("profiles")),
	folders = setmetatable({}, buildMeta("folders")),
	rulesets = setmetatable({}, buildMeta("rulesets")),
	settings = config.monsterLab.settings
}
