Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Configuration",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		local displayTable = tabHeader:AddTable("allConfigs", 2)
		displayTable:AddColumn("", "WidthFixed")
		displayTable:AddColumn("", "WidthStretch")

		local row = displayTable:AddRow()

		local selectionTreeCell = row:AddCell()
		local configurationViewCell = row:AddCell()

		local universalSelection = selectionTreeCell:AddTree("Universal")
	end
)
