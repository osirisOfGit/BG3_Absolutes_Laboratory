MonsterLabModProxy = {
	FileName = "AbsolutesLaboratory_MonsterLab_ProfilesAndMutations"
}

---@param modId Guid
---@return MonsterLabConfig?
---@return Guid?
local function importMonsterLab(modId)
	local mod = Ext.Mod.GetMod(modId)
	if mod then
		---@type {["monsterLab"]: MonsterLabConfig?}
		local monsterLab = FileUtils:LoadTableFile(string.format("Mods/%s/%s", mod.Info.Directory, MonsterLabModProxy.FileName .. ".json"), "data")
		if monsterLab then
			return monsterLab["monsterLab"], modId
		end
	end
end

---@class LocalMonsterLabModCache
---@field profiles {[Guid] : string}
---@field folders {[Guid] : string}
---@field rulesets {[Guid] : string}

---@type {[Guid]: LocalMonsterLabModCache}
local modList = {}

local haveImported
local function importModConfigs()
	if not haveImported then
		haveImported = true

		for _, modId in pairs(Ext.Mod.GetLoadOrder()) do
			local config = importMonsterLab(modId)
			if config then
				modList[modId] = {}

				for configKey in pairs(ConfigurationStructure.config.monsterLab) do
					if config[configKey] then
						modList[modId][configKey] = {}
						for id, entry in pairs(config[configKey]) do
							modList[modId][configKey][id] = entry.name
						end
					end
				end
			end
		end
	end
end

---@param modId Guid
---@param key "all"|string
---@param target "profiles"|"folders"|"rulesets"
local function setDataFromMod(modId, key, target)
	local config = importMonsterLab(modId)
	if config and config[target] then
		local function doIt(key, targetEntry)
			targetEntry.modId = modId
			if targetEntry.encounters then
				for _, encounter in pairs(targetEntry.encounters) do
					encounter.modId = modId
				end
			end
			rawset(MonsterLabModProxy.ModProxy[target], key, config[target][key])
		end

		if key ~= "all" then
			doIt(key, config[target][key])
		else
			for id, entry in pairs(config[target]) do
				doIt(id, entry)
			end
			return config[target]
		end
	end
end

---@param tbl table
---@param key string
---@param target "profiles"|"folders"|"rulesets"
local function setModProxyFields(tbl, key, target)
	importModConfigs()

	local modId = TableUtils:IndexOf(modList, function(value)
		return value[target] and (key ~= "all" or value[target][key] ~= nil)
	end)

	if modId then
		setDataFromMod(modId, key, target)
		return rawget(tbl, key)
	end
end

---@param name string
---@return metatable
local buildMetatable = function(name)
	return {
		__mode = 'k',
		__index = function(t, k)
			return setModProxyFields(t, k, name)
		end,
		__newindex = function(t, k, v)
			Logger:BasicError("Tried to set a new value to a mod-sourced %s - key: %s | value: %s\n%s", name, k, v, debug.traceback())
		end,
		__pairs = function(t)
			local collection = {}
			for modId, container in pairs(modList) do
				if container[name] then
					for id, entry in pairs(setDataFromMod(modId, "all", name)) do
						collection[id] = entry
					end
				end
			end

			return pairs(collection)
		end
	}
end

---@type MonsterLabConfig
---@diagnostic disable-next-line: missing-fields
MonsterLabModProxy.ModProxy = {
	profiles = setmetatable({}, buildMetatable("profiles")),

	folders = setmetatable({}, buildMetatable("folders")),

	rulesets = setmetatable({}, buildMetatable("rulesets"))
}
