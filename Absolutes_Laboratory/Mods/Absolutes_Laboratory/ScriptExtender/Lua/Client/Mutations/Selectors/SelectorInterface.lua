---@class SelectorInterface
SelectorInterface = {
	name = ""
}

local registeredSelectors = {}

---@param name string
---@return SelectorInterface instance
function SelectorInterface:new(name)
	local instance = { name = name }

	
	setmetatable(instance, self)
	self.__index = self
	
	MutationManager:registerSelector(name, instance)

	return instance
end

---@param parent ExtuiTreeParent
---@param existingSelector Selector?
---@param onChangeFunc fun(selector: Selector)
function SelectorInterface:createSelector(parent, existingSelector, onChangeFunc) end

---@param selector Selector
---@return fun(entity: EntityHandle): boolean
function SelectorInterface:convertToSelectorFunction(selector) end
