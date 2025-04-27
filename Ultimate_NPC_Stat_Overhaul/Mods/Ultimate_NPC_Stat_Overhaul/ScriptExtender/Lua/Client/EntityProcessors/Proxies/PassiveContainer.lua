PassivesContainerProxy = EntityProxy:new()

EntityProxy:RegisterResourceProxy("PassiveContainer", PassivesContainerProxy)


---@param passiveEntries {string: [BoostEntry]}
function PassivesContainerProxy:RenderDisplayableValue(parent, passiveEntries)
	if passiveEntries then
		local header = parent:AddCollapsingHeader("Passives")
		header:SetColor("Header", { 1, 1, 1, 0 })

		local displayTable = Styler:TwoColumnTable(header, "pasives")

		for passiveId, passiveEntry in TableUtils:OrderedPairs(passiveEntries) do
			local row = displayTable:AddRow()

			ResourceManager:RenderDisplayableValue(row:AddCell(), passiveId, "Passives")

			local displayCell = row:AddCell()
			EntityManager:RenderDisplayableValue(displayCell, passiveEntry)
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
