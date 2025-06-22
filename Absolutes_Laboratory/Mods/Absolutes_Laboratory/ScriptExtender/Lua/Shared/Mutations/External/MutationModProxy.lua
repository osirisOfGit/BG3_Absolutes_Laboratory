MutationModProxy = {}

MutationModProxy.Filename = "AbsolutesLaboratory_ProfilesAndMutations"

---@class LocalModCache
---@field profiles {[Guid] : string}
---@field folders {[Guid] : string}
---@field spellLists {[Guid] : string}

---@type {[Guid] : LocalModCache}
local modList = {}

local function setModProxyFields(tbl, key, target)
	MutationModProxy:ImportMutationsFromMods()

	local modId = TableUtils:IndexOf(modList, function(value)
		return value[target] and value[target][key] ~= nil
	end)

	if modId then
		local mutationConfig = MutationModProxy:ImportMutation(modId)
		TableUtils:ConvertStringifiedNumberIndexes(mutationConfig)

		if mutationConfig.profiles then
			for profileId, profile in pairs(mutationConfig.profiles) do
				profile.modId = modId
				rawset(MutationModProxy.ModProxy.profiles, profileId, profile)
			end
		end

		if mutationConfig.folders then
			for folderId, folder in pairs(mutationConfig.folders) do
				folder.modId = modId
				for _, mutation in pairs(folder.mutations) do
					mutation.modId = modId
				end

				rawset(MutationModProxy.ModProxy.folders, folderId, folder)
			end
		end

		if mutationConfig.spellLists then
			for spellListId, spellList in pairs(mutationConfig.spellLists) do
				spellList.modId = modId
				rawset(MutationModProxy.ModProxy.spellLists, spellListId, spellList)
			end
		end
		return rawget(tbl, key)
	end
end

---@type MutationsConfig
---@diagnostic disable-next-line: missing-fields
MutationModProxy.ModProxy = {
	profiles = setmetatable({}, {
		__mode = "k",
		__index = function(t, k)
			return setModProxyFields(t, k, "profiles")
		end,
		__pairs = function(t)
			return pairs(modList)
		end
	}),
	folders = setmetatable({}, {
		__mode = "k",
		__call = function(t)
			MutationModProxy:ImportMutationsFromMods()
			return TableUtils:CountElements(modList)
		end,
		__index = function(t, k)
			return setModProxyFields(t, k, "folders")
		end,
		__pairs = function(t)
			return pairs(modList)
		end
	}),
	spellLists = setmetatable({}, {
		__mode = "k",
		__index = function(t, k)
			return setModProxyFields(t, k, "spellLists")
		end,
		__call = function(t)
			MutationModProxy:ImportMutationsFromMods()
			return TableUtils:CountElements(modList)
		end,
		__pairs = function(t)
			return pairs(modList)
		end
	})
}

---@param modId Guid
---@return MutationsConfig?
---@return Guid?
function MutationModProxy:ImportMutation(modId)
	local mod = Ext.Mod.GetMod(modId)
	if mod then
		---@type MutationsConfig?
		local mutations = FileUtils:LoadTableFile(string.format("Mods/%s/%s", mod.Info.Directory, self.Filename .. ".json"), "data")
		if mutations then
			return mutations.mutations, modId
		end
	end
end

local haveImported
function MutationModProxy:ImportMutationsFromMods()
	if not haveImported then
		haveImported = true

		for _, modId in pairs(Ext.Mod.GetLoadOrder()) do
			local mutations = self:ImportMutation(modId)
			if mutations then
				modList[modId] = {}
				local modEntry = modList[modId]

				if mutations.profiles and next(mutations.profiles) then
					modEntry.profiles = {}
					for profileId, profile in pairs(mutations.profiles) do
						modEntry.profiles[profileId] = profile.name
					end
				end

				if mutations.folders and next(mutations.folders) then
					modEntry.folders = {}
					for folderId, folder in pairs(mutations.folders) do
						modEntry.folders[folderId] = folder.name
					end
				end

				if mutations.spellLists and next(mutations.spellLists) then
					modEntry.spellLists = {}
					for spellListId, spellList in pairs(mutations.spellLists) do
						modEntry.spellLists[spellListId] = spellList.name
					end
				end
			end
		end
	end
end
