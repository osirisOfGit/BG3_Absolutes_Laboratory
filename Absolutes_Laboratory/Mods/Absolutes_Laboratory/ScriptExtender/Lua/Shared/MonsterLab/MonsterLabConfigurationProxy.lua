Ext.Require("Shared/MonsterLab/MonsterLabModProxy.lua")

---@type MonsterLabConfig
MonsterLabConfigurationProxy = {
	profiles = setmetatable({}, {
		__index = function(t, k)

		end,
		__newindex = function(t, k, v)

		end,
		__pairs = function(t)

		end
	})
}
