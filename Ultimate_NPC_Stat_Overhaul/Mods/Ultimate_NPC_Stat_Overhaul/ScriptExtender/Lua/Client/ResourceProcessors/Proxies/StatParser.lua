StatRouterProxy = ResourceProxy:new()

ResourceProxy:RegisterResourceProxy("Stats", StatRouterProxy)

function StatRouterProxy:RenderDisplayableValue(parent, resourceValue)
	if resourceValue then
		---@type StatusData
		local stat = Ext.Stats.Get(resourceValue)
		if stat then
			ResourceManager:RenderDisplayableValue(parent, resourceValue, stat.ModifierList)
		else
			ResourceManager:RenderDisplayableValue(parent, resourceValue)
		end
	end
end
