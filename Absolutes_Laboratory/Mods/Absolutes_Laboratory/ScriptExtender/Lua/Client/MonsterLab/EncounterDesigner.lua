Ext.Vars.RegisterModVariable(ModuleUUID, "MonsterLab_SpawnedEntities", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

Ext.Vars.RegisterUserVariable("AbsolutesLaboratory_MonsterLab_Entity", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

EncounterDesigner = {
	---@type ExtuiWindow
	designerWindow = nil,
	---@type ExtuiWindow
	designerModeHeader = nil,
	---@type ExtuiPopup
	popup = nil
}

---@param encounter MonsterLabEncounter
function EncounterDesigner:buildDesigner(encounter)
	if not self.designerWindow then
		self.designerWindow = Ext.IMGUI.NewWindow(encounter.name)
		self.designerWindow.Closeable = true

		self.popup = self.designerWindow:AddPopup("encounter")
		self.popup:SetColor("PopupBg", { 0, 0, 0, 1 })
		self.popup:SetColor("Border", { 1, 0, 0, 0.5 })

		self.designerModeHeader = Ext.IMGUI.NewWindow("ACTIVE DESIGNER MODE")
		self.designerModeHeader.Closeable = false
		self.designerModeHeader.NoResize = true
		self.designerModeHeader.NoTitleBar = true
		self.designerModeHeader.NoMove = true
		self.designerModeHeader:SetBgAlpha(0)
		self.designerModeHeader:SetColor("FrameBg", { 1, 1, 1, 0 })

		Styler:MiddleAlignedColumnLayout(self.designerModeHeader, function(ele)
			Styler:CheapTextAlign("DESIGNER MODE ACTIVE", ele, "Big")

			---@type ManageDesignerModeRequest
			local manageDesignerModeRequest = { playersCanDialogue = false, playersCanFight = false }

			Styler:CheapTextAlign("Players:", ele)
			Styler:EnableToggleButton(ele, "Can Enter Combat", false, function(swap)
				if swap then
					manageDesignerModeRequest.playersCanFight = not manageDesignerModeRequest.playersCanFight
					Channels.ManageDesignerMode:SendToServer(manageDesignerModeRequest)
				end
				return manageDesignerModeRequest.playersCanFight
			end)

			ele:AddText(" | ").SameLine = true

			Styler:EnableToggleButton(ele, "Can Enter/Trigger Dialogue", true, function(swap)
				if swap then
					manageDesignerModeRequest.playersCanDialogue = not manageDesignerModeRequest.playersCanDialogue
					Channels.ManageDesignerMode:SendToServer(manageDesignerModeRequest)
				end
				return manageDesignerModeRequest.playersCanDialogue
			end)
		end)
	else
		self.designerModeHeader.Open = true

		self.designerWindow.Label = encounter.name
		self.designerWindow.Open = true
		self.designerWindow:SetFocus()
		Helpers:KillChildren(self.designerWindow)
	end

	MCM.CloseMCMWindow()

	Ext.Timer.WaitFor(50, function()
		self.designerModeHeader:SetPos({ 0, 0 }, "Always")
	end)

	Channels.ManageDesignerMode:SendToServer({
		playersCanDialogue = false,
		playersCanFight = false
	} --[[@as ManageDesignerModeRequest]])


	local currentGameLevel

	Channels.GetCurrentHostLevel:RequestToServer(nil, function(levelName)
		currentGameLevel = levelName
		if levelName == encounter.gameLevel then
			Channels.ManageEncounterSpawns:SendToServer({
				encounterId = encounter._parent_key,
				encounter = (encounter._real or encounter)
			} --[[@as ManageEncounterRequest]])
		end
	end)


	if not TableUtils:TablesAreEqual(encounter.baseCoords, { 0, 0, 0 }) then
		Channels.OrbAtPosition:SendToServer({
			encounterId = encounter._parent_key,
			context = "BaseCoords",
			coords = encounter.baseCoords._real,
			moonbeam = 5
		} --[[@as VisualizationRequest]])
	end

	self.designerWindow.OnClose = function()
		Channels.OrbAtPosition:SendToServer({
			encounterId = encounter._parent_key,
			cleanupEncounter = true
		} --[[@as VisualizationRequest]])

		self.designerModeHeader.Open = false
		Channels.ManageDesignerMode:SendToServer({
			playersCanDialogue = true,
			playersCanFight = true
		} --[[@as ManageDesignerModeRequest]])

		Channels.ManageEncounterSpawns:SendToServer({
			encounterId = encounter._parent_key,
			delete = true
		} --[[@as ManageEncounterRequest]])

		MCM.OpenMCMWindow()
	end

	local entityCardsGroup

	Styler:MiddleAlignedColumnLayout(self.designerWindow, function(ele)
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
			pickCoordsButton = Styler:ImageButton(ele:AddImageButton("PickBaseCoords", "Spell_Divination_TrueStrike", Styler:ScaleFactor({ 48, 48 })))
			pickCoordsButton:Tooltip():AddText(
				"\t Pick a location in the game world to set as the base coordinates for this encounter - has no impact on functionality,\nbut is used for the teleport button to the right and is useful for planning out your encounter")
			pickCoordsButton.UserData = false
			pickCoordsButton.OnClick = function()
				if not pickCoordsButton.UserData then
					pickCoordsButton.UserData = true
					local tickSub = Ext.Events.Tick:Subscribe(function(e)
						local coords = Ext.ClientUI.GetPickingHelper(1).Inner.Position
						for i = 1, 3 do
							coordsGroup.Children[i * 2].Value = { coords[i], coords[i], coords[i], coords[i] }
						end

						Channels.OrbAtPosition:SendToServer({
							encounterId = encounter._parent_key,
							coords = coords,
							context = "BaseCoords"
						} --[[@as VisualizationRequest]])
					end)

					local mouseSub
					mouseSub = Ext.Events.MouseButtonInput:Subscribe(
					---@param e EclLuaMouseButtonEvent
						function(e)
							if e.Pressed then
								if e.Button == 3 then
									Ext.Events.Tick:Unsubscribe(tickSub)
									Ext.Events.MouseButtonInput:Unsubscribe(mouseSub)
									for i = 1, 3 do
										coordsGroup.Children[i * 2]:OnChange()
									end
									pickCoordsButton.UserData = false
								else
									for i = 1, 3 do
										coordsGroup.Children[i * 2]:OnChange()
									end
								end
							end
						end)
				end
			end
			pickCoordsButton.Visible = false

			teleportToCoordsButton = Styler:ImageButton(ele:AddImageButton("Teleport_Coords", "Spell_Conjuration_DimensionDoor", Styler:ScaleFactor({ 48, 48 })))
			teleportToCoordsButton:Tooltip():AddText("\t Teleport to the Encounter's Base Coordinates")
			teleportToCoordsButton.OnClick = function()
				Channels.TeleportToCoords:SendToServer({
					x = encounter.baseCoords[1],
					y = encounter.baseCoords[2],
					z = encounter.baseCoords[3],
				})
			end

			local openExtraSettingsButton = Styler:ImageButton(ele:AddImageButton("Extra_Settings", "ico_combatlog_h", Styler:ScaleFactor({ 48, 48 })))
			openExtraSettingsButton:Tooltip():AddText("\t Show extra encounter-level settings")
			openExtraSettingsButton.SameLine = true

			local extraSettingsGroup = self.designerWindow:AddGroup("ExtraSettings")
			extraSettingsGroup.Visible = false

			self:manageExtraSettings(extraSettingsGroup, encounter)
			openExtraSettingsButton.OnClick = function()
				extraSettingsGroup.Visible = not extraSettingsGroup.Visible
			end

			local refreshEntitiesButton = Styler:ImageButton(ele:AddImageButton("RefreshView", "ico_reset_d", Styler:ScaleFactor({ 48, 48 })))
			refreshEntitiesButton.SameLine = true
			refreshEntitiesButton:Tooltip():AddText("\t Refresh the Entity Card View to match the current window dimensions")
			refreshEntitiesButton.OnClick = function()
				self:RenderCardForEntities(entityCardsGroup, encounter.entities, currentGameLevel == encounter.gameLevel)
			end
		end)

		teleportToCoordsButton.Visible = false
		teleportToCoordsButton.SameLine = true
		teleportToLevelButton.OnClick = function()
			Channels.TeleportToLevel:SendToServer({
				LevelName = encounter.gameLevel
			})
			currentGameLevel = encounter.gameLevel
			teleportToCoordsButton.Visible = true
			pickCoordsButton.Visible = true
			teleportToLevelButton.Visible = false
			self:RenderCardForEntities(entityCardsGroup, encounter.entities, currentGameLevel == encounter.gameLevel)
		end

		local function checkCurrentLevel()
			Channels.GetCurrentHostLevel:RequestToServer(nil, function(levelName)
				currentGameLevel = levelName
				teleportToLevelButton.Visible = levelName ~= encounter.gameLevel
				teleportToCoordsButton.Visible = not teleportToLevelButton.Visible
				pickCoordsButton.Visible = teleportToCoordsButton.Visible

				self:RenderCardForEntities(entityCardsGroup, encounter.entities, currentGameLevel == encounter.gameLevel)
			end)
		end
		checkCurrentLevel()

		levelCombo.OnChange = function()
			encounter.gameLevel = levelCombo.Options[levelCombo.SelectedIndex + 1]
			checkCurrentLevel()
		end
	end)

	entityCardsGroup = self.designerWindow:AddGroup("cards")
end

---@param parent ExtuiTreeParent
---@param entities {[Guid]: MonsterLabEntity}
---@param renderCoordPickers boolean
function EncounterDesigner:RenderCardForEntities(parent, entities, renderCoordPickers)
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

		local maxRowSize = math.floor(cardsWindow.LastSize[1] / (Styler:ScaleFactor() * 400))
		local entriesPerColumn = math.floor(TableUtils:CountElements(entities) / maxRowSize)
		entriesPerColumn = entriesPerColumn > 0 and entriesPerColumn or 1
		local layoutTable = cardGroup:AddTable("cards", math.min(TableUtils:CountElements(entities), maxRowSize))

		local row = layoutTable:AddRow()

		for _ = 1, maxRowSize do
			row:AddCell()
		end

		local counter = 0

		for mlEntityId, mlEntity in TableUtils:OrderedPairs(entities, function(key, value)
			return value.displayName
		end) do
			counter = counter + 1

			---@type CharacterTemplate
			local template = Ext.ClientTemplate.GetTemplate(mlEntity.template)

			---@type ExtuiGroup
			local card = row.Children[(counter % maxRowSize) > 0 and (counter % maxRowSize) or maxRowSize]:AddGroup(mlEntityId)

			local groupTable = card:AddTable("chlidTable", 1)
			groupTable.Borders = true
			groupTable:SetColor("TableBorderStrong", Styler:ConvertRGBAToIMGUI(cardColours[(counter % (#cardColours - (maxRowSize % 2 == 0 and 1 or 0))) + 1]))

			local entityRow = groupTable:AddRow():AddCell()

			Styler:MiddleAlignedColumnLayout(entityRow, function(ele)
				Styler:MiddleAlignedColumnLayout(ele, function(ele)
					local image = ele:AddImage(template.Icon, Styler:ScaleFactor({ 48, 48 }))
					if image.ImageData.Icon == "" then
						image:Destroy()
						ele:AddImage("Item_Unknown", Styler:ScaleFactor({ 48, 48 }))
					end
					ele:AddDummy(32, 32).SameLine = true
				end)

				local nameLink = Styler:HyperlinkText(ele, mlEntity.displayName, function(parent)
					ResourceManager:RenderDisplayWindow(template, parent)
				end)
				nameLink:SetColor("TextLink", { 0.86, 0.79, 0.68, 0.78 })

				local editEntityButton = Styler:ImageButton(ele:AddImageButton("editEntity", "ico_edit_d", Styler:ScaleFactor({ 24, 24 })))
				editEntityButton.SameLine = true
				editEntityButton.OnClick = function()
					Helpers:KillChildren(self.popup)
					self.popup:Open()

					self.popup:AddSelectable("Edit", "DontClosePopups").OnClick = function()
						MonsterLab:buildCreateEntityForm(self.popup, entities._parent_proxy, function()
							Channels.ManageEncounterSpawns:SendToServer({
								encounterId = entities._parent_proxy._parent_key,
								encounter = entities._parent_proxy._real
							} --[[@as ManageEncounterRequest]])

							self.popup:SetCollapsed(true)
							self:RenderCardForEntities(parent, entities, renderCoordPickers)
						end, mlEntity)
					end

					self.popup:AddSelectable("Copy").OnClick = function()
						entities[FormBuilder:generateGUID()] = TableUtils:DeeplyCopyTable(mlEntity._real)
						Channels.ManageEncounterSpawns:SendToServer({
							encounterId = entities._parent_proxy._parent_key,
							encounter = entities._parent_proxy._real
						} --[[@as ManageEncounterRequest]])

						self:RenderCardForEntities(parent, entities, renderCoordPickers)
					end

					---@param selectable ExtuiSelectable
					self.popup:AddSelectable("Delete", "DontClosePopups").OnClick = function(selectable)
						if selectable.Label ~= "Delete" then
							entities[mlEntityId].delete = true

							-- Clean up, then respawn
							Channels.ManageEncounterSpawns:SendToServer({
								encounterId = entities._parent_proxy._parent_key,
								delete = true
							} --[[@as ManageEncounterRequest]])

							Channels.ManageEncounterSpawns:SendToServer({
								encounterId = entities._parent_proxy._parent_key,
								encounter = entities._parent_proxy._real
							} --[[@as ManageEncounterRequest]])

							self.popup:SetCollapsed(true)
							self:RenderCardForEntities(parent, entities, renderCoordPickers)
						else
							selectable.Label = "Are You Sure?"
							Styler:Color(selectable, "ErrorText")
						end
					end
				end
			end)


			local pickerPlaceholder = entityRow:AddGroup("pickerButton")
			pickerPlaceholder.Visible = renderCoordPickers

			local coordsGroup = entityRow:AddGroup("coords")
			coordsGroup.SameLine = renderCoordPickers

			---@diagnostic disable-next-line: missing-fields
			local pickCoordsButton = Styler:ImageButton(pickerPlaceholder:AddImageButton("PickCoords", "Spell_Divination_TrueStrike", Styler:ScaleFactor({ 26, 26 })))

			pickCoordsButton.OnClick = function()
				if not pickCoordsButton.UserData then
					pickCoordsButton.UserData = true
					local tickSub = Ext.Events.Tick:Subscribe(function(e)
						local coords = Ext.ClientUI.GetPickingHelper(1).Inner.Position
						for i = 1, 3 do
							coordsGroup.Children[i * 2].Value = { coords[i], coords[i], coords[i], coords[i] }
						end

						local entityCopy = TableUtils:DeeplyCopyTable((mlEntity._real or mlEntity))
						entityCopy.coordinates = coords

						Channels.ManageEncounterSpawns:SendToServer({
							encounterId = entities._parent_proxy._parent_key,
							encounter = {
								entities = {
									[mlEntityId] = entityCopy
								}
							}
						} --[[@as ManageEncounterRequest]])
					end)

					local mouseSub
					mouseSub = Ext.Events.MouseButtonInput:Subscribe(
					---@param e EclLuaMouseButtonEvent
						function(e)
							if e.Pressed then
								if e.Button == 3 then
									Ext.Events.Tick:Unsubscribe(tickSub)
									Ext.Events.MouseButtonInput:Unsubscribe(mouseSub)
									for i = 1, 3 do
										coordsGroup.Children[i * 2]:OnChange()
									end
									pickCoordsButton.UserData = false
								else
									for i = 1, 3 do
										coordsGroup.Children[i * 2]:OnChange()
									end
								end
							end
						end)
				end
			end

			for i, coord in ipairs({ "X", "Y", "Z" }) do
				coordsGroup:AddText(coord .. ": ").SameLine = i > 1
				local input = coordsGroup:AddInputScalar("", mlEntity.coordinates[i])
				input.SameLine = true
				input.ItemWidth = Styler:ScaleFactor() * 85
				input.OnChange = function()
					mlEntity.coordinates[i] = input.Value[1]
				end
			end

			--#region Rotation
			entityRow:AddText("Rotation: ")
			local rotationGroup = entityRow:AddGroup("Rotatations")
			rotationGroup.SameLine = true

			local rotateButton = rotationGroup:AddButton("+.25")
			local rotationValue = rotationGroup:AddInputScalar("", mlEntity.rotation)
			rotationValue.ItemWidth = 85 * Styler:ScaleFactor()
			rotateButton.OnClick = function()
				local newVal = rotationValue.Value[1] + .25
				rotationValue.Value = { newVal, newVal, newVal, newVal }
				rotationValue:OnChange()
			end
			rotationValue.SameLine = true
			rotationValue.OnChange = function()
				mlEntity.rotation = rotationValue.Value[1]

				Channels.ManageEncounterSpawns:SendToServer({
					encounterId = entities._parent_proxy._parent_key,
					encounter = {
						entities = {
							[mlEntityId] = mlEntity._real
						}
					}
				} --[[@as ManageEncounterRequest]])
			end
			--#endregion

			--#region Animation
			local animationHeader = entityRow:AddCollapsingHeader("Animation")
			animationHeader:SetColor("Header", { 0, 0, 0, 0 })
			animationHeader.DefaultOpen = false

			local refreshAnimFunc

			Styler:MiddleAlignedColumnLayout(animationHeader, function(ele)
				Styler:DualToggleButton(ele, "Basic", "Looping", false, function(swap)
					if swap then
						mlEntity.animation.simple = not mlEntity.animation.simple and "" or nil
						refreshAnimFunc()
					end
					return mlEntity.animation.simple ~= nil
				end)
			end)

			local animationGroup = animationHeader:AddGroup("Animations")
			refreshAnimFunc = function()
				Helpers:KillChildren(animationGroup)
				local animationConfig = mlEntity.animation
				if animationConfig.simple then
					---@type ResourceAnimationResource?
					local existingAnimation = Ext.Resource.Get(animationConfig.simple, "Animation")
					local animationInput = animationGroup:AddInputText("", existingAnimation and existingAnimation.SourceFile:match("([^/\\]+)$") or "")
					animationInput.Hint = "Enter UUID"
					animationInput.OnChange = function()
						---@type ResourceAnimationResource
						local animation = Ext.Resource.Get(animationInput.Text, "Animation")
						if animation then
							animationConfig.simple = animation.Guid
							animationInput.Text = animation.SourceFile:match("([^/\\]+)$")
							animationInput:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })
							Channels.ManageEncounterSpawns:SendToServer({
								encounterId = entities._parent_proxy._parent_key,
								encounter = {
									entities = {
										[mlEntityId] = mlEntity._real
									}
								}
							} --[[@as ManageEncounterRequest]])
						else
							animationInput:SetColor("Text", { 1, 0, 0, 0.75 })
						end
					end
				else
					for animationKey, animationId in TableUtils:OrderedPairs(animationConfig.looping) do
						animationGroup:AddText(animationKey)

						---@type ResourceAnimationResource?
						local existingAnimation = Ext.Resource.Get(animationId, "Animation")
						local animationInput = animationGroup:AddInputText("", existingAnimation and existingAnimation.SourceFile:match("([^/\\]+)$") or "")
						animationInput.ItemWidth = 500
						animationInput.Hint = "Enter UUID"
						animationInput.OnChange = function()
							---@type ResourceAnimationResource
							local animation = Ext.Resource.Get(animationInput.Text, "Animation")
							if animation then
								animationConfig.looping[animationKey] = animation.Guid
								animationInput.Text = animation.SourceFile:match("([^/\\]+)$")
								animationInput:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })

								Channels.ManageEncounterSpawns:SendToServer({
									encounterId = entities._parent_proxy._parent_key,
									encounter = {
										entities = {
											[mlEntityId] = mlEntity._real
										}
									}
								} --[[@as ManageEncounterRequest]])
							else
								animationInput:SetColor("Text", { 1, 0, 0, 0.75 })
							end
						end
					end
				end
			end
			refreshAnimFunc()
			--#endregion
		end

		--#region Adding New Entity
		---@type ExtuiGroup
		local card = cardGroup:AddGroup("Add New Entity")

		local groupTable = card:AddTable("chlidTable", 1)
		groupTable.Borders = true
		groupTable:SetColor("TableBorderStrong", Styler:ConvertRGBAToIMGUI(cardColours[((counter + 1) % (#cardColours - (maxRowSize % 2 == 0 and 1 or 0))) + 1]))

		local addNewEntityRow = groupTable:AddRow():AddCell()

		---@type ExtuiGroup
		local formGroup
		Styler:MiddleAlignedColumnLayout(addNewEntityRow, function(ele)
			Styler:CheapTextAlign("Add New Entity", ele, "Big")
			ele:AddButton("Launch Form").OnClick = function(button)
				if #formGroup.Children == 0 then
					button.Label = "Close Form"
					MonsterLab:buildCreateEntityForm(formGroup, entities._parent_proxy, function()
						Channels.ManageEncounterSpawns:SendToServer({
							encounterId = entities._parent_proxy._parent_key,
							encounter = entities._parent_proxy._real
						} --[[@as ManageEncounterRequest]])
						self:RenderCardForEntities(parent, entities, renderCoordPickers)
					end)
				else
					button.Label = "Launch Form"
					Helpers:KillChildren(formGroup)
				end
			end
		end)
		formGroup = addNewEntityRow:AddGroup("New Entity")
		--#endregion
	end

	renderGroupCards()
end

---@param parent ExtuiTreeParent
---@param encounter MonsterLabEncounter
function EncounterDesigner:manageExtraSettings(parent, encounter)
	Helpers:KillChildren(parent)

	parent:AddText("Copy Values By Selecting Entity: ")
	local pickEntityButton = Styler:ImageButton(parent:AddImageButton("PickEntityButton", "Spell_Divination_TrueStrike", Styler:ScaleFactor({ 36, 36 })))
	pickEntityButton.SameLine = true
	pickEntityButton.UserData = false

	parent:AddText("CombatGroupId: ")
	local combatGroupId = parent:AddInputText("", encounter.combatGroupId)
	combatGroupId.OnChange = function()
		if #combatGroupId.Text == 36 then
			combatGroupId:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })
			encounter.combatGroupId = combatGroupId.Text
			Channels.ManageEncounterSpawns:SendToServer({
				encounterId = encounter._parent_key,
				encounter = encounter._real
			} --[[@as ManageEncounterRequest]])
		else
			Styler:Color(combatGroupId, "ErrorText")
		end
	end

	parent:AddText("Faction: ")
	local factionDisplayName
	factionDisplayName = Styler:HyperlinkText(parent, "", function(parent)
		if factionDisplayName.UserData then
			ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(factionDisplayName.UserData, "Faction"), parent)
		end
	end)
	factionDisplayName.SameLine = true

	local factionInput = parent:AddInputText("", encounter.faction)

	local function setFactionDisplayName()
		factionDisplayName.UserData = nil

		if #factionInput.Text == 36 then
			pcall(function(...)
				---@type ResourceFaction?
				local faction = Ext.StaticData.Get(factionInput.Text, "Faction")
				if faction then
					factionDisplayName.Label = faction.Faction
					factionDisplayName.UserData = faction.ResourceUUID
				else
					factionDisplayName.Label = ""
				end
			end)
		else
			factionDisplayName.Label = ""
		end
	end
	setFactionDisplayName()
	factionInput.OnChange = function()
		setFactionDisplayName()
		if #factionDisplayName.Label > 0 then
			factionInput:SetColor("Text", { 0.86, 0.79, 0.68, 0.78 })
			encounter.faction = factionInput.Text
			Channels.ManageEncounterSpawns:SendToServer({
				encounterId = encounter._parent_key,
				encounter = encounter._real
			} --[[@as ManageEncounterRequest]])
		else
			Styler:Color(factionInput, "ErrorText")
		end
	end

	pickEntityButton.OnClick = function()
		if not pickEntityButton.UserData then
			combatGroupId.Disabled = true
			factionInput.Disabled = true

			pickEntityButton.UserData = true
			local tickSub = Ext.Events.Tick:Subscribe(function(e)
				local entity = Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject
				if entity and entity.ClientCharacter and not entity.Vars.AbsolutesLaboratory_MonsterLab_Entity then
					if entity.CombatParticipant and entity.CombatParticipant.CombatGroupId then
						combatGroupId.Text = entity.CombatParticipant.CombatGroupId
					end

					if entity.Faction and entity.Faction.field_8 then
						factionInput.Text = entity.Faction.field_8
						setFactionDisplayName()
					end
				else
					combatGroupId.Text = encounter.combatGroupId
					factionInput.Text = encounter.faction
					setFactionDisplayName()
				end
			end)

			local mouseSub
			mouseSub = Ext.Events.MouseButtonInput:Subscribe(
			---@param e EclLuaMouseButtonEvent
				function(e)
					if e.Pressed then
						if e.Button == 3 then
							Ext.Events.Tick:Unsubscribe(tickSub)
							Ext.Events.MouseButtonInput:Unsubscribe(mouseSub)
							combatGroupId.Disabled = false
							combatGroupId:OnChange()
							factionInput.Disabled = false
							factionInput:OnChange()

							pickEntityButton.UserData = false
						else
						end
					end
				end)
		end
	end
end
