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
			---@type {[Guid]: CustomList}
			local spellLists = TableUtils:DeeplyCopyTable(mutationsConfig.spellLists._real)

			for _, modCache in pairs(MutationModProxy.ModProxy.spellLists) do
				---@cast modCache LocalModCache

				if modCache.spellLists and next(modCache.spellLists) then
					for spellListId in pairs(modCache.spellLists) do
						spellLists[spellListId] = MutationModProxy.ModProxy.spellLists[spellListId]
					end
				end
			end

			return TableUtils:OrderedPairs(spellLists, function(key, value)
				return (value.modId or "_") .. value.name
			end)
		end
	}),
	passiveLists = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.passiveLists[k] or MutationModProxy.ModProxy.passiveLists[k]
		end,
		__pairs = function(t)
			---@type {[Guid]: CustomList}
			local passiveLists = TableUtils:DeeplyCopyTable(mutationsConfig.passiveLists._real)

			for _, modCache in pairs(MutationModProxy.ModProxy.passiveLists) do
				---@cast modCache LocalModCache

				if modCache.passiveLists and next(modCache.passiveLists) then
					for passiveListId in pairs(modCache.passiveLists) do
						passiveLists[passiveListId] = MutationModProxy.ModProxy.passiveLists[passiveListId]
					end
				end
			end

			return TableUtils:OrderedPairs(passiveLists, function(key, value)
				return (value.modId or "_") .. value.name
			end)
		end
	}),
	statusLists = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.statusLists[k] or MutationModProxy.ModProxy.statusLists[k]
		end,
		__pairs = function(t)
			---@type {[Guid]: CustomList}
			local statusLists = TableUtils:DeeplyCopyTable(mutationsConfig.statusLists._real)

			for _, modCache in pairs(MutationModProxy.ModProxy.statusLists) do
				---@cast modCache LocalModCache

				if modCache.statusLists and next(modCache.statusLists) then
					for statusListId in pairs(modCache.statusLists) do
						statusLists[statusListId] = MutationModProxy.ModProxy.statusLists[statusListId]
					end
				end
			end

			return TableUtils:OrderedPairs(statusLists, function(key, value)
				return (value.modId or "_") .. value.name
			end)
		end
	}),
}
