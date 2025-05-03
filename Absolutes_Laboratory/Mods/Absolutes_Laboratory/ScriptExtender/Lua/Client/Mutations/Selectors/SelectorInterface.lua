---@class SelectorInterface
Selector = {
	name = ""
}

---@param name string
---@return ResourceProxy instance
function Selector:new(name)
	local instance = { name = name }

	setmetatable(instance, self)
	self.__index = self

	MutationManager:registerSelector(name, instance)

	return instance
end

---@param parent ExtuiTreeParent
---@param existingSelector Selector?
---@param onChangeFunc fun(selector: Selector)
function Selector:createSelector(parent, existingSelector, onChangeFunc) end
