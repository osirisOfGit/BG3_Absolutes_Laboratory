---@class SelectorInterface
SelectorInterface = {
	name = "",
	---@type {[string]: SelectorInterface}
	registeredSelectors = {},
	---@type SelectorPredicate
	predicate = nil
}

---@param name string
---@return SelectorInterface instance
function SelectorInterface:new(name)
	local instance = { name = name }

	setmetatable(instance, self)
	self.__index = self

	if Ext.IsClient() then
		MutationManager:registerSelector(name, instance)
	end
	SelectorInterface.registeredSelectors[name] = instance

	return instance
end

---@param parent ExtuiTreeParent
---@param existingSelector Selector?
function SelectorInterface:renderSelector(parent, existingSelector) end

---@class SelectorPredicate
SelectorPredicate = {
}

---@param func fun(entity: EntityRecord|EntityHandle, selector: Selector): boolean
---@return SelectorPredicate instance
function SelectorPredicate:new(func)
	local instance = {}

	setmetatable(instance, self)
	self.__index = self
	self.__call = func

	return instance
end

---@param f SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate:And(f)
	return SelectorPredicate:new(function(entity, selector)
		return self(entity, selector) and f(entity, selector)
	end)
end

---@param f SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate:Or(f)
	return SelectorPredicate:new(function(entity, selector)
		return self(entity, selector) or f(entity, selector)
	end)
end

function SelectorPredicate:Negate()
	return SelectorPredicate:new(function (entity, selector)
		return not self(entity, selector)
	end)
end

---@param selectorQuery SelectorQuery
---@return SelectorPredicate
function SelectorInterface:createComposedPredicate(selectorQuery)
	---@type SelectorPredicate
	local predicate

	---@type SelectorPredicate
	local predicateGroup

	local currentOperation = "AND"
	for _, selector in ipairs(selectorQuery) do
		if type(selector) == "string" then
			if not predicate then
				predicate = predicateGroup
			elseif currentOperation == "AND" then
				predicate = predicate:And(predicateGroup)
			else
				predicate = predicate:Or(predicateGroup)
			end

			predicateGroup = nil
			currentOperation = selector
		else
			---@type SelectorPredicate
			local selectorPred = self.registeredSelectors[selector.criteriaCategory].predicate
			if next(selector.subSelectors) then
				selectorPred:And(self:createComposedPredicate(selector.subSelectors))
			end

			if not selector.inclusive then
				selectorPred = selectorPred:Negate()
			end

			if not predicateGroup then
				predicateGroup = selectorPred
			elseif currentOperation == "AND" then
				predicateGroup = predicateGroup:And(selectorPred)
			else
				predicateGroup = predicateGroup:Or(selectorPred)
			end
		end
	end

	if predicateGroup then
		if currentOperation == "AND" then
			predicate = predicate:And(predicateGroup)
		else
			predicate = predicate:Or(predicateGroup)
		end
	end

	return predicate
end

Ext.Require("Shared/Selectors/RaceSelector.lua")
