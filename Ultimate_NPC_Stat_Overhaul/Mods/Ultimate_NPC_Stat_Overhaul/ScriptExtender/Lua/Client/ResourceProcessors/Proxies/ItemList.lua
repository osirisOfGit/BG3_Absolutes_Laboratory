ItemListProxy = ResourceProxy:new()

ItemListProxy.fieldsToParse = {
	"Amount",
	"CanBePickpocketed",
	"Conditions",
	"IsDroppedOnDeath",
	"IsTradable",
	"ItemName",
	"LevelName",
	"TemplateID",
	"Type",
	"UUID",
}

ResourceProxy:RegisterResourceProxy("ItemList", ItemListProxy)

---@param itemList InventoryItemData[]
function ItemListProxy:RenderDisplayableValue(parent, itemList)
	if itemList then
		for _, itemData in ipairs(itemList) do
			local displayTable = parent:AddTable("itemList" .. itemData.UUID, 2)
			displayTable.Borders = true
			displayTable:AddColumn("", "WidthFixed")
			displayTable:AddColumn("", "WidthStretch")

			for key, value in TableUtils:OrderedPairs(itemData) do
				local row = displayTable:AddRow()
				if type(value) ~= "table" and (type(value) ~= "string" or value ~= "") and (type(value) ~= "number" or value > 0) then
					row:AddCell():AddText(key)
					if key == "TemplateID" and Ext.Template.GetRootTemplate(value) then
						local templateText = Styler:HyperlinkText(row:AddCell():AddText(value))
						ResourceManager:RenderDisplayWindow(Ext.Template.GetRootTemplate(value), templateText:Tooltip(), "ItemTemplate")
					else
						ResourceManager:RenderDisplayableValue(row:AddCell(), value, key)
					end
				end
				if #row.Children == 0 then
					row:Destroy()
				end
			end
		end
	end
end
