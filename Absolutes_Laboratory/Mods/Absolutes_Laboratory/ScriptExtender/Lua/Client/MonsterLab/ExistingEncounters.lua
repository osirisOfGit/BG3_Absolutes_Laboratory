ExistingEncounters = {}

---@param parent ExtuiTreeParent
---@param currentGameLevel GameLevel
---@param encounter MonsterLabEncounter
---@param editCallback fun()
function ExistingEncounters:renderEncounters(parent, currentGameLevel, encounter, editCallback)
	Helpers:KillChildren(parent)

	---@type ExtuiCombo
	local levelCombo
	Styler:MiddleAlignedColumnLayout(parent, function(ele)
		levelCombo = ele:AddCombo("")
		levelCombo.WidthFitPreview = true

		local opts = {}
		for _, level in ipairs(EntityRecorder.Levels) do
			if currentGameLevel == level then
				levelCombo.SelectedIndex = #opts
			end
			table.insert(opts, level)
		end
		levelCombo.Options = opts
	end)

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
		end)
		-- function(key, value)
		-- 	return value.CombatGroupId ~= ""
		-- end)
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

			---@type ExtuiChildWindow
			local combatGroupCard = row.Children[(counter % maxRowSize) > 0 and (counter % maxRowSize) or maxRowSize]:AddChildWindow(combatGroupId)
			combatGroupCard.NoSavedSettings = true
			combatGroupCard:SetColor("ChildBg", { 1, 1, 1, 0 })
			combatGroupCard.Size = Styler:ScaleFactor({ 300, (TableUtils:CountElements(entityRecords) * 40) + 40 })

			local groupTable = combatGroupCard:AddTable("childTable", 1)
			groupTable:AddColumn("", "WidthStretch")
			groupTable.Borders = true
			groupTable:SetColor("TableBorderStrong", Styler:ConvertRGBAToIMGUI(cardColours[(counter % (#cardColours - (maxRowSize % 2 == 0 and 1 or 0))) + 1]))

			Styler:MiddleAlignedColumnLayout(groupTable:AddRow():AddCell(), function(ele)
				if combatGroupId == "" then
					ele:AddText("No CombatGroupId")
				else
					if level == currentGameLevel then
						local teleportButton = Styler:ImageButton(ele:AddImageButton("Teleport_Group", "Spell_Conjuration_DimensionDoor", { 32, 32 }))
						teleportButton:Tooltip():AddText("\t Teleport to this combat group")
						teleportButton.OnClick = function()
							Channels.TeleportToEntity:SendToServer(next(entityRecords))
						end
					end

					if not encounter.modId then
						local copyEncounterButton = Styler:ImageButton(ele:AddImageButton("Copy Encounter", "ico_copy_d", { 32, 32 }))
						copyEncounterButton.SameLine = level == currentGameLevel
						copyEncounterButton:Tooltip():AddText("\t Copy all the templates from this group into your current encounter, including the names")
						copyEncounterButton.OnClick = function()
							for _, entityRecord in pairs(entityRecords) do
								for _ = 1, dupeTracker[combatGroupId][entityRecord.Name] do
									local entityEntry = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.entity)
									entityEntry.displayName = entityRecord.Name
									entityEntry.template = entityRecord.Template
									entityEntry.coordinates = encounter.baseCoords._real

									encounter.entities[FormBuilder:generateGUID()] = entityEntry
								end
							end
							editCallback()
						end
					end
				end
			end)

			for entityId, entityRecord in TableUtils:OrderedPairs(entityRecords, function(key, value)
				return value.Name
			end) do
				local entityRow = groupTable:AddRow():AddCell()
				local dupeKey = entityRecord.Name

				if combatGroupId == "" and level == currentGameLevel then
					local teleportButton = Styler:ImageButton(entityRow:AddImageButton("Teleport_Group", "Spell_Conjuration_DimensionDoor", { 32, 32 }))
					teleportButton:Tooltip():AddText("\t Teleport to this combat group")
					teleportButton.OnClick = function()
						Channels.TeleportToEntity:SendToServer(entityId)
					end
				end

				if not encounter.modId then
					local copyEntityButton = Styler:ImageButton(entityRow:AddImageButton("Copy Encounter", "ico_copy_d", { 32, 32 }))
					copyEntityButton.SameLine = #entityRow.Children > 1
					copyEntityButton:Tooltip():AddText("\t Copy this template into your current encounter, including the name")
					copyEntityButton.OnClick = function()
						local entityEntry = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.monsterLab.entity)
						entityEntry.displayName = entityRecord.Name
						entityEntry.template = entityRecord.Template
						entityEntry.coordinates = encounter.baseCoords._real

						encounter.entities[FormBuilder:generateGUID()] = entityEntry
						editCallback()
					end
				end

				local image = entityRow:AddImage(entityRecord.Icon, { 32, 32 })
				image.SameLine = #entityRow.Children > 1
				if image.ImageData.Icon == "" then
					image:Destroy()
					entityRow:AddImage("Item_Unknown", { 32, 32 }).SameLine = #entityRow.Children > 1
				end

				local link = Styler:HyperlinkText(entityRow, entityRecord.Name .. "##" .. entityId, function(parent)
					CharacterWindow:BuildWindow(parent, entityId)
				end)

				link:SetColor("TextLink", { 0.86, 0.79, 0.68, 0.78 })
				link.SameLine = true

				if dupeTracker[combatGroupId][dupeKey] > 1 then
					entityRow:AddText(string.format("x%s", dupeTracker[combatGroupId][dupeKey])).SameLine = true
				end
			end
		end
	end

	renderCombatGroupCards(levelCombo.Options[levelCombo.SelectedIndex + 1])

	levelCombo.OnChange = function()
		renderCombatGroupCards(levelCombo.Options[levelCombo.SelectedIndex + 1])
	end
end
