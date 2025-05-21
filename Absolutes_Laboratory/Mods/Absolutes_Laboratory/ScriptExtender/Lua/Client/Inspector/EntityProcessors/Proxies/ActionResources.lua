ActionResourcesProxy = EntityProxy:new()
ActionResourcesProxy.fieldsToParse = {
	"Amount",
	"DiceValues",
	"Level",
	"MaxAmount",
	"ReplenishType",
	"ResourceId",
	"ResourceUUID",
	"SubAmounts",
	"field_28",
	"field_A8",
}

EntityProxy:RegisterResourceProxy("ActionResources", ActionResourcesProxy)
EntityProxy:RegisterResourceProxy("PreferredCastingResource", ActionResourcesProxy)
EntityProxy:RegisterResourceProxy("ResourceActionResource", ActionResourcesProxy)

local displayNameCache = {}

---@param resources {[string]: ActionResourceEntry[]}
function ActionResourcesProxy:RenderDisplayableValue(parent, resources, resourceType)
	if type(resources) == "table" then
		for resourceId, resource in TableUtils:OrderedPairs(resources, function(key)
			local cache = displayNameCache[key]
			if not cache then
				---@type ResourceActionResource
				local resource = Ext.StaticData.Get(key, "ActionResource")
				if resource then
					local name = resource.DisplayName:Get() or resource.Name
					displayNameCache[key] = name
					return name
				else
					return displayNameCache[key]
				end
			else
				return displayNameCache[key]
			end
		end) do
			local displayTable = Styler:TwoColumnTable(parent, resourceId)
			local row = displayTable:AddRow()
			row:AddCell():AddText(displayNameCache[resourceId] or resourceId)

			EntityManager:RenderDisplayableValue(row:AddCell(), resource)
		end
	elseif resources ~= "00000000-0000-0000-0000-000000000000" then
		---@type ResourceActionResource
		local resource = Ext.StaticData.Get(resources, "ActionResource")

		if resource then
			local cache = displayNameCache[resources]
			if not cache then
				local name = resource.DisplayName:Get() or resource.Name
				displayNameCache[resources] = name
				cache = name
			end

			Styler:HyperlinkText(parent, cache, function(parent)
				EntityManager:RenderDisplayWindow(resource, parent)
			end)
		else
			parent:AddText(resources)
		end
	end
end
