---@class EntityProxy:ResourceProxy
EntityProxy = ResourceProxy:new()

---@type GUIDSTRING?
EntityProxy.entityId = nil

---@type {[string]: ResourceProxy}
local proxyRegistry = {}

function EntityProxy:RegisterResourceProxy(resourceType, instance)
	proxyRegistry[resourceType] = instance
end

EntityManager = ResourceProxy:new()

---@param resource EntityHandle|ComponentHandle
function EntityManager:RenderDisplayWindow(resource, parent)
	if type(resource) == "userdata" and (Ext.Types.GetObjectType(resource) == "Entity" or Ext.Types.GetObjectType(resource):find("Component")) then
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

---@param resourceValue BaseComponent
function EntityManager:RenderDisplayableValue(parent, resourceValue, resourceType)
	local success, result = xpcall(function(...)
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
				Styler:SimpleRecursiveTwoColumnTable(parent, resourceValue)
			end
		end
	end, debug.traceback)

	if not success then
		Logger:BasicError(result)
	end
end

Ext.Require("Client/EntityProcessors/Proxies/Entity.lua")
Ext.Require("Client/EntityProcessors/Proxies/ActionResources.lua")
Ext.Require("Client/EntityProcessors/Proxies/BoostContainers.lua")
Ext.Require("Client/EntityProcessors/Proxies/PassiveContainer.lua")
Ext.Require("Client/EntityProcessors/Proxies/DisplayStrings.lua")
Ext.Require("Client/EntityProcessors/Proxies/SpellBook.lua")
