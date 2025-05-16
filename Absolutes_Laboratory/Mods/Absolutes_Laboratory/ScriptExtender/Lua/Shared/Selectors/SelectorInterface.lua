---@class SelectorInterface
SelectorInterface = {
	name = "",
	---@type {[string]: SelectorInterface}
	registeredSelectors = {},
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
	---@type fun(entity: EntityHandle|EntityRecord): boolean
	func = nil
}

---@param func fun(entity: EntityHandle|EntityRecord): boolean
---@return SelectorPredicate instance
function SelectorPredicate:new(func)
	local instance = {func = func}

	setmetatable(instance, self)
	self.__index = self

	return instance
end

---@param entity EntityHandle|EntityRecord
---@return boolean
function SelectorPredicate:Test(entity)
	return self.func(entity)
end

---@param f1 SelectorPredicate
---@param f2 SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate.And(f1, f2)
	return SelectorPredicate:new(function(entity)
		return f1:Test(entity) and f2:Test(entity)
	end)
end

---@param f1 SelectorPredicate
---@param f2 SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate.Or(f1, f2)
	return SelectorPredicate:new(function(entity)
		return f1:Test(entity) or f2:Test(entity)
	end)
end

---@param f SelectorPredicate
---@return SelectorPredicate
function SelectorPredicate.Negate(f)
	return SelectorPredicate:new(function(entity)
		return not f:Test(entity)
	end)
end

---@param selector Selector
---@return fun(entity: EntityHandle|EntityRecord): boolean
function SelectorInterface:predicate(selector) end

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
			---@type SelectorInterface
			local selectorImpl = self.registeredSelectors[selector.criteriaCategory]
			---@type SelectorPredicate
			local selectorPred = SelectorPredicate:new(selectorImpl:predicate(selector))

			if next(selector.subSelectors) then
				selectorPred = selectorPred:And(self:createComposedPredicate(selector.subSelectors))
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
		if not predicate then
			predicate = predicateGroup
		elseif currentOperation == "AND" then
			predicate = predicate:And(predicateGroup)
		else
			predicate = predicate:Or(predicateGroup)
		end
	end

	return predicate
end

Ext.Require("Shared/Selectors/RaceSelector.lua")
Ext.Require("Shared/Selectors/TagSelector.lua")
