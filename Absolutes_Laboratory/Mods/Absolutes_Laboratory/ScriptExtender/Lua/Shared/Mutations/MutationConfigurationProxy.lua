Ext.Require("Shared/Mutations/External/MutationModProxy.lua")

local mutationsConfig = ConfigurationStructure.config.mutations

if Ext.IsServer() then
	Channels.UpdateConfiguration:SetHandler(function(payload, user)
		ConfigurationStructure:InitializeConfig()
		mutationsConfig = ConfigurationStructure.config.mutations
	end)
end

---@type MutationsConfig
---@diagnostic disable-next-line: missing-fields
MutationConfigurationProxy = {
	profiles = setmetatable({}, {
		__index = function(t, k)
			return MutationModProxy.ModProxy.profiles[k] or mutationsConfig.profiles[k]
		end
	}),
	folders = setmetatable({}, {
		__index = function(t, k)
			return MutationModProxy.ModProxy.folders[k] or mutationsConfig.folders[k]
		end
	}),
	prepPhaseMarkers = setmetatable({}, {
		__index = function(t, k)
			return MutationModProxy.ModProxy.prepPhaseMarkers[k] or mutationsConfig.prepPhaseMarkers[k]
		end,
		__pairs = function(t)
			---@type {[Guid]: PrepMarkerCategory}
			local markerCategories = TableUtils:DeeplyCopyTable(mutationsConfig.prepPhaseMarkers._real or mutationsConfig.prepPhaseMarkers)

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
				return MutationModProxy.ModProxy.lists.spellLists[k] or mutationsConfig.lists.spellLists[k]
			end,
			__pairs = function(t)
				---@type {[Guid]: CustomList}
				local spellLists = TableUtils:DeeplyCopyTable(mutationsConfig.lists.spellLists._real or mutationsConfig.lists.spellLists)

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
				return MutationModProxy.ModProxy.lists.passiveLists[k] or mutationsConfig.lists.passiveLists[k]
			end,
			__pairs = function(t)
				---@type {[Guid]: CustomList}
				local passiveLists = TableUtils:DeeplyCopyTable(mutationsConfig.lists.passiveLists._real or mutationsConfig.lists.passiveLists)

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
				return MutationModProxy.ModProxy.lists.statusLists[k] or mutationsConfig.lists.statusLists[k]
			end,
			__pairs = function(t)
				---@type {[Guid]: CustomList}
				local statusLists = TableUtils:DeeplyCopyTable(mutationsConfig.lists.statusLists._real or mutationsConfig.lists.statusLists)

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
				return MutationModProxy.ModProxy.lists.entryReplacerDictionary[k]
			end
		}),
	}
}
