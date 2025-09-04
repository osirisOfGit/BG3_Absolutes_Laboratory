EncounterDesigner = {
	---@type ExtuiWindow
	window = nil
}

---@param encounter MonsterLabEncounter
function EncounterDesigner:buildDesigner(encounter)
	if not self.window then
		self.window = Ext.IMGUI.NewWindow(encounter.name)
		self.window.Closeable = true
	else
		self.window.Label = encounter.name
		self.window.Open = true
		self.window:SetFocus()
		Helpers:KillChildren(self.window)
	end

	if not TableUtils:TablesAreEqual(encounter.baseCoords, { 0, 0, 0 }) then
		Channels.OrbAtPosition:SendToServer({
			context = "BaseCoords",
			coords = encounter.baseCoords._real,
			moonbeam = 5
		} --[[@as OrbRequest]])

		self.window.OnClose = function()
			Channels.OrbAtPosition:SendToServer({
				context = "BaseCoords",
				cleanup = true
			} --[[@as OrbRequest]])
		end
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

		local coordsGroup = ele:AddGroup("coords")
		for i, coord in ipairs({ "X", "Y", "Z" }) do
			coordsGroup:AddText(coord .. ": ").SameLine = i > 1
			local input = coordsGroup:AddInputScalar("", encounter.baseCoords[i])
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
						coordsGroup.Children[i * 2].Value = { coords[i], coords[i], coords[i], coords[i] }
					end
					Channels.OrbAtPosition:SendToServer({
						context = "BaseCoords",
						coords = coords
					} --[[@as OrbRequest]])
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
								coordsGroup.Children[i * 2]:OnChange()
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

	self:RenderCardForEntities(self.window:AddGroup("cards"), encounter.entities)
end

---@param parent ExtuiTreeParent
---@param entities MonsterLabEntity[]
function EncounterDesigner:RenderCardForEntities(parent, entities)
	Helpers:KillChildren(parent)

	-- Only using this to determine the width of the container, as it keeps scaling the vertical dimension infinitely
	local cardsWindow = parent:AddChildWindow("Combat Group Cards")
	cardsWindow.AlwaysAutoResize = true
	cardsWindow.Size = { 0, 1 }

	local cardGroup = parent:AddGroup("cards")

	local cardColours = {
		{ 255, 0,   0,   0.5 },
		{ 0,   255, 0,   0.5 },
		{ 0,   0,   255, 0.5 },
		{ 255, 0,   255, 0.5 },
		{ 255, 255, 0,   0.5 },
		{ 0,   255, 255, 0.5 },
	}

	local function renderGroupCards()
		if cardsWindow.LastSize[1] == 0.0 then
			Ext.Timer.WaitFor(50, function()
				renderGroupCards()
			end)
			return
		end

		Helpers:KillChildren(cardGroup)

		local maxRowSize = math.floor(cardsWindow.LastSize[1] / (Styler:ScaleFactor() * 300))
		local entriesPerColumn = math.floor(TableUtils:CountElements(combatGroups) / maxRowSize)
		entriesPerColumn = entriesPerColumn > 0 and entriesPerColumn or 1
		local layoutTable = cardGroup:AddTable("cards", maxRowSize)

		local row = layoutTable:AddRow()

		for _ = 1, maxRowSize do
			row:AddCell()
		end

		local counter = 0

		for _, mlEntity in TableUtils:OrderedPairs(entities, function(key, value)
			return value.displayName
		end) do
			counter = counter + 1

			---@type CharacterTemplate
			local template = Ext.ClientTemplate.GetTemplate(mlEntity.template)

			---@type ExtuiChildWindow
			local card = row.Children[(counter % maxRowSize) > 0 and (counter % maxRowSize) or maxRowSize]:AddChildWindow(mlEntity.template .. mlEntity.displayName)
			card.Size = Styler:ScaleFactor({ 300, (TableUtils:CountElements(entities) + 1.5) * 40 })

			local groupTable = card:AddTable("chlidTable", 1)
			groupTable.Borders = true
			groupTable:SetColor("TableBorderStrong", Styler:ConvertRGBAToIMGUI(cardColours[(counter % (#cardColours - (maxRowSize % 2 == 0 and 1 or 0))) + 1]))

			local headerCell = groupTable:AddRow():AddCell()
			Styler:MiddleAlignedColumnLayout(headerCell, function(ele)
				local setCoordsButton = Styler:ImageButton(ele:AddImageButton("PickCoords", "Spell_Divination_TrueStrike", Styler:ScaleFactor({ 36, 36 })))
			end)
			local entityRow = groupTable:AddRow():AddCell()

			local image = entityRow:AddImage(template.Icon, Styler:ScaleFactor({ 32, 32 }))
			if image.ImageData.Icon == "" then
				image:Destroy()
				entityRow:AddImage("Item_Unknown", Styler:ScaleFactor({ 32, 32 }))
			end

			local link = Styler:HyperlinkText(entityRow, mlEntity.template, function(parent)
				ResourceManager:RenderDisplayWindow(template, parent)
			end)

			link:SetColor("TextLink", { 0.86, 0.79, 0.68, 0.78 })
			link.SameLine = true
		end
	end

	renderGroupCards()
end
