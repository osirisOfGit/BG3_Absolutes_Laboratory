EntityProxy = ResourceProxy:new()

---@type {[string]: ResourceProxy}
local proxyRegistry = {}

function EntityProxy:RegisterResourceProxy(resourceType, instance)
	proxyRegistry[resourceType] = instance
end

EntityManager = ResourceProxy:new()

---@param resource EntityHandle|ComponentHandle
function EntityManager:RenderDisplayWindow(resource, parent)
	if type(resource) == "userdata" and Ext.Types.GetObjectType(resource):find("Component") then
		local success, result = pcall(function(...)
			proxyRegistry[Ext.Types.GetObjectType(resource)]:RenderDisplayWindow(resource, parent)
		end)

		if not success then
			Logger:BasicError(result)
		end
	else
		ResourceManager:RenderDisplayWindow(resource, parent)
	end
end

function EntityManager:RenderDisplayableValue(parent, resourceValue, resourceType)
	local success, result = pcall(function(...)
		if proxyRegistry[resourceType] then
			proxyRegistry[resourceType]:RenderDisplayableValue(parent, resourceValue, resourceType)
		elseif ResourceProxy:CanRenderValue(resourceType) then
			ResourceManager:RenderDisplayableValue(parent, resourceValue, resourceType)
		elseif resourceValue then
			if (type(resourceValue) == "string" and resourceValue ~= "" and resourceValue ~= "00000000-0000-0000-0000-000000000000")
				or (type(resourceValue) == "number" and resourceValue > 0)
			then
				parent:AddText(tostring(resourceValue))
			elseif type(resourceValue) == "table" then
				if resourceValue[1] and type(resourceValue[1]) ~= "table" then
					parent:AddText(table.concat(resourceValue, "|"))
				else
					Styler:SimpleRecursiveTwoColumnTable(parent, resourceValue)
				end
			end
		end
	end)

	if not success then
		Logger:BasicError(result)
	end
end

Ext.Require("Client/EntityProcessors/Proxies/Entity.lua")
