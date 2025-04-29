Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Mutations",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		local parentTable = Styler:TwoColumnTable(tabHeader, "mutationsMain")

		local row = parentTable:AddRow()

		local selectionParent = row:AddCell():AddChildWindow("selectionParent")

		selectionParent:AddSeparatorText("Your Mutations"):SetStyle("SeparatorTextAlign", 0.5)
		local userFolderGroup = selectionParent:AddGroup("User Folders")

		---@type ExtuiSelectable
		local createFolderButton = selectionParent:AddSelectable("Create Folder")

		createFolderButton.OnClick = function ()
			createFolderButton.Selected = false
		end

		local rulesParent = row:AddCell()
	end)
