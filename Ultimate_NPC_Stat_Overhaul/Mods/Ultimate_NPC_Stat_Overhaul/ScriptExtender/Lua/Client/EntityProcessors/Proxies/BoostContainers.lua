BoostsContainerProxy = EntityProxy:new()
BoostsContainerProxy.fieldsToParse = {
	"Amount",
	"DiceValues",
	"Level",
	"MaxAmount",
	"ReplenishType",
	"ResourceId",
	"ResourceUUID",
	"SubAmounts",
	"field_28",
	"field_A8",
}

EntityProxy:RegisterResourceProxy("BoostsContainer", BoostsContainerProxy)


---@param boostEntries {string: [BoostEntry]}
function BoostsContainerProxy:RenderDisplayableValue(parent, boostEntries)
	if boostEntries then
		local header = parent:AddCollapsingHeader("Boosts")
		header:SetColor("Header", { 1, 1, 1, 0 })

		local displayTable = Styler:TwoColumnTable(header, "boosts")

		for boostType, boostEntry in TableUtils:OrderedPairs(boostEntries) do
			local row = displayTable:AddRow()

			row:AddCell():AddText(boostType)

			local displayCell = row:AddCell()
			EntityManager:RenderDisplayableValue(displayCell, boostEntry)
			if #displayCell.Children == 0 then
				row:Destroy()
			end
		end
		if #displayTable.Children == 0 then
			displayTable:Destroy()
		end

		if #header.Children == 0 then
			header:Destroy()
		end
	end
end
