---@class SelectorInterface
SelectorInterface = {
	name = "",
	registeredSelectors = {}
}

---@param name string
---@return SelectorInterface instance
function SelectorInterface:new(name)
	local instance = { name = name }

	setmetatable(instance, self)
	self.__index = self

	if Ext.IsClient() then
		MutationManager:registerSelector(name, instance)
	else
		SelectorInterface.registeredSelectors[name] = instance
	end

	return instance
end

---@param parent ExtuiTreeParent
---@param existingSelector Selector?
function SelectorInterface:renderSelector(parent, existingSelector) end

---@param selector Selector
---@return fun(entity: EntityRecord): boolean
function SelectorInterface:convertToSelectorFunction(selector) end

Ext.Require("Shared/Selectors/RaceSelector.lua")
