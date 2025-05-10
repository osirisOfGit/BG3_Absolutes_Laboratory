TreasureTableProxy = ResourceProxy:new()

TreasureTableProxy.fieldsToParse = {
	"CanMerge",
	"IgnoreLevelDiff",
	"MaxLevel",
	"MinLevel",
	"Name",
	"SubTables",
	"UseTreasureGroupContainers",
}

ResourceProxy:RegisterResourceProxy("TradeTreasures", TreasureTableProxy)
ResourceProxy:RegisterResourceProxy("Treasures", TreasureTableProxy)
ResourceProxy:RegisterResourceProxy("TreasureTable", TreasureTableProxy)

---@param treasureTableNames string[]|string
function TreasureTableProxy:RenderDisplayableValue(parent, treasureTableNames, statType)
	local function buildTreasureTable(treasureTableName)
		local treasureTable = Ext.Stats.TreasureTable.GetLegacy(treasureTableName)

		if treasureTable then
			if statType ~= "TreasureTable" then
				local statText = parent:AddCollapsingHeader(treasureTableName)
				statText:SetColor("Header", { 1, 1, 1, 0 })
				TreasureTableProxy:RenderDisplayWindow(treasureTable, statText)
			else
				TreasureTableProxy:RenderDisplayWindow(treasureTable, parent)
			end
		else
			parent:AddText(treasureTableName)
		end
	end
	if type(treasureTableNames) == "table" then
		for _, treasureTableName in ipairs(treasureTableNames) do
			buildTreasureTable(treasureTableName)
		end
	else
		buildTreasureTable(treasureTableNames)
	end
end

---@param resource StatsTreasureTable
function TreasureTableProxy:RenderDisplayWindow(resource, parent)
	local displayTable = Styler:TwoColumnTable(parent)

	for _, fieldName in ipairs(self.fieldsToParse) do
		local row = displayTable:AddRow()

		row:AddCell():AddText(fieldName)

		local fieldValue = resource[fieldName]
		if type(fieldValue) == "table" then
			Styler:SimpleRecursiveTwoColumnTable(row:AddCell(), fieldValue)
		elseif fieldValue ~= "" and (type(fieldValue) ~= "number" or fieldValue > 0) then
			row:AddCell():AddText(tostring(resource[fieldName]))
		end

		if #row.Children == 1 then
			row:Destroy()
		end
	end
end

--#region TreasureCategory
TreasureCategoryProxy = ResourceProxy:new()
TreasureCategoryProxy.fieldsToParse = {
	"Category",
	"Items"
}

ResourceProxy:RegisterResourceProxy("TreasureCategory", TreasureCategoryProxy)

---@param treasureCategoryName string
function TreasureCategoryProxy:RenderDisplayableValue(parent, treasureCategoryName)
	local treasureCategory = Ext.Stats.TreasureCategory.GetLegacy(treasureCategoryName)

	if treasureCategory then
		Styler:HyperlinkText(parent, treasureCategoryName, function(parent)
			self:RenderDisplayWindow(treasureCategory, parent)
		end)
	else
		parent:AddText(treasureCategoryName)
	end
end

--#endregion
