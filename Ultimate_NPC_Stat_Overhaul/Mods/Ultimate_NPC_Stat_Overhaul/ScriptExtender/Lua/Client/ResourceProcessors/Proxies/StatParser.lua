StatRouterProxy = ResourceProxy:new()

ResourceProxy:RegisterResourceProxy("Stats", StatRouterProxy)

function StatRouterProxy:RenderDisplayableValue(parent, resourceValue)
	if resourceValue then
		local function render(statValue)
			---@type StatusData
			local stat = Ext.Stats.Get(statValue)
			if stat then
				ResourceManager:RenderDisplayableValue(parent, statValue, stat.ModifierList)
			else
				ResourceManager:RenderDisplayableValue(parent, statValue)
			end
		end
		if type(resourceValue) == "table" then
			for _, stat in ipairs(resourceValue) do
				render(stat)
			end
		else
			render(resourceValue)
		end
	end
end
