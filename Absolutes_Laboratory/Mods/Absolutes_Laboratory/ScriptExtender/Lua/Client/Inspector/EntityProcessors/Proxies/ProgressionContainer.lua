ProgressionContainerProxy = EntityProxy:new()

EntityProxy:RegisterResourceProxy("ProgressionContainer", ProgressionContainerProxy)

---@param progressionEntries {[number]: {[string]: BoostEntry}}
function ProgressionContainerProxy:RenderDisplayableValue(parent, progressionEntries)
	if progressionEntries then
		local header = parent:AddCollapsingHeader("Progressions")
		header:SetColor("Header", { 1, 1, 1, 0 })

		local displayTable = Styler:TwoColumnTable(header, "progressions")

		for _, progressionSet in ipairs(progressionEntries) do
			for progressionId, progressionEntry in TableUtils:OrderedPairs(progressionSet) do
				local row = displayTable:AddRow()

				---@type ResourceProgression
				local progression = Ext.StaticData.Get(progressionId, "Progression")
				Styler:HyperlinkText(row:AddCell(), progression.Name, function(parent)
					ResourceManager:RenderDisplayWindow(progression, parent)
				end)

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
