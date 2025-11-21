Ext.Require("Shared/Mutations/External/MutationModProxy.lua")

local mutationsConfig = ConfigurationStructure.config

if Ext.IsServer() then
	Channels.UpdateConfiguration:SetHandler(function(payload, user)
		ConfigurationStructure:InitializeConfig()
	end)
end

---@type MutationsConfig
---@diagnostic disable-next-line: missing-fields
MutationConfigurationProxy = {
	profiles = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.mutations.profiles[k] or MutationModProxy.ModProxy.profiles[k]
		end
	}),
	folders = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.mutations.folders[k] or MutationModProxy.ModProxy.folders[k]
		end
	}),
	prepPhaseMarkers = setmetatable({}, {
		__index = function(t, k)
			return mutationsConfig.mutations.prepPhaseMarkers[k] or MutationModProxy.ModProxy.prepPhaseMarkers[k]
		end,
		__pairs = function(t)
			---@type {[Guid]: PrepMarkerCategory}
			local markerCategories = TableUtils:DeeplyCopyTable(mutationsConfig.mutations.prepPhaseMarkers._real or mutationsConfig.mutations.prepPhaseMarkers)

			for _, modCache in pairs(MutationModProxy.ModProxy.prepPhaseMarkers) do
				---@cast modCache +LocalModCache

				if modCache.prepPhaseMarkers and next(modCache.prepPhaseMarkers) then
					for markerId, markerObject in pairs(modCache.prepPhaseMarkers) do
						markerCategories[markerId] = markerObject
					end
				end
			end

			return TableUtils:OrderedPairs(markerCategories, function(key, value)
				return (value.modId or "_") .. value.name
			end)
		end
	}),
	lists = {
		spellLists = setmetatable({}, {
			__index = function(t, k)
				return mutationsConfig.mutations.lists.spellLists[k] or MutationModProxy.ModProxy.lists.spellLists[k]
			end,
			__pairs = function(t)
				---@type {[Guid]: CustomList}
				local spellLists = TableUtils:DeeplyCopyTable(mutationsConfig.mutations.lists.spellLists._real or mutationsConfig.mutations.lists.spellLists)

				for _, modCache in pairs(MutationModProxy.ModProxy.lists.spellLists) do
					---@cast modCache +LocalModCache

					if modCache.lists and modCache.lists.spellLists and next(modCache.lists.spellLists) then
						for spellListId in pairs(modCache.lists.spellLists) do
							spellLists[spellListId] = MutationModProxy.ModProxy.lists.spellLists[spellListId]
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
				return mutationsConfig.mutations.lists.passiveLists[k] or MutationModProxy.ModProxy.lists.passiveLists[k]
			end,
			__pairs = function(t)
				---@type {[Guid]: CustomList}
				local passiveLists = TableUtils:DeeplyCopyTable(mutationsConfig.mutations.lists.passiveLists._real or mutationsConfig.mutations.lists.passiveLists)

				for _, modCache in pairs(MutationModProxy.ModProxy.lists.passiveLists) do
					---@cast modCache +LocalModCache

					if modCache.lists and modCache.lists.passiveLists and next(modCache.lists.passiveLists) then
						for passiveListId in pairs(modCache.lists.passiveLists) do
							passiveLists[passiveListId] = MutationModProxy.ModProxy.lists.passiveLists[passiveListId]
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
				return mutationsConfig.mutations.lists.statusLists[k] or MutationModProxy.ModProxy.lists.statusLists[k]
			end,
			__pairs = function(t)
				---@type {[Guid]: CustomList}
				local statusLists = TableUtils:DeeplyCopyTable(mutationsConfig.mutations.lists.statusLists._real or mutationsConfig.mutations.lists.statusLists)

				for _, modCache in pairs(MutationModProxy.ModProxy.lists.statusLists) do
					---@cast modCache +LocalModCache

					if modCache.lists and modCache.lists.statusLists and next(modCache.lists.statusLists) then
						for statusListId in pairs(modCache.lists.statusLists) do
							statusLists[statusListId] = MutationModProxy.ModProxy.lists.statusLists[statusListId]
						end
					end
				end

				return TableUtils:OrderedPairs(statusLists, function(key, value)
					return (value.modId or "_") .. value.name
				end)
			end
		}),
		entryReplacerDictionary = setmetatable({}, {
			__index = function(t, k)
				return mutationsConfig.mutations.lists.entryReplacerDictionary[k] or MutationModProxy.ModProxy.lists.entryReplacerDictionary[k]
			end
		}),
	}
}
