ExistingEncounters = {}

---@param parent ExtuiTreeParent
function ExistingEncounters:init(parent)
	---@type ExtuiCombo
	local levelCombo
	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		levelCombo = ele:AddCombo("")
		levelCombo.WidthFitPreview = true

		local opts = {}
		for _, level in ipairs(EntityRecorder.Levels) do
			table.insert(opts, level)
		end
		levelCombo.Options = opts

		levelCombo.SelectedIndex = 0
	end)

	local cardsWindow = parent:AddChildWindow("Combat Group Cards")

	local cardColours = {
		{ 0,  51,  51, 0.4 },
		{ 80, 0,   60, 0.4 },
		{ 50, 0,   0,  0.4 },
		{ 0,  100, 50, 0.4 },
	}

	local function renderCombatGroupCards(level)
		if cardsWindow.LastSize[1] == 0.0 then
			Ext.Timer.WaitFor(50, function()
				renderCombatGroupCards(level)
			end)
			return
		end

		Helpers:KillChildren(cardsWindow)

		---@type {[string] : {[Guid]: EntityRecord}}
		local combatGroups = {}

		for entityId, entityRecord in TableUtils:OrderedPairs(EntityRecorder:GetEntities()[level], function(key, value)
				return value.CombatGroupId
			end,
			function(key, value)
				return value.CombatGroupId ~= nil and value.CombatGroupId ~= ""
			end)
		do
			combatGroups[entityRecord.CombatGroupId] = combatGroups[entityRecord.CombatGroupId] or {}
			combatGroups[entityRecord.CombatGroupId][entityId] = entityRecord
		end

		local maxRowSize = math.floor(cardsWindow.LastSize[1] / (Styler:ScaleFactor() * 200))
		local entriesPerColumn = math.floor(TableUtils:CountElements(combatGroups) / maxRowSize)
		entriesPerColumn = entriesPerColumn > 0 and entriesPerColumn or 1

		local layoutTable = cardsWindow:AddTable("cards", maxRowSize)

		local row = layoutTable:AddRow()
		local column = row:AddCell()

		local counter = 0

		for combatGroupId, entityRecords in TableUtils:OrderedPairs(combatGroups) do
			counter = counter + 1

			local combatGroupCard = column:AddChildWindow(combatGroupId)
			combatGroupCard.Border = true
			combatGroupCard.Size = Styler:ScaleFactor({ 200, TableUtils:CountElements(entityRecords) * 40 })
			combatGroupCard:SetColor("ChildBg", Styler:ConvertRGBAToIMGUI(cardColours[(counter % #cardColours) + 1]))

			for entityId, entityRecord in TableUtils:OrderedPairs(entityRecords, function(key, value)
				return value.Name
			end) do
				local image = combatGroupCard:AddImage(entityRecord.Icon, Styler:ScaleFactor({ 32, 32 }))
				if image.ImageData.Icon == "" then
					image:Destroy()
					combatGroupCard:AddImage("Item_Unknown", Styler:ScaleFactor({ 32, 32 }))
				end

				Styler:HyperlinkText(combatGroupCard, entityRecord.Name .. "##" .. entityId, function(parent)
					CharacterWindow:BuildWindow(parent, entityId)
				end).SameLine = true
			end

			if counter % entriesPerColumn == 0 and counter < (entriesPerColumn * maxRowSize - 1) then
				column = row:AddCell()
			end
		end
	end

	renderCombatGroupCards(levelCombo.Options[levelCombo.SelectedIndex + 1])

	levelCombo.OnChange = function()
		renderCombatGroupCards(levelCombo.Options[levelCombo.SelectedIndex + 1])
	end
end
