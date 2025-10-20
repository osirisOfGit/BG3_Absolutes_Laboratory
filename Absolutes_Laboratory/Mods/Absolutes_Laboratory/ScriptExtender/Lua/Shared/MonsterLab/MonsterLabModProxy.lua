MonsterLabModProxy = {
	fileName = "AbsolutesLaboratory_MonsterLab_ProfilesAndMutations"
}

---@param modId Guid
---@return MonsterLabConfig?
---@return Guid?
local function importMonsterLab(modId)
	local mod = Ext.Mod.GetMod(modId)
	if mod then
		---@type {["monsterLab"]: MonsterLabConfig?}
		local monsterLab = FileUtils:LoadTableFile(string.format("Mods/%s/%s", mod.Info.Directory, MonsterLabModProxy.Filename .. ".json"), "data")
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

local function setModProxyFields(tbl, key, target)
	importModConfigs()

	local modId = TableUtils:IndexOf(modList, function(value)
		return value[target] and value[target][key] ~= nil
	end)

	if modId then
		local config = importMonsterLab(modId)
		if config then
			local targetEntry = config[target][key]
			targetEntry.modId = modId
			if targetEntry.encounters then
				for _, encounter in pairs(targetEntry.encounters) do
					encounter.modId = modId
				end
			end
			rawset(MonsterLabModProxy.ModProxy[target], key, config[target][key])
			return rawget(tbl, key)
		end
	end
end

---@type MonsterLabConfig
---@diagnostic disable-next-line: missing-fields
MonsterLabModProxy.ModProxy = {
	profiles = setmetatable({}, {
		__mode = 'k',
		__index = function(t, k)
			return setModProxyFields(t, k, "profiles")
		end,
		__newindex = function(t, k, v)
			Logger:BasicError("Tried to set a new value to a mod-sourced profile - key: %s | value: %s\n%s", k, v, debug.traceback())
		end
	}),

	folders = setmetatable({}, {
		__mode = 'k',
		__index = function(t, k)
			return setModProxyFields(t, k, "folders")
		end,
		__newindex = function(t, k, v)
			Logger:BasicError("Tried to set a new value to a mod-sourced folder - key: %s | value: %s\n%s", k, v, debug.traceback())
		end
	}),

	rulesets = setmetatable({}, {
		__mode = 'k',
		__index = function(t, k)
			return setModProxyFields(t, k, "rulesets")
		end,
		__newindex = function(t, k, v)
			Logger:BasicError("Tried to set a new value to a mod-sourced ruleset - key: %s | value: %s\n%s", k, v, debug.traceback())
		end
	})
}
