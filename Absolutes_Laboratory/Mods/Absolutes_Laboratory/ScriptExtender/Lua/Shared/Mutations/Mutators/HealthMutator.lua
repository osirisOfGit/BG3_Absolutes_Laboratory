HealthMutator = MutatorInterface:new("Health")


---@alias HealthModifierKeys "CharacterLevel"|"GameLevel"|"XPReward"

---@class HealthMutator : Mutator
---@field values number
---@field modifiers {[HealthModifierKeys]: HealthClassLevelModifier}

---@class HealthClassLevelModifier : MutationModifier
---@field value number
---@field extraData {[number] : number}

---@param mutator HealthMutator
function HealthMutator:renderMutator(parent, mutator)
	if not mutator.values then
		mutator.values = 10
	end

	parent:AddText("Base Health Increases by ")
	local input = parent:AddInputScalar("%", mutator.values)
	input.ItemWidth = 100
	input.SameLine = true

	input.OnChange = function()
		mutator.values = input.Value[1]
	end

	local previewButton = parent:AddButton("Preview Matrix")
	previewButton.OnClick = function()
		self:previewResult(mutator)
	end

	local modifierParent = parent:AddCollapsingHeader("Modifiers")
	modifierParent:SetColor("Header", { 1, 1, 1, 0 })
	self:renderModifiers(modifierParent, mutator.modifiers)
end

function HealthMutator:renderModifiers(parent, modifiers)
	Helpers:KillChildren(parent)

	--#region Character Level
	---@type HealthClassLevelModifier
	local characterLevelModifier = modifiers["CharacterLevel"] or {
		value = 0,
		extraData = {}
	} --[[@as HealthClassLevelModifier]]

	modifiers["CharacterLevel"] = characterLevelModifier

	characterLevelModifier.extraData = characterLevelModifier.extraData or {}

	local cLevelInfoText = parent:AddSeparatorText("Character Level Modifiers ( ? )")
	cLevelInfoText:SetStyle("SeparatorTextAlign", 0, 0.3)
	cLevelInfoText:SetStyle("Alpha", 1)
	cLevelInfoText:Tooltip():AddText(
		"\t Set the levels at which the modifier changes - for example, setting the modifier to 10% at level 5\nwhen the base modifier is 5% means the modifier will be 5% levels 1-4 and 10% levels 5+")

	parent:AddText("Each character level adds")
	local baseCLevelMod = parent:AddInputScalar("% to the % Base Health Mutator##characterLevel", characterLevelModifier.value)
	baseCLevelMod.ItemWidth = 100
	baseCLevelMod.SameLine = true
	baseCLevelMod.OnChange = function()
		characterLevelModifier.value = baseCLevelMod.Value[1]
	end

	local cLevelTable = parent:AddTable("characterModifierCustomizer", 2)
	local headers = cLevelTable:AddRow()
	headers.Headers = true
	headers:AddCell():AddText("Level")
	headers:AddCell():AddText("% Modifier")

	for level, modifier in TableUtils:OrderedPairs(characterLevelModifier.extraData) do
		local row = cLevelTable:AddRow()
		local levelCell = row:AddCell()
		Styler:ImageButton(levelCell:AddImageButton("delete" .. level, "ico_red_x", { 16, 16 })).OnClick = function()
			characterLevelModifier.extraData[level] = nil
			self:renderModifiers(parent, modifiers)
		end

		local levelInput = levelCell:AddInputInt("##" .. level, level)
		levelInput.SameLine = true

		local modInput = row:AddCell():AddInputScalar("##" .. level .. modifier, modifier)

		levelInput.OnDeactivate = function()
			characterLevelModifier.extraData[level] = nil
			characterLevelModifier.extraData[levelInput.Value[1]] = modInput.Value[1]
			self:renderModifiers(parent, modifiers)
		end

		modInput.OnDeactivate = function()
			characterLevelModifier.extraData[levelInput.Value[1]] = modInput.Value[1]
			self:renderModifiers(parent, modifiers)
		end
	end

	parent:AddButton("+").OnClick = function()
		characterLevelModifier.extraData[#characterLevelModifier.extraData + 1] = 1
		self:renderModifiers(parent, modifiers)
	end

	--#endregion

	--#region Game Level
	---@type HealthClassLevelModifier
	local gameLevelModifier = modifiers["GameLevel"] or {
		value = 0,
		extraData = {}
	} --[[@as HealthClassLevelModifier]]

	modifiers["GameLevel"] = gameLevelModifier

	gameLevelModifier.extraData = gameLevelModifier.extraData or {}

	local gLevelInfoText = parent:AddSeparatorText("Game Level Modifiers ( ? )")
	gLevelInfoText:SetStyle("SeparatorTextAlign", 0, 0.3)
	gLevelInfoText:SetStyle("Alpha", 1)
	gLevelInfoText:Tooltip():AddText([[
	Set the levels at which the modifier changes - for example, setting the modifier to 10% for SCL_MAIN_A
when the base modifier is 5% means the modifier will be 5% on TUT, WLD, and SCL and 10% after.
Setting to 0 will just use base, empty will use the last non-empty value in the table or base if none are found.
	]])

	parent:AddText("Each game level adds")
	local baseGLevelMod = parent:AddInputScalar("% to the % Base Health Mutator##gameLevel", gameLevelModifier.value)
	baseGLevelMod.ItemWidth = 100
	baseGLevelMod.SameLine = true
	baseGLevelMod.OnChange = function()
		gameLevelModifier.value = baseGLevelMod.Value[1]
	end

	local gLevelTable = parent:AddTable("gameModifierCustomizer", 2)
	local gameHeaders = gLevelTable:AddRow()
	gameHeaders.Headers = true
	gameHeaders:AddCell():AddText("Level")
	gameHeaders:AddCell():AddText("% Modifier")

	for _, level in ipairs(EntityRecorder.Levels) do
		local row = gLevelTable:AddRow()
		local levelCell = row:AddCell()

		levelCell:AddText(level)

		local modInput = row:AddCell():AddInputScalar("##" .. level, gameLevelModifier.extraData[level] or 0)
		modInput.ParseEmptyRefVal = true
		modInput.DisplayEmptyRefVal = true

		modInput.OnDeactivate = function()
			gameLevelModifier.extraData[level] = modInput.Value[1] ~= 0 and modInput.Value[1] or nil
		end
	end
	--#endregion

	--#region Character Level
	---@type HealthClassLevelModifier
	local xpRewardLevelModifier = modifiers["XPReward"] or {
		value = 0,
		extraData = {}
	} --[[@as HealthClassLevelModifier]]

	modifiers["XPReward"] = xpRewardLevelModifier

	xpRewardLevelModifier.extraData = xpRewardLevelModifier.extraData or {}

	local xpLevelInfoText = parent:AddSeparatorText("XPReward Modifiers ( ? )")
	xpLevelInfoText:SetStyle("SeparatorTextAlign", 0, 0.3)
	xpLevelInfoText:SetStyle("Alpha", 1)
	xpLevelInfoText:Tooltip():AddText([[
	Set the XPReward Categories at which the modifier changes - for example, setting the modifier to 10% for Elites
when the base modifier is 5% means the modifier will be 5% for Pack/Combatant and 10% levels for elites and above
Setting to 0 will just use base, empty will use the last non-empty value in the table or base if none are found.
]])

	parent:AddText("Each XPReward level adds")
	local baseXPLevelMod = parent:AddInputInt("% to the % Base Health Mutator##xpRewardLevel", xpRewardLevelModifier.value)
	baseXPLevelMod.ItemWidth = 100
	baseXPLevelMod.SameLine = true
	baseXPLevelMod.OnChange = function()
		xpRewardLevelModifier.value = baseXPLevelMod.Value[1]
	end

	local xpLevelTable = parent:AddTable("xpRewardModifierCustomizer", 2)
	local xpHeaders = xpLevelTable:AddRow()
	xpHeaders.Headers = true
	xpHeaders:AddCell():AddText("XPReward")
	xpHeaders:AddCell():AddText("% Modifier")

	for _, xpReward in ipairs(Ext.StaticData.GetAll("ExperienceReward")) do
		---@type ResourceExperienceRewards
		local xpRewardResource = Ext.StaticData.Get(xpReward, "ExperienceReward")
		if xpRewardResource.LevelSource > 0 then
			local row = xpLevelTable:AddRow()
			local levelCell = row:AddCell()


			Styler:HyperlinkText(levelCell, xpRewardResource.Name, function(parent)
				ResourceManager:RenderDisplayWindow(xpRewardResource, parent)
			end)

			local modInput = row:AddCell():AddInputScalar("##" .. xpReward, xpRewardLevelModifier.extraData[xpReward])
			modInput.ParseEmptyRefVal = true
			modInput.DisplayEmptyRefVal = true

			modInput.OnDeactivate = function()
				xpRewardLevelModifier.extraData[xpReward] = modInput.Value[1] ~= 0 and modInput.Value[1] or nil
			end
		end
	end

	--#endregion
end

---@param mutatorModifier HealthClassLevelModifier
---@param characterLevel number
---@return number
local function calculateCharacterLevelModifier(mutatorModifier, characterLevel)
	local cMod = mutatorModifier.extraData[characterLevel]
	if not cMod then
		for i = characterLevel - 1, 0, -1 do
			cMod = mutatorModifier.extraData[i]
			if cMod then
				break
			end
		end
	end

	return (cMod or mutatorModifier.value) * characterLevel
end

---@param mutatorModifier HealthClassLevelModifier
---@param gameLevel string
---@return number
local function calculateGameLevelModifier(mutatorModifier, gameLevel)
	local gMod = mutatorModifier.extraData[gameLevel]
	if not gMod then
		for i = TableUtils:IndexOf(EntityRecorder.Levels, gameLevel) - 1, 1, -1 do
			gMod = mutatorModifier.extraData[EntityRecorder.Levels[i]]
			if gMod then
				break
			end
		end
	end

	return (gMod or mutatorModifier.value) * TableUtils:IndexOf(EntityRecorder.Levels, gameLevel)
end

local xpRewardList = {}

---@param mutatorModifier HealthClassLevelModifier
---@param xpRewardId string
---@return number
local function calculateXPRewardLevelModifier(mutatorModifier, xpRewardId)
	if not next(xpRewardList) then
		for _, xpReward in ipairs(Ext.StaticData.GetAll("ExperienceReward")) do
			---@type ResourceExperienceRewards
			local xpRewardResource = Ext.StaticData.Get(xpReward, "ExperienceReward")
			if xpRewardResource.LevelSource > 0 then
				table.insert(xpRewardList, xpReward)
			end
		end
	end

	local xMod = mutatorModifier.extraData[xpRewardId]
	if not xMod and TableUtils:IndexOf(xpRewardList, xpRewardId) then
		for i = TableUtils:IndexOf(xpRewardList, xpRewardId) - 1, 0, -1 do
			xMod = mutatorModifier.extraData[xpRewardList[i]]
			if xMod then
				break
			end
		end
	end

	return (xMod or mutatorModifier.value) * (TableUtils:IndexOf(xpRewardList, xpRewardId) or 0)
end

---@type ExtuiWindow?
local window

---@param mutator HealthMutator
function HealthMutator:previewResult(mutator)
	if not window then
		window = Ext.IMGUI.NewWindow("Preview Health Mutator")
		window.Closeable = true
		window.AlwaysAutoResize = true
	else
		window.Open = true
		window:SetFocus()
		Helpers:KillChildren(window)
	end

	window:AddButton("Refresh").OnClick = function()
		self:previewResult(mutator)
	end

	window:AddText("Base Health of Character:")
	local healthInput = window:AddInputInt("", 100)
	healthInput.ItemWidth = 40
	healthInput.SameLine = true

	window:AddText("XPReward Of Character:")
	local xpCombo = window:AddCombo("")
	xpCombo.WidthFitPreview = true
	xpCombo.SameLine = true
	local opt = {}
	local xpRewards = {}
	for _, xpReward in ipairs(Ext.StaticData.GetAll("ExperienceReward")) do
		---@type ResourceExperienceRewards
		local xpRewardResource = Ext.StaticData.Get(xpReward, "ExperienceReward")
		if xpRewardResource.LevelSource > 0 then
			xpRewards[xpRewardResource.Name] = xpReward
			table.insert(opt, xpRewardResource.Name)
		end
	end
	xpCombo.Options = opt
	xpCombo.SelectedIndex = 0

	local matrix = window:AddTable("HealthMutatorMatrix", #EntityRecorder.Levels + 1)
	matrix.Borders = true
	matrix.RowBg = true

	local function buildMatrix()
		Helpers:KillChildren(matrix)

		local headerRow = matrix:AddRow()
		headerRow:AddCell()
		for _, gameLevel in ipairs(EntityRecorder.Levels) do
			headerRow:AddCell():AddText(gameLevel)
		end

		local xPRewardMod = calculateXPRewardLevelModifier(mutator.modifiers["XPReward"], xpRewards[xpCombo.Options[xpCombo.SelectedIndex + 1]])

		for c = 1, 30 do
			local row = matrix:AddRow()
			row:AddCell():AddText(tostring(c))

			local characterMod = calculateCharacterLevelModifier(mutator.modifiers["CharacterLevel"], c)
			-- local

			for _, gameLevel in ipairs(EntityRecorder.Levels) do
				local gameMod = calculateGameLevelModifier(mutator.modifiers["GameLevel"], gameLevel)
				local percentToAdd = (mutator.values + (characterMod + gameMod + xPRewardMod)) / 100
				row:AddCell():AddText(tostring(math.floor(healthInput.Value[1] + (healthInput.Value[1] * percentToAdd))))
			end
		end
	end

	healthInput.OnChange = function()
		buildMatrix()
	end
	xpCombo.OnChange = function()
		buildMatrix()
	end

	buildMatrix()
end

function HealthMutator:applyMutator(entity, entityVar)
	---@type HealthMutator
	local mutator = entityVar.appliedMutators[self.name]

	---@type Character
	local charStat = Ext.Stats.Get(entity.Data.StatsId)

	---@type number?
	local xPRewardMod
	if charStat.XPReward then
		xPRewardMod = calculateXPRewardLevelModifier(mutator.modifiers["XPReward"], charStat.XPReward)
	end

	local gameLevelMod = entity.Level and calculateGameLevelModifier(mutator.modifiers["GameLevel"], entity.Level.LevelName) or 0
	local characterMod = calculateCharacterLevelModifier(mutator.modifiers["CharacterLevel"], entity.AvailableLevel.Level)
	local percentageToAdd = (mutator.values + (characterMod + gameLevelMod + xPRewardMod)) / 100

	entityVar.originalValues[self.name] = entity.Health.MaxHp

	local currentHealthPercentage = 1 - (entity.Health.Hp / entity.Health.MaxHp)

	entity.Health.MaxHp = math.floor(entity.Health.MaxHp + (entity.Health.MaxHp * percentageToAdd))
	entity.Health.Hp = entity.Health.MaxHp - (entity.Health.MaxHp * currentHealthPercentage)

	entity:Replicate("Health")
end

function HealthMutator:undoMutator(entity, entityVar)
	local healthPercentage = 1 - (entity.Health.Hp / entity.Health.MaxHp)

	local originalMaxHp = entity.Health.MaxHp

	entity.Health.MaxHp = entityVar.originalValues[self.name]
	entity.Health.Hp = entity.Health.MaxHp - (entity.Health.MaxHp * healthPercentage)

	entity:Replicate("Health")

	Logger:BasicTrace("Undid Health Mutator, reverting max health of %s to %s (current health: %s)",
		entity.ServerCharacter.Template.Name .. "_" .. entity.Uuid.EntityUuid,
		originalMaxHp,
		entity.Health.MaxHp,
		entity.Health.Hp
	)
end
