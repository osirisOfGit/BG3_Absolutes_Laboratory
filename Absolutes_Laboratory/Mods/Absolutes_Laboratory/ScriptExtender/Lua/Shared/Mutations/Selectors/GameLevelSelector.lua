GameLevelSelector = SelectorInterface:new("Game Level")

---@class GameLevelSelector : Selector
---@field criteriaValue string[]

function GameLevelSelector:renderSelector(parent, existingSelector)
	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local tbl = parent:AddTable("gameLevel", 3)
	local row = tbl:AddRow()

	for i, level in ipairs(EntityRecorder.Levels) do
		local checkbox = row:AddCell():AddCheckbox(level, TableUtils:IndexOf(existingSelector.criteriaValue, level) ~= nil)
		checkbox.OnChange = function ()
			local index = TableUtils:IndexOf(existingSelector.criteriaValue, level)
			if index then
				existingSelector.criteriaValue[index] = nil
				TableUtils:ReindexNumericTable(existingSelector.criteriaValue)
			else
				table.insert(existingSelector.criteriaValue, level)
			end
		end

		if i / 3 == 1 then
			row = tbl:AddRow()
		end
	end
end

---@param selector GameLevelSelector
---@return fun(entity: EntityHandle|EntityRecord):boolean
function GameLevelSelector:predicate(selector)
	return function (entity)
		if type(entity) == "userdata" then
			---@cast entity EntityHandle
			if entity.Level then
				return TableUtils:IndexOf(selector.criteriaValue, entity.Level.LevelName) ~= nil
			end
		else
			---@cast entity EntityRecord
			return TableUtils:IndexOf(selector.criteriaValue, entity.LevelName) ~= nil
		end
		return false
	end
end
