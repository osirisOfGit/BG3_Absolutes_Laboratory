---@alias Resource StatsObject|CharacterTemplate

---@class StatProxy
StatProxy = {
	delimeter = ";",
	---@class ResourceFieldsToParse
	fieldsToParse = {},
}

---@type {[string]: StatProxy}
local proxyRegistry = {}

---@param instance table?
---@return StatProxy instance
function StatProxy:new(instance)
	instance = instance or {}

	setmetatable(instance, self)
	self.__index = self
	self.fieldsToParse = {}

	return instance
end

---@param statName string
---@return StatsObject?
function StatProxy:Get(statName)
	return Ext.Stats.Get(statName)
end

function StatProxy:RegisterStatType(resourceType, instance)
	proxyRegistry[resourceType] = instance
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

---@param resource Resource
---@param propertiesToRender ResourceFieldsToParse
---@param statDisplayTable ExtuiTable
local function buildDisplayTable(resource, propertiesToRender, statDisplayTable)
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
					and Ext.Loca.GetTranslatedString(resource[value], resource[value]):gsub("<[^>]+>", "")
					or resource[value])

				if statValue and (statValue ~= "No" and statValue ~= "None") then
					leftCell:AddText(value)
					StatManager:buildHyperlinkedStrings(rightCell, statValue, value)
					if value == "Icon" then
						rightCell:AddImage(statValue, { 32, 32 }).SameLine = true
					end
				end
			elseif type(value) == "table" then
				for _, fieldName in TableUtils:OrderedPairs(value) do
					local statValue = makeDisplayable(resource[fieldName])
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

---@param resource Resource
---@param parent ExtuiTreeParent
---@param statType string
function StatProxy:RenderDisplayWindow(resource, parent)
	---@param nextResource Resource
	---@param propertiesToCopy ResourceFieldsToParse?
	---@param parentCell ExtuiTreeParent|ExtuiTableCell
	local function buildRecursiveStatTable(nextResource, propertiesToCopy, parentCell)
		---@type Resource?
		local parentResource
		if Ext.Types.GetObjectType(nextResource) == "CharacterTemplate" then
			if nextResource.ParentTemplateId ~= "" then
				parentResource = Ext.Template.GetRootTemplate(nextResource.ParentTemplateId)
			elseif nextResource.TemplateName ~= "" then
				parentResource = Ext.Template.GetRootTemplate(nextResource.TemplateName)
			end
		else
			parentResource = (nextResource.Using ~= "" and Ext.Stats.Get(nextResource.Using) or nil)
		end

		if parentResource then
			---@type ResourceFieldsToParse
			local overriddenProperties = {}
			---@type ResourceFieldsToParse
			local inheritedProperties = {}

			local function determineStatDiff(fieldName, key, parentKey)
				local isInherited
				if type(nextResource[fieldName]) == "table" then
					isInherited = TableUtils:CompareLists(nextResource[fieldName], parentResource[fieldName])
				else
					isInherited = tostring(nextResource[fieldName]) == tostring(parentResource[fieldName])
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

			for key, value in TableUtils:OrderedPairs(propertiesToCopy or self.fieldsToParse) do
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

			if Ext.Types.GetObjectType(parentResource) == "CharacterTemplate" then
				parentCell:AddText(string.format("%s | File: %s", nextResource.Name, nextResource.FileName:match("Public/(.+)") or "Unknown"))
			else
				parentCell:AddText(string.format("%s | Original Mod: %s ", nextResource.Name, nextResource.OriginalModId,
					nextResource.ModId ~= nextResource.OriginalModId and ("| Modified By: " .. nextResource.ModId) or "")).Font = "Large"
			end

			local statDisplayTable = parentCell:AddTable("StatDisplay" .. nextResource.Name, 2)
			statDisplayTable:AddColumn("", "WidthFixed")
			statDisplayTable:AddColumn("", "WidthStretch")

			statDisplayTable.Borders = true
			if next(overriddenProperties) then
				buildDisplayTable(nextResource, overriddenProperties, statDisplayTable)
			end

			if next(inheritedProperties) then
				local statDisplayRow = statDisplayTable:AddRow()
				statDisplayRow:AddCell()

				local rightCell = statDisplayRow:AddCell()
				buildRecursiveStatTable(parentResource, inheritedProperties, rightCell)
			end

			if #statDisplayTable.Children == 0 then
				statDisplayTable:Destroy()
			end
		else
			if Ext.Types.GetObjectType(nextResource) == "CharacterTemplate" then
				parentCell:AddText(string.format("%s | File: %s", nextResource.Name, nextResource.FileName:gsub("^.*[\\/]Mods[\\/]", "") or "Unknown"))
			else
				parentCell:AddText(string.format("%s | Original Mod: %s ", nextResource.Name, nextResource.OriginalModId,
					nextResource.ModId ~= nextResource.OriginalModId and ("| Modified By: " .. nextResource.ModId) or "")).Font = "Large"
			end

			local statDisplayTable = parentCell:AddTable("StatDisplay" .. nextResource.Name, 2)
			statDisplayTable:AddColumn("", "WidthFixed")
			statDisplayTable:AddColumn("", "WidthStretch")
			statDisplayTable.Borders = true
			buildDisplayTable(nextResource, propertiesToCopy or self.fieldsToParse, statDisplayTable)
		end
	end

	buildRecursiveStatTable(resource, nil, parent)
end

StatManager = StatProxy:new()

function StatManager:RenderDisplayWindow(resource, parent)
	local success, result = pcall(function(...)
		proxyRegistry[Ext.Types.GetObjectType(resource) == "CharacterTemplate" and "CharacterTemplate" or resource.ModifierList]:RenderDisplayWindow(resource, parent)
	end)

	if not success then
		Logger:BasicError(result)
	end
end

function StatManager:buildHyperlinkedStrings(parent, statString, resourceType)
	local success, result = pcall(function(...)
		if proxyRegistry[resourceType] then
			proxyRegistry[resourceType]:buildHyperlinkedStrings(parent, statString)
		else
			parent:AddText(statString)
		end
	end)

	if not success then
		Logger:BasicError(result)
	end
end

Ext.Require("Client/Stats/Proxies/CharacterTemplate.lua")
Ext.Require("Client/Stats/Proxies/CharacterStat.lua")
Ext.Require("Client/Stats/Proxies/Status.lua")
Ext.Require("Client/Stats/Proxies/Passives.lua")
