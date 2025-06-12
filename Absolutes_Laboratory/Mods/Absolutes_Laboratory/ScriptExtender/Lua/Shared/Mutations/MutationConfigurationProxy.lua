Ext.Require("Shared/Mutations/External/MutationModProxy.lua")

local mutationsConfig = ConfigurationStructure.config.mutations

---@type MutationsConfig
---@diagnostic disable-next-line: missing-fields
MutationConfigurationProxy = {
	profiles = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.profiles[k] or MutationModProxy.ModProxy.profiles[k]
		end
	}),
	folders = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.folders[k] or MutationModProxy.ModProxy.folders[k]
		end
	}),
	spellLists = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.spellLists[k] or MutationModProxy.ModProxy.spellLists[k]
		end
	}),
}
