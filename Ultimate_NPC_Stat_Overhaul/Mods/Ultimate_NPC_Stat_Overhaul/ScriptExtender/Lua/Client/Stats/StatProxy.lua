---@class StatProxy
StatProxy = {
	delimeter = ";",
	---@class StatFieldsToParse
	statsToParse = {},
}

---@type {[string]: StatProxy}
local proxyRegistry = {}

---@param instance table?
---@return StatProxy instance
function StatProxy:new(instance)
	instance = instance or {}

	setmetatable(instance, self)
	self.__index = self
	self.statsToParse = {}

	return instance
end

---@param statName string
---@return StatsObject?
function StatProxy:Get(statName)
	return Ext.Stats.Get(statName)
end

function StatProxy:RegisterStatType(statType, instance)
	proxyRegistry[statType] = instance
end

---@param statString string
---@return fun():string
function StatProxy:SplitSpring(statString)
	return string.gmatch(statString, "([^" .. self.delimeter .. "]+)")
end

---@param parent ExtuiTreeParent
---@param statString string
---@param statType string?
function StatProxy:buildHyperlinkedStrings(parent, statString, statType) end

---@param stat StatsObject
---@param propertiesToRender StatFieldsToParse
---@param statDisplayTable ExtuiTable
local function buildDisplayTable(stat, propertiesToRender, statDisplayTable)
	local function makeDisplayable(value)
		if type(value) == "table" then
			return #value > 0 and table.concat(value, "|")
		elseif type(value) == "number" then
			return value > 0 and value
		else
			return (value and tostring(value) ~= "") and tostring(value)
		end
	end
	for key, value in TableUtils:OrderedPairs(propertiesToRender, function(key)
		return type(propertiesToRender[key]) == "string" and propertiesToRender[key] or key
	end) do
		local statDisplayRow = statDisplayTable:AddRow()
		local leftCell = statDisplayRow:AddCell()
		local rightCell = statDisplayRow:AddCell()
		local success, error = pcall(function()
			if type(value) == "string" then
				local statValue = makeDisplayable(
					(value == "DisplayName" or value == "Description")
					and Ext.Loca.GetTranslatedString(stat[value], stat[value])
					or stat[value])

				if statValue and (statValue ~= "No" and statValue ~= "None") then
					leftCell:AddText(value)
					StatManager:buildHyperlinkedStrings(rightCell, statValue, value)
					if value == "Icon" then
						rightCell:AddImage(statValue, {32, 32}).SameLine = true
					end
				end
			elseif type(value) == "table" then
				for _, fieldName in TableUtils:OrderedPairs(value) do
					local statValue = makeDisplayable(stat[fieldName])
					if statValue then
						leftCell:AddText(fieldName)
						StatManager:buildHyperlinkedStrings(rightCell, statValue, fieldName)
					end
				end
			end
		end)
		if not success then
			statDisplayRow:Destroy()
			Logger:BasicError(error)
		elseif #rightCell.Children == 0 then
			statDisplayRow:Destroy()
		end
	end
end


---@param stat StatsObject
---@param parent ExtuiTreeParent
---@param statType string
function StatProxy:RenderDisplayWindow(stat, parent)
	---@param nextStat StatsObject
	---@param propertiesToCopy StatFieldsToParse?
	---@param parentCell ExtuiTreeParent|ExtuiTableCell
	local function buildRecursiveStatTable(nextStat, propertiesToCopy, parentCell)
		---@type StatsObject?
		local parentStat = nextStat.Using ~= "" and Ext.Stats.Get(nextStat.Using) or nil
		if parentStat then
			---@type StatFieldsToParse
			local overriddenProperties = {}
			---@type StatFieldsToParse
			local inheritedProperties = {}

			local function determineStatDiff(fieldName, key, parentKey)
				local isInherited
				if type(nextStat[fieldName]) == "table" then
					isInherited = TableUtils:CompareLists(nextStat[fieldName], parentStat[fieldName])
				else
					isInherited = tostring(nextStat[fieldName]) == tostring(parentStat[fieldName])
				end

				local tableToPopulate = isInherited and inheritedProperties or overriddenProperties

				if parentKey then
					if not tableToPopulate[parentKey] then
						tableToPopulate[parentKey] = {}
					end
					tableToPopulate[parentKey][key] = fieldName
				else
					tableToPopulate[key] = fieldName
				end
			end

			for key, value in TableUtils:OrderedPairs(propertiesToCopy or self.statsToParse) do
				local success, error = pcall(function()
					if type(value) == "string" then
						determineStatDiff(value, key)
					elseif type(value) == "table" then
						for index, fieldName in pairs(value) do
							determineStatDiff(fieldName, index, key)
						end
					end
				end)
				if not success then
					Logger:BasicError(error)
				end
			end

			parentCell:AddText(string.format("%s | Original Mod: %s ", nextStat.Name, nextStat.OriginalModId,
				nextStat.ModId ~= nextStat.OriginalModId and ("| Modified By: " .. nextStat.ModId) or "")).Font = "Large"

			local statDisplayTable = parentCell:AddTable("StatDisplay" .. nextStat.Name, 2)
			statDisplayTable:AddColumn("", "WidthFixed")
			statDisplayTable:AddColumn("", "WidthStretch")

			statDisplayTable.Borders = true
			if next(overriddenProperties) then
				buildDisplayTable(nextStat, overriddenProperties, statDisplayTable)
			end

			if next(inheritedProperties) then
				local statDisplayRow = statDisplayTable:AddRow()
				statDisplayRow:AddCell()

				local rightCell = statDisplayRow:AddCell()
				buildRecursiveStatTable(parentStat, inheritedProperties, rightCell)
			end

			if #statDisplayTable.Children == 0 then
				statDisplayTable:Destroy()
			end
		else
			parentCell:AddText(string.format("%s | Original Mod: %s ", nextStat.Name, nextStat.OriginalModId,
				nextStat.ModId ~= nextStat.OriginalModId and ("| Modified By: " .. nextStat.ModId) or "")).Font = "Large"

			local statDisplayTable = parentCell:AddTable("StatDisplay" .. nextStat.Name, 2)
			statDisplayTable:AddColumn("", "WidthFixed")
			statDisplayTable:AddColumn("", "WidthStretch")
			statDisplayTable.Borders = true
			buildDisplayTable(nextStat, propertiesToCopy or self.statsToParse, statDisplayTable)
		end
	end

	buildRecursiveStatTable(stat, nil, parent)
end

StatManager = StatProxy:new()

function StatManager:RenderDisplayWindow(stat, parent)
	local success, result = pcall(function(...)
		proxyRegistry[stat.ModifierList]:RenderDisplayWindow(stat, parent)
	end)

	if not success then
		Logger:BasicError(result)
	end
end

function StatManager:buildHyperlinkedStrings(parent, statString, statType)
	local success, result = pcall(function(...)
		if proxyRegistry[statType] then
			proxyRegistry[statType]:buildHyperlinkedStrings(parent, statString)
		else
			parent:AddText(statString)
		end
	end)

	if not success then
		Logger:BasicError(result)
	end
end

Ext.Require("Client/Stats/Proxies/Character.lua")
Ext.Require("Client/Stats/Proxies/Status.lua")
Ext.Require("Client/Stats/Proxies/Passives.lua")
