ExistingEncounters = {}

---@param parent ExtuiTreeParent
function ExistingEncounters:init(parent)
	-- Helpers:KillChildren(parent)

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

	-- Only using this to determine the width of the container, as it keeps scaling the vertical dimension infinitely
	local cardsWindow = parent:AddChildWindow("Combat Group Cards")
	cardsWindow.AlwaysAutoResize = true
	cardsWindow.Size = {0, 1}

	local cardGroup = parent:AddGroup("cards")

	local cardColours = {
		{ 0,  51,  51, 0.4 },
		{ 80, 0,   60, 0.4 },
		{ 50, 0,   0,  0.4 },
		{ 0,  100, 50, 0.4 },
		{ 0,  70,  70, 0.4 },
		{ 60, 0,   70, 0.4 },
		{ 40, 0,   20, 0.4 },
		{ 0,  120, 60, 0.4 },
		{ 20, 0,   40, 0.4 },
		{ 10, 0,   10, 0.4 },
		{ 0,  110, 70, 0.4 },
	}

	local function renderCombatGroupCards(level)
		if cardsWindow.LastSize[1] == 0.0 then
			Ext.Timer.WaitFor(50, function()
				renderCombatGroupCards(level)
			end)
			return
		end

		Helpers:KillChildren(cardGroup)

		---@type {[string] : {[Guid]: EntityRecord}}
		local combatGroups = {}

		---@type {[string] : {[string]: number}}
		local dupeTracker = {}

		for entityId, entityRecord in TableUtils:OrderedPairs(EntityRecorder:GetEntities()[level], function(key, value)
				return value.CombatGroupId
			end,
			function(key, value)
				return value.CombatGroupId ~= nil and value.CombatGroupId ~= ""
			end)
		do
			combatGroups[entityRecord.CombatGroupId] = combatGroups[entityRecord.CombatGroupId] or {}

			if not dupeTracker[entityRecord.CombatGroupId] or not dupeTracker[entityRecord.CombatGroupId][entityRecord.Name] then
				combatGroups[entityRecord.CombatGroupId][entityId] = entityRecord

				dupeTracker[entityRecord.CombatGroupId] = dupeTracker[entityRecord.CombatGroupId] or {}
				dupeTracker[entityRecord.CombatGroupId][entityRecord.Name] = 1
			else
				dupeTracker[entityRecord.CombatGroupId][entityRecord.Name] = dupeTracker[entityRecord.CombatGroupId][entityRecord.Name] + 1
			end
		end

		local maxRowSize = math.floor(cardsWindow.LastSize[1] / (Styler:ScaleFactor() * 300))
		local entriesPerColumn = math.floor(TableUtils:CountElements(combatGroups) / maxRowSize)
		entriesPerColumn = entriesPerColumn > 0 and entriesPerColumn or 1
		local layoutTable = cardGroup:AddTable("cards", maxRowSize)

		local row = layoutTable:AddRow()

		for _ = 1, maxRowSize do
			row:AddCell()
		end

		local counter = 0

		for combatGroupId, entityRecords in TableUtils:OrderedPairs(combatGroups, function(key, value)
			return TableUtils:CountElements(value)
		end) do
			counter = counter + 1

			local combatGroupCard = row.Children[(counter % maxRowSize) > 0 and (counter % maxRowSize) or maxRowSize]:AddChildWindow(combatGroupId)
			combatGroupCard.Border = true
			combatGroupCard.Size = Styler:ScaleFactor({ 300, TableUtils:CountElements(entityRecords) * 40 })

			combatGroupCard:SetColor("ChildBg", Styler:ConvertRGBAToIMGUI(cardColours[(counter % #cardColours) + 1]))

			for entityId, entityRecord in TableUtils:OrderedPairs(entityRecords, function(key, value)
				return value.Name
			end) do
				local dupeKey = entityRecord.Name

				local image = combatGroupCard:AddImage(entityRecord.Icon, Styler:ScaleFactor({ 32, 32 }))
				if image.ImageData.Icon == "" then
					image:Destroy()
					combatGroupCard:AddImage("Item_Unknown", Styler:ScaleFactor({ 32, 32 }))
				end

				local link = Styler:HyperlinkText(combatGroupCard, entityRecord.Name .. "##" .. entityId, function(parent)
					CharacterWindow:BuildWindow(parent, entityId)
				end)

				link:SetColor("TextLink", { 255, 255, 255, .85 })
				link.SameLine = true

				if dupeTracker[combatGroupId][dupeKey] > 1 then
					combatGroupCard:AddText(string.format("x%s", dupeTracker[combatGroupId][dupeKey])).SameLine = true
				end
			end
		end
	end

	renderCombatGroupCards(levelCombo.Options[levelCombo.SelectedIndex + 1])

	levelCombo.OnChange = function()
		renderCombatGroupCards(levelCombo.Options[levelCombo.SelectedIndex + 1])
	end
end
