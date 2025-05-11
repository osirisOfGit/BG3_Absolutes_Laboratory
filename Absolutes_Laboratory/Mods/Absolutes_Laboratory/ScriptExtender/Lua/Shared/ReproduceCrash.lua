ReproduceCrasher = {}

if Ext.IsClient() then
	---@param parent ExtuiTreeParent
	---@param ... fun(ele: ExtuiTableCell)|string
	local function MiddleAlignedColumnLayout(parent, ...)
		local table = parent:AddTable("", 3)
		table.NoSavedSettings = true

		table:AddColumn("", "WidthStretch")
		table:AddColumn("", "WidthFixed")
		table:AddColumn("", "WidthStretch")

		for _, uiElement in pairs({ ... }) do
			local row = table:AddRow()
			row:AddCell()

			if type(uiElement) == "function" then
				uiElement(row:AddCell())
			elseif type(uiElement) == "string" then
				row:AddCell():AddText(uiElement)
			end

			row:AddCell()
		end
	end

	---@param parent ExtuiTreeParent
	---@return ExtuiTable
	local function TwoColumnTable(parent, id)
		local displayTable = parent:AddTable("twoCol" .. parent.IDContext .. (id or ""), 2)
		displayTable.Borders = true
		displayTable.Resizable = true
		displayTable:SetColor("TableBorderStrong", { 0.56, 0.46, 0.26, 0.78 })
		displayTable:AddColumn("", "WidthFixed", 300)
		displayTable:AddColumn("", "WidthStretch")

		return displayTable
	end

	local selectedSelectable

	Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Inspector",
		--- @param tabHeader ExtuiTreeParent
		function(tabHeader)
			local selectionTreeCell = tabHeader:AddChildWindow("selectionTree")
			selectionTreeCell.ChildAlwaysAutoResize = true
			selectionTreeCell.Size = { 400, 0 }

			local configCell = tabHeader:AddChildWindow("configCell")
			configCell.AlwaysHorizontalScrollbar = true
			configCell.SameLine = true
			configCell.NoSavedSettings = true
			configCell.AlwaysAutoResize = true
			configCell.ChildAlwaysAutoResize = true

			local selectTree = selectionTreeCell:AddTree("Selects")

			local populated
			local function populate()
				populated = true
				local tabBar = configCell:AddTabBar("Tabs" ..  tostring(Ext.Math.Random(10)))
				local tab1 = tabBar:AddTabItem("Item 1" .. tostring(Ext.Math.Random(10)))
				tabBar:AddTabItem("Item 2".. tostring(Ext.Math.Random(10)))
				tabBar:AddTabItem("Item 3".. tostring(Ext.Math.Random(10)))

				local mainTable = TwoColumnTable(tab1, tostring(Ext.Math.Random(10)))
				for x = 1, 10 do
					local row = mainTable:AddRow()
					row:AddCell():AddText(tostring(x).. tostring(Ext.Math.Random(10)))

					for y = 1, 10 do
						local parent = row:AddCell()
						if (x % 3) == 0 then
							parent = parent:AddCollapsingHeader("x" .. tostring(x).. tostring(Ext.Math.Random(10)))
						end
						local yTable = TwoColumnTable(parent, tostring(Ext.Math.Random(10)))
						local yrow = yTable:AddRow()
						if (y + x) % 2 == 0 then
							yrow:AddCell():AddText(tostring(y) .. tostring(Ext.Math.Random(10)))
						else
							yrow:AddCell():AddSelectable(tostring(y + x).. tostring(Ext.Math.Random(10)))
						end
						for z = 1, 5 do
							local zTable = TwoColumnTable(yrow:AddCell(), tostring(Ext.Math.Random(10)))
							local zrow = zTable:AddRow()
							zrow:AddCell():AddText(tostring(z))
						end
					end
				end
			end

			for i = 1, 200 do
				---@type ExtuiSelectable
				local selectable = selectTree:AddSelectable("Option" .. i)

				selectable.OnClick = function()
					if selectedSelectable then
						selectedSelectable.Selected = false
					end
					selectedSelectable = selectable
					for _, child in pairs(configCell.Children) do
						child:Destroy()
					end

					MiddleAlignedColumnLayout(configCell, function(ele)
						ele:AddImage("e16a220d-a2bf-a2a8-1bfb-eb723d857eb1-_(Icon_Human_Male)", { 128, 128 })
						if not populated then
							ele:AddButton("Change Act").OnClick = function()
								Channels.TeleportToLevel:SendToServer({
									LevelName = "SCL_Main_A"
								})

								local sub
								sub = Ext.Events.GameStateChanged:Subscribe(function(e)
									---@cast e EsvLuaGameStateChangedEvent
									if e.ToState == "Running" then
										populate()
										Ext.Events.GameStateChanged:Unsubscribe(sub)
									end
								end)
							end
						else
							populate()
						end
					end)
				end
			end
		end)
else
	Channels.TeleportToLevel:SetHandler(function(data, user)
		Osi.TeleportPartiesToLevelWithMovie(data.LevelName, "", "")
	end)
end
