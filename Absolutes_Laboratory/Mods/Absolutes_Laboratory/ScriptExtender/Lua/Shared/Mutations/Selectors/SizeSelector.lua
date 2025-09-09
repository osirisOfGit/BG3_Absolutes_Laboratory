SizeSelector = SelectorInterface:new("Size")

function SizeSelector:handleDependencies()
	-- NOOP
end

---@class SizeSelector : Selector
---@field criteriaValue number[]

---@param existingSelector SizeSelector
function SizeSelector:renderSelector(parent, existingSelector)
	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local tbl = parent:AddTable("size", 3)
	local row = tbl:AddRow()

	for i, size in ipairs(Ext.Enums.StatsSize) do
		size = tostring(size)
		local box = row:AddCell():AddCheckbox(size, TableUtils:IndexOf(existingSelector.criteriaValue, size) ~= nil)
		box.OnChange = function()
			local index = TableUtils:IndexOf(existingSelector.criteriaValue, size)
			if index then
				existingSelector.criteriaValue[index] = nil
				TableUtils:ReindexNumericTable(existingSelector.criteriaValue)
			else
				table.insert(existingSelector.criteriaValue, size)
			end
		end
		if i / 3 == 1 then
			row = tbl:AddRow()
		end
	end
end

---@param selector Selector
---@return fun(entity: (EntityHandle|EntityRecord)): boolean
function SizeSelector:predicate(selector)
	return function(entity)
		if type(entity) == "userdata" then
			---@cast entity EntityHandle
			if entity.ObjectSize then
				return TableUtils:IndexOf(selector.criteriaValue, tostring(Ext.Enums.StatsSize[entity.ObjectSize.Size])) ~= nil
			end
		else
			---@cast entity EntityRecord
			if entity.Size then
				return TableUtils:IndexOf(selector.criteriaValue, tostring(Ext.Enums.StatsSize[entity.Size])) ~= nil
			end
		end

		return false
	end
end
