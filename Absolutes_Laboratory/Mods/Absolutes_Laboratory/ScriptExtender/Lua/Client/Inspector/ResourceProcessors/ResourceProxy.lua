---@alias Resource StatsObject|GameObjectTemplate

---@class ResourceProxy
ResourceProxy = {
	delimeter = ";",
	---@class ResourceFieldsToParse
	fieldsToParse = {},
	---@type fun():boolean
	CanRenderValue = nil,
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

function ResourceProxy:CanRenderValue(resourceType)
	return proxyRegistry[resourceType] ~= nil
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
	local serializedResource = (type(resource) == "table" or Ext.Types.GetObjectType(resource) == "stats::Object") and resource or Ext.Types.Serialize(resource)

	local function makeDisplayable(value)
		if value then
			if type(value) == "table" then
				if value["Handle"] then
					return Ext.Loca.GetTranslatedString(value["Handle"]["Handle"], ""):gsub("<[^>]+>", "")
				end

				return next(value) and value or nil
			elseif type(value) == "number" then
				return value > 0 and value
			else
				return tostring(value) ~= "" and tostring(value)
			end
		end
	end
	for key, fieldEntry in TableUtils:OrderedPairs(propertiesToRender, function(key)
		return type(propertiesToRender[key]) == "string" and propertiesToRender[key] or key
	end) do
		local statDisplayRow = statDisplayTable:AddRow()
		local leftCell = statDisplayRow:AddCell()
		local rightCell = statDisplayRow:AddCell()
		local success, error = pcall(function()
			if type(fieldEntry) == "string" then
				local statValue
				if (fieldEntry == "DisplayName" or fieldEntry == "Description" or fieldEntry == "ExtraDescription") and type(serializedResource[fieldEntry]) ~= "table" then
					statValue = Ext.Loca.GetTranslatedString(serializedResource[fieldEntry], serializedResource[fieldEntry]):gsub("<[^>]+>", "")
				else
					statValue = serializedResource[fieldEntry]
				end
				statValue = makeDisplayable(statValue)

				if statValue and (statValue ~= "No" and statValue ~= "None" and statValue ~= "Empty") then
					leftCell:AddText(fieldEntry)

					ResourceManager:RenderDisplayableValue(rightCell, statValue, fieldEntry)
					if fieldEntry == "Icon" then
						rightCell:AddImage(statValue, { 32, 32 }).SameLine = true
					end
				end
			elseif type(fieldEntry) == "table" then
				for _, fieldName in TableUtils:OrderedPairs(fieldEntry) do
					local statValue
					if Ext.Types.GetObjectType(serializedResource) == "stats::Object" then
						statValue = serializedResource[fieldName]
					else
						statValue = serializedResource[key][fieldName]
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
		local serializedResource = (type(nextResource) == "userdata" and not Ext.Types.GetObjectType(nextResource):find("stats::Object"))
			and Ext.Types.Serialize(nextResource)
			or nextResource

		---@type Resource?
		local parentResource
		if Ext.Types.GetObjectType(serializedResource) ~= "stats::Object" then
			if serializedResource.ParentTemplateId ~= "" then
				parentResource = Ext.Template.GetRootTemplate(serializedResource.ParentTemplateId)
			elseif serializedResource.TemplateName ~= "" then
				parentResource = Ext.Template.GetRootTemplate(serializedResource.TemplateName)
			end
			if parentResource then
				parentResource = Ext.Types.Serialize(parentResource)
			end
		else
			parentResource = (serializedResource.Using ~= "" and Ext.Stats.Get(serializedResource.Using) or nil)
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
					if type(serializedResource[parentKey]) == "userdata" then
						fieldValue = Ext.Types.Serialize(serializedResource[parentKey])[fieldName]
						parentValue = Ext.Types.Serialize(parentResource[parentKey])[fieldName]
					else
						fieldValue = serializedResource[parentKey][fieldName]
						parentValue = parentResource[parentKey][fieldName]
					end
				else
					fieldValue = serializedResource[fieldName]
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
				parentCell:AddText(string.format("%s | Original Mod: %s ", serializedResource.Name, Helpers:BuildModString(serializedResource.OriginalModId),
					serializedResource.ModId ~= serializedResource.OriginalModId and ("| Modified By: " .. Helpers:BuildModString(serializedResource.ModId)) or "")).Font = "Large"
			else
				parentCell:AddText(string.format("%s | File: %s", serializedResource.Name, serializedResource.FileName:gsub("^.*[\\/]Mods[\\/]", ""):gsub("^.*[\\/]Public[\\/]", "") or serializedResource.FileName)).Font =
				"Large"
			end

			local statDisplayTable = Styler:TwoColumnTable(parentCell, serializedResource.Name)

			statDisplayTable.Borders = true
			if next(overriddenProperties) then
				buildDisplayTable(serializedResource, overriddenProperties, statDisplayTable)
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
			if Ext.Types.GetObjectType(serializedResource) == "stats::Object" then
				parentCell:AddText(string.format("%s | Original Mod: %s ", serializedResource.Name, Helpers:BuildModString(serializedResource.OriginalModId),
					serializedResource.ModId ~= serializedResource.OriginalModId and ("| Modified By: " .. Helpers:BuildModString(serializedResource.ModId)) or "")).Font = "Large"
			else
				if serializedResource.FileName then
					parentCell:AddText(string.format("%s | File: %s",
						serializedResource.Name,
						serializedResource.FileName:gsub("^.*[\\/]Mods[\\/]", ""):gsub("^.*[\\/]Public[\\/]", "") or serializedResource.FileName)).Font = "Large"
				else
					if serializedResource.Name or serializedResource.Category then
						parentCell:AddText(string.format("%s", serializedResource.Name or serializedResource.Category)).Font = "Large"
					end
				end
			end

			local statDisplayTable = Styler:TwoColumnTable(parentCell, serializedResource.Name or serializedResource.Category)
			buildDisplayTable(serializedResource, propertiesToCopy or self.fieldsToParse, statDisplayTable)
		end
	end

	buildRecursiveResourceTable(resource, nil, parent)
end

ResourceManager = ResourceProxy:new()

function ResourceManager:RenderDisplayWindow(resource, parent)
	if resource then
		local success, result = xpcall(function(...)
			proxyRegistry[Ext.Types.GetObjectType(resource) == "stats::Object" and resource.ModifierList or Ext.Types.GetObjectType(resource)]:RenderDisplayWindow(resource, parent)
		end, debug.traceback)

		if not success then
			Logger:BasicError(result)
		end
	end
end

function ResourceManager:RenderDisplayableValue(parent, resourceValue, resourceType)
	local success, result = xpcall(function(...)
		if proxyRegistry[resourceType] then
			proxyRegistry[resourceType]:RenderDisplayableValue(parent, resourceValue, resourceType)
		elseif resourceValue then
			if (type(resourceValue) == "string" and resourceValue ~= "" and resourceValue ~= "00000000-0000-0000-0000-000000000000")
				or (type(resourceValue) == "number" and resourceValue > 0)
			then
				parent:AddText(tostring(resourceValue))
			elseif type(resourceValue) == "table" then
				Styler:SimpleRecursiveTwoColumnTable(parent, resourceValue, resourceType)
			end
		end
	end, debug.traceback)

	if not success then
		Logger:BasicError("Error managing resourceType %s : %s", resourceType or type(resourceValue), result)
	end
end

--- Template Stuff
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/CharacterTemplate.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/ItemTemplate.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/CharacterStat.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/SkillList.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/Factions.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/Tags.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/Race.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/Progressions.lua")

--- Stat Stuff
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/StatParser.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/ItemList.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/Status.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/ActionResource.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/Passives.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/Spell.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/TreasureTables.lua")
Ext.Require("Client/Inspector/ResourceProcessors/Proxies/XPReward.lua")
