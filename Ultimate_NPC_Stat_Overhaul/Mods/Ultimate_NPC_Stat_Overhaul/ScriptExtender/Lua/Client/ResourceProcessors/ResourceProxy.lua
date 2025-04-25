---@alias Resource StatsObject|CharacterTemplate

---@class ResourceProxy
ResourceProxy = {
	delimeter = ";",
	---@class ResourceFieldsToParse
	fieldsToParse = {},
}

---@type {[string]: ResourceProxy}
local proxyRegistry = {}

---@param instance table?
---@return ResourceProxy instance
function ResourceProxy:new(instance)
	instance = instance or {}

	setmetatable(instance, self)
	self.__index = self
	self.fieldsToParse = {}

	return instance
end

---@param statName string
---@return StatsObject?
function ResourceProxy:GetStat(statName)
	return Ext.Stats.Get(statName)
end

function ResourceProxy:RegisterResourceProxy(resourceType, instance)
	proxyRegistry[resourceType] = instance
end

---@param statString string
---@return fun():string
function ResourceProxy:SplitSpring(statString)
	return string.gmatch(statString, "([^" .. self.delimeter .. "]+)")
end

---@param parent ExtuiTreeParent
---@param resourceValue any
---@param statType string?
function ResourceProxy:RenderDisplayableValue(parent, resourceValue, statType) end

---@param resource Resource
---@param propertiesToRender ResourceFieldsToParse
---@param statDisplayTable ExtuiTable
local function buildDisplayTable(resource, propertiesToRender, statDisplayTable)
	resource = Ext.Types.GetObjectType(resource) == "CharacterTemplate" and Ext.Types.Serialize(resource) or resource

	local function makeDisplayable(value)
		if value then
			if type(value) == "table" then
				return value
			elseif type(value) == "number" then
				return value > 0 and value
			else
				return tostring(value) ~= "" and tostring(value)
			end
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
					ResourceManager:RenderDisplayableValue(rightCell, statValue, value)
					if value == "Icon" then
						rightCell:AddImage(statValue, { 32, 32 }).SameLine = true
					end
				end
			elseif type(value) == "table" then
				for _, fieldName in TableUtils:OrderedPairs(value) do
					local statValue
					if Ext.Types.GetObjectType(resource) == "stats::Object" then
						statValue = resource[fieldName]
					else
						statValue = resource[key][fieldName]
					end

					statValue = makeDisplayable(statValue)

					if statValue then
						leftCell:AddText(fieldName)
						ResourceManager:RenderDisplayableValue(rightCell, statValue, fieldName)
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
function ResourceProxy:RenderDisplayWindow(resource, parent)
	---@param nextResource Resource
	---@param propertiesToCopy ResourceFieldsToParse?
	---@param parentCell ExtuiTreeParent|ExtuiTableCell
	local function buildRecursiveResourceTable(nextResource, propertiesToCopy, parentCell)
		nextResource = Ext.Types.GetObjectType(nextResource) == "CharacterTemplate" and Ext.Types.Serialize(nextResource) or nextResource

		---@type Resource?
		local parentResource
		if Ext.Types.GetObjectType(nextResource) ~= "stats::Object" then
			if nextResource.ParentTemplateId ~= "" then
				parentResource = Ext.Template.GetRootTemplate(nextResource.ParentTemplateId)
			elseif nextResource.TemplateName ~= "" then
				parentResource = Ext.Template.GetRootTemplate(nextResource.TemplateName)
			end
			if parentResource then
				parentResource = Ext.Types.Serialize(parentResource)
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
				local fieldValue
				local parentValue
				if parentKey and not Ext.Types.GetObjectType(resource):find("stats::Object") then
					if type(nextResource[parentKey]) == "userdata" then
						fieldValue = Ext.Types.Serialize(nextResource[parentKey])[fieldName]
						parentValue = Ext.Types.Serialize(parentResource[parentKey])[fieldName]
					else
						fieldValue = nextResource[parentKey][fieldName]
						parentValue = parentResource[parentKey][fieldName]
					end
				else
					fieldValue = nextResource[fieldName]
					parentValue = parentResource[fieldName]
				end

				local isInherited
				if type(fieldValue) == "table" then
					isInherited = TableUtils:CompareLists(fieldValue, parentValue)
				else
					isInherited = tostring(fieldValue) == tostring(parentValue)
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

			if Ext.Types.GetObjectType(parentResource) == "stats::Object" then
				parentCell:AddText(string.format("%s | Original Mod: %s ", nextResource.Name, nextResource.OriginalModId,
					nextResource.ModId ~= nextResource.OriginalModId and ("| Modified By: " .. nextResource.ModId) or "")).Font = "Large"
			else
				parentCell:AddText(string.format("%s | File: %s", nextResource.Name, nextResource.FileName:match("Public/(.+)") or "Unknown"))
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
				buildRecursiveResourceTable(parentResource, inheritedProperties, rightCell)
			end

			if #statDisplayTable.Children == 0 then
				statDisplayTable:Destroy()
			end
		else
			if Ext.Types.GetObjectType(nextResource) == "stats::Object" then
				parentCell:AddText(string.format("%s | Original Mod: %s ", nextResource.Name, nextResource.OriginalModId,
					nextResource.ModId ~= nextResource.OriginalModId and ("| Modified By: " .. nextResource.ModId) or "")).Font = "Large"
			else
				parentCell:AddText(string.format("%s | File: %s", nextResource.Name, nextResource.FileName:gsub("^.*[\\/]Mods[\\/]", "") or "Unknown"))
			end

			local statDisplayTable = parentCell:AddTable("StatDisplay" .. nextResource.Name, 2)
			statDisplayTable:AddColumn("", "WidthFixed")
			statDisplayTable:AddColumn("", "WidthStretch")
			statDisplayTable.Borders = true
			buildDisplayTable(nextResource, propertiesToCopy or self.fieldsToParse, statDisplayTable)
		end
	end

	buildRecursiveResourceTable(resource, nil, parent)
end

ResourceManager = ResourceProxy:new()

function ResourceManager:RenderDisplayWindow(resource, parent)
	local success, result = pcall(function(...)
		proxyRegistry[Ext.Types.GetObjectType(resource) == "CharacterTemplate" and "CharacterTemplate" or resource.ModifierList]:RenderDisplayWindow(resource, parent)
	end)

	if not success then
		Logger:BasicError(result)
	end
end

function ResourceManager:RenderDisplayableValue(parent, resourceValue, resourceType)
	local success, result = pcall(function(...)
		if proxyRegistry[resourceType] then
			proxyRegistry[resourceType]:RenderDisplayableValue(parent, resourceValue)
		elseif resourceValue ~= "" then
			parent:AddText(tostring(resourceValue))
		end
	end)

	if not success then
		Logger:BasicError(result)
	end
end

Ext.Require("Client/ResourceProcessors/Proxies/CharacterTemplate.lua")
Ext.Require("Client/ResourceProcessors/Proxies/CharacterStat.lua")
Ext.Require("Client/ResourceProcessors/Proxies/ItemList.lua")
Ext.Require("Client/ResourceProcessors/Proxies/Status.lua")
Ext.Require("Client/ResourceProcessors/Proxies/Passives.lua")
