EncounterDesigner = {
	---@type ExtuiWindow
	window = nil
}

---@param encounter MonsterLabEncounter
function EncounterDesigner:buildDesigner(encounter)
	if not self.window then
		self.window = Ext.IMGUI.NewWindow(encounter.name .. "###encounterDesigner")
		self.window.Closeable = true
	else
		self.window.Open = true
		self.window:SetFocus()
	end

	Styler:MiddleAlignedColumnLayout(self.window, function(ele)
		local levelCombo
		local teleportToLevelButton
		Styler:MiddleAlignedColumnLayout(ele, function(ele)
			ele:AddText("Location:")
			local levels = {}
			for _, level in ipairs(EntityRecorder.Levels) do
				table.insert(levels, level)
			end
			levelCombo = ele:AddCombo("")
			levelCombo.WidthFitPreview = true
			levelCombo.SameLine = true
			levelCombo.Options = levels
			levelCombo.SelectedIndex = TableUtils:IndexOf(levels, encounter.gameLevel) - 1

			teleportToLevelButton = Styler:ImageButton(ele:AddImageButton("Teleport_Level", "Spell_Conjuration_DimensionDoor", Styler:ScaleFactor({ 32, 32 })))
			teleportToLevelButton.Visible = false
			teleportToLevelButton.SameLine = true
		end)

		local coordsTable = ele:AddTable("coords", 3)

		local inputRow = coordsTable:AddRow()

		for i, coord in ipairs({ "X", "Y", "Z" }) do
			local cell = inputRow:AddCell()
			cell:AddText(coord .. ": ")
			local input = cell:AddInputScalar("", encounter.baseCoords[i])
			input.SameLine = true
			input.ItemWidth = 100
			input.OnChange = function()
				encounter.baseCoords[i] = input.Value[1]
			end
		end

		local pickCoordsButton
		local teleportToCoordsButton

		Styler:MiddleAlignedColumnLayout(ele, function(ele)
			pickCoordsButton = Styler:ImageButton(ele:AddImageButton("PickCoords", "Spell_Divination_TrueStrike", Styler:ScaleFactor({ 48, 48 })))
			pickCoordsButton.Visible = false
			pickCoordsButton.OnClick = function()
				Ext.UI.GetCursorControl().CurrentOverlay = "Wand"
				local tickSub = Ext.Events.Tick:Subscribe(function(e)
					local coords = Ext.ClientUI.GetPickingHelper(1).Inner.Position
					for i = 1, 3 do
						inputRow.Children[i].Children[2].Value = { coords[i], coords[i], coords[i], coords[i] }
					end
				end)

				local mouseSub
				mouseSub = Ext.Events.MouseButtonInput:Subscribe(
				---@param e EclLuaMouseButtonEvent
					function(e)
						if e.Pressed and e.Button == 3 then
							Ext.Events.Tick:Unsubscribe(tickSub)
							Ext.Events.MouseButtonInput:Unsubscribe(mouseSub)
							Ext.UI.GetCursorControl().CurrentOverlay = "None"
							for i = 1, 3 do
								inputRow.Children[i].Children[2]:OnChange()
							end
						end
					end)
			end

			teleportToCoordsButton = Styler:ImageButton(ele:AddImageButton("Teleport_Coords", "Spell_Conjuration_DimensionDoor", Styler:ScaleFactor({ 48, 48 })))
			teleportToCoordsButton.OnClick = function()
				Channels.TeleportToCoords:SendToServer({
					x = encounter.baseCoords[1],
					y = encounter.baseCoords[2],
					z = encounter.baseCoords[3],
				})
			end
		end)

		teleportToCoordsButton.Visible = false
		teleportToCoordsButton.SameLine = true
		teleportToLevelButton.OnClick = function()
			Channels.TeleportToLevel:SendToServer(encounter.gameLevel)
			teleportToCoordsButton.Visible = true
			pickCoordsButton.Visible = true
			teleportToLevelButton.Visible = false
		end

		local function checkCurrentLevel()
			Channels.GetCurrentHostLevel:RequestToServer(nil, function(levelName)
				teleportToLevelButton.Visible = levelName ~= encounter.gameLevel
				teleportToCoordsButton.Visible = not teleportToLevelButton.Visible
				pickCoordsButton.Visible = teleportToCoordsButton.Visible
			end)
		end
		checkCurrentLevel()

		levelCombo.OnChange = function()
			encounter.gameLevel = levelCombo.Options[levelCombo.SelectedIndex + 1]
			checkCurrentLevel()
		end
	end)
end
