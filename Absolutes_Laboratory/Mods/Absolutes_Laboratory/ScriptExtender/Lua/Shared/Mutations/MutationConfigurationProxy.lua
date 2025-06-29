Ext.Require("Shared/Mutations/External/MutationModProxy.lua")

local mutationsConfig = ConfigurationStructure.config.mutations

if Ext.IsServer() then
	Ext.RegisterNetListener(ModuleUUID .. "_UpdateConfiguration", function(channel, payload, user)
		mutationsConfig = ConfigurationStructure.config.mutations._real
	end)
end

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
		end,
		__pairs = function(t)
			local spellLists = TableUtils:DeeplyCopyTable(mutationsConfig.spellLists._real)

			for _, modCache in pairs(MutationModProxy.ModProxy.spellLists) do
				---@cast modCache LocalModCache

				if modCache.spellLists and next(modCache.spellLists) then
					for spellListId in pairs(modCache.spellLists) do
						spellLists[spellListId] = MutationModProxy.ModProxy.spellLists[spellListId]
					end
				end
			end

			return pairs(spellLists)
		end
	}),
}
