ProgressionContainerProxy = EntityProxy:new()

EntityProxy:RegisterResourceProxy("ProgressionContainer", ProgressionContainerProxy)


---@param progressionEntries {[number]: {[string]: BoostEntry}}
function ProgressionContainerProxy:RenderDisplayableValue(parent, progressionEntries)
	if progressionEntries then
		local header = parent:AddCollapsingHeader("Progr")
		header:SetColor("Header", { 1, 1, 1, 0 })

		local displayTable = Styler:TwoColumnTable(header, "progressions")

		for _, progressionSet in ipairs(progressionEntries) do
			for progressionId, progressionEntry in TableUtils:OrderedPairs(progressionSet) do
				local row = displayTable:AddRow()

				local hyperlinkText = Styler:HyperlinkText(row:AddCell():AddText(CharacterIndex.displayNameMappings[progressionId]))
				ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(progressionId, "Progression"), hyperlinkText:Tooltip())

				local displayCell = row:AddCell()
				EntityManager:RenderDisplayableValue(displayCell, progressionEntry)

				if #displayCell.Children == 0 then
					row:Destroy()
				end
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
