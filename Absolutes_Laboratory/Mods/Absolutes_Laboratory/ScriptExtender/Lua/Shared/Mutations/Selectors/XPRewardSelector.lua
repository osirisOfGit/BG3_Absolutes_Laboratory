XPRewardSelector = SelectorInterface:new("XPReward")

---@class XPRewardSelector : Selector
---@field criteriaValue Guid[]

---@param parent ExtuiTreeParent
---@param selector XPRewardSelector
function XPRewardSelector:renderSelector(parent, selector)
	selector.criteriaValue = selector.criteriaValue or {}

	local counter = 0
	for _, xpRewardId in TableUtils:OrderedPairs(Ext.StaticData.GetAll("ExperienceReward"), function(key, value)
		return Ext.StaticData.Get(value, "ExperienceReward").Name
	end, function(key, value)
		return Ext.StaticData.Get(value, "ExperienceReward").LevelSource > 0
	end) do
		counter = counter + 1

		---@type ResourceExperienceRewards
		local xpReward = Ext.StaticData.Get(xpRewardId, "ExperienceReward")

		local box = parent:AddCheckbox(xpReward.Name, TableUtils:IndexOf(selector.criteriaValue, xpRewardId) ~= nil)
		box.SameLine = (counter - 1) % 5 ~= 0
		box.OnChange = function()
			if box.Checked then
				table.insert(selector.criteriaValue, xpRewardId)
			else
				selector.criteriaValue[TableUtils:IndexOf(selector.criteriaValue, xpRewardId)] = nil
			end
		end
	end
end

---@param selector XPRewardSelector
---@return fun(entity: EntityHandle|EntityRecord): boolean
function XPRewardSelector:predicate(selector)
	return function(entity)
		if type(entity) == "userdata" then
			return TableUtils:IndexOf(selector.criteriaValue, Ext.Stats.Get(entity.Data.StatsId).XPReward) ~= nil
		else
			return TableUtils:IndexOf(selector.criteriaValue, entity.XPReward) ~= nil
		end
	end
end

---@param selector XPRewardSelector
function XPRewardSelector:handleDependencies(export, selector, removeMissingDependencies)
	local rewardIndex = Ext.StaticData.GetSources("ExperienceReward")

	for i, xpRewardId in pairs(selector.criteriaValue) do
		---@type ResourceExperienceRewards
		local xpReward = Ext.StaticData.Get(xpRewardId, "ExperienceReward")

		if not xpReward then
			selector.criteriaValue[i] = nil
		elseif not removeMissingDependencies then
			local source = TableUtils:IndexOf(rewardIndex, function(value)
				return TableUtils:IndexOf(value, xpRewardId) ~= nil
			end)
			if source then
				selector.modDependencies = selector.modDependencies or {}
				if not selector.modDependencies[xpRewardId] then
					local name, author, version = Helpers:BuildModFields(source)
					if author == "Larian" then
						goto continue
					end
					selector.modDependencies[source] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = source,
						packagedItems = {}
					}
				end

				selector.modDependencies[source].packagedItems[xpRewardId] = xpReward.Name
			end
		end
		::continue::
	end
end

function XPRewardSelector:generateDocs()
end
