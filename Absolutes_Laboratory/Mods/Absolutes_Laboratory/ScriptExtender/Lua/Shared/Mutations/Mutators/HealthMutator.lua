---@class HealthMutatorClass : MutatorInterface
HealthMutator = MutatorInterface:new("Health")
HealthMutator.affectedComponents = {
	"BoostsContainer",
	"Health"
}

function HealthMutator:priority()
	return self:recordPriority(ClassesAndSubclassesMutator:priority() + BoostsMutator:priority())
end

function HealthMutator:Transient()
	return false
end

---@param mutator HealthMutator
---@param existingMutator HealthMutator
function HealthMutator:canBeAdditive(mutator, existingMutator)
	if existingMutator then
		if (mutator.staticHealth and existingMutator.staticHealth)
			or (not mutator.staticHealth and not existingMutator.staticHealth) then
			return false
		end
	end
	return true
end

---@alias HealthModifierKeys "CharacterLevel"|"GameLevel"|"XPReward"

---@class HealthMutator : Mutator
---@field values number
---@field staticHealth number
---@field modifiers {[HealthModifierKeys]: HealthClassLevelModifier}

---@class HealthClassLevelModifier : MutationModifier
---@field value number
---@field extraData {[number] : number}

---@param mutator HealthMutator
function HealthMutator:renderMutator(parent, mutator)
	Helpers:KillChildren(parent)
	if not mutator.values and not mutator.staticHealth then
		mutator.values = 10
	end

	Styler:DualToggleButton(parent, "Static", "Dynamic", false, function(swap)
		if swap then
			if mutator.values then
				mutator.values = nil
				mutator.staticHealth = 100
				mutator.modifiers.delete = true
			else
				mutator.staticHealth = nil
				mutator.values = 10
			end

			self:renderMutator(parent, mutator)
		end

		return mutator.staticHealth ~= nil
	end)

	if mutator.values then
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
		mutator.modifiers = mutator.modifiers or {}
		self:renderModifiers(modifierParent, mutator.modifiers)
	else
		parent:AddText("Set Entity Health To: ")
		local staticHealthInput = parent:AddInputInt("", mutator.staticHealth)
		staticHealthInput.SameLine = true
		staticHealthInput.ItemWidth = 80
		staticHealthInput.OnChange = function()
			if staticHealthInput.Value[1] <= 0 then
				staticHealthInput.Value = { 1, 1, 1, 1 }
			end
			mutator.staticHealth = staticHealthInput.Value[1]
		end
	end
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
		"\t Set the levels at which the modifier increases - for example, setting the modifier to 10% at level 5\nwhen the base modifier is 5% means the modifier will be 5% levels 1-4 and 15% levels 5+")

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

	--#region XPReward
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

function HealthMutator:handleDependencies()
	-- NOOP
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
	---@type HealthMutator[]
	local mutators = entityVar.appliedMutators[self.name]
	if not mutators[1] then
		mutators = { mutators }
	end

	entityVar.originalValues[self.name] = {
		healthPercentage = 1 - (entity.Health.Hp / entity.Health.MaxHp)
	}

	local percentageToAdd = 0

	for _, mutator in TableUtils:OrderedPairs(mutators, function(key, value)
		return value.staticHealth and 1 or 2
	end) do
		if mutator.values then
			---@type Character
			local charStat = Ext.Stats.Get(entity.Data.StatsId)

			---@type number?
			local xPRewardMod = 0
			if charStat.XPReward then
				xPRewardMod = calculateXPRewardLevelModifier(mutator.modifiers["XPReward"], charStat.XPReward)
			end

			local gameLevelMod = entity.Level and calculateGameLevelModifier(mutator.modifiers["GameLevel"], entity.Level.LevelName) or 0
			local characterMod = calculateCharacterLevelModifier(mutator.modifiers["CharacterLevel"], entity.AvailableLevel.Level)

			local baseHp = percentageToAdd > 0 and percentageToAdd or entity.Health.MaxHp
			local dynamicPercentage = (mutator.values + (characterMod + gameLevelMod + xPRewardMod)) / 100

			percentageToAdd = baseHp + math.floor(baseHp * dynamicPercentage)

			Logger:BasicDebug(
				"Dynamic calculation will increase max health of %d by %s%% to a value of %d (base: %s%%, character: %s%%, gameLevel: %s%%, xpReward: %s%%)",
				baseHp,
				(mutator.values + (characterMod + gameLevelMod + xPRewardMod)),
				percentageToAdd,
				mutator.values,
				characterMod,
				gameLevelMod,
				xPRewardMod
			)
		else
			percentageToAdd = mutator.staticHealth
			Logger:BasicDebug("Static Calculation will change max health from %d to %d",
				entity.Health.MaxHp,
				mutator.staticHealth)
		end
	end

	local boostString = ("IncreaseMaxHP(%d)"):format(math.floor(percentageToAdd - entity.Health.MaxHp))
	entityVar.originalValues[self.name].boost = boostString

	Osi.AddBoosts(entity.Uuid.EntityUuid, boostString, entity.Uuid.EntityUuid, entity.Uuid.EntityUuid)
	Logger:BasicDebug("Applied boost %s", boostString)
end

function HealthMutator:undoMutator(entity, entityVar)
	if type(entityVar.originalValues[self.name]) == "table" then
		Logger:BasicDebug("Removing Health Boost %s", entityVar.originalValues[self.name].boost)
		Osi.RemoveBoosts(entity.Uuid.EntityUuid, entityVar.originalValues[self.name].boost, 0, entity.Uuid.EntityUuid, entity.Uuid.EntityUuid)
	else
		Ext.System.ServerStats.CalculationRequests[entity] = Ext.Enums.StatsDirtyFlags.MaxHP
	end
end

function HealthMutator:FinalizeMutator(entity)
	Ext.Timer.WaitFor(200, function()
		---@type MutatorEntityVar
		local entityVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME]

		if entityVar then
			local healthPercentage = entityVar.originalValues[self.name].healthPercentage

			if healthPercentage ~= (1 - (entity.Health.Hp / entity.Health.MaxHp)) then
				Logger:BasicDebug("Manually updating %s (%s) current health of %d to %d, matching the original percentage of %d%%",
					EntityRecorder:GetEntityName(entity),
					entity.Uuid.EntityUuid,
					entity.Health.Hp,
					entity.Health.MaxHp - math.max(0, math.floor((entity.Health.MaxHp * healthPercentage))),
					math.min(100, (1 + healthPercentage) * 100))

				entity.Health.Hp = entity.Health.MaxHp - math.max(0, math.floor((entity.Health.MaxHp * healthPercentage)))
				entity:Replicate("Health")
			end
		end
	end)
end

---@return MazzleDocsDocumentation
function HealthMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Health",
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "",
					prefix_color = "Yellow",
					text = [[
Dependency On: Level Mutator (but runs after Boosts and (Sub)Classes Mutators to try and ensure some predictability with all the other factors)
Transient: No
Composable: Static Overwrites Static, Dynamic Overwrites Dynamic. Static is always applied first]]
				} --[[@as MazzleDocsCallOut]],
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Summary"
				},
				{
					type = "Content",
					text =
					[[This is a conceptually simple mutator that allows for some unique complexity - namely, it allows you to define Health curves for different mob types of different character levels in different game levels, which can be previewed using the button showed above.

The Modifiers are additive to the base amount, but also allow setting negative and decimal values, allowing you to define the curve exactly as you wish.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Client-Side Content"
				},
				{
					type = "Content",
					text = [[
The mutator is laid out as follows:

Static vs Dynamic Toggle - if set to Static, you'll set the Entity Health to exactly that value, no modifiers included.
Dynamic takes the entity's current max health and changes it according the % defined (positive or negative), modifiers included.
The Preview button shows you exactly what the result will be for the combinations you select.

The rest of the Mutator UI is explained via tooltips to avoid duplicated info and inevitable deprecation of information.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Server-Side Implementation"
				},
				{
					type = "Content",
					text = [[
This Mutator directly applies a `IncreaseMaxHP` boost via `Osi.AddBoosts(entity.Uuid.EntityUuid, "IncreaseMaxHP(flatValue)", entity.Uuid.EntityUuid, entity.Uuid.EntityUuid)` call - this originally just modified the Health component on the entity, but the engine liked to reset the customizations in that component whenever the maxHp needed to be recalculated, so this ensures the desired value both persists through boost updates and includes them in the final result.
A final calculation is done ~200ms after the boost is applied to update the health percentage to the correct value, based on what their pre-mutation health percentage was, preventing any full-heal shenanigans - meaning, if the entity's health is 7/10, and the max health is set to 20, the current health will be updated to 14 (70% of 20).

If a Static and a Dyanmic Health Mutator in different Mutations make it to the final pool (due to the one lower in the profile order being set to Composable), Lab will apply the Static version first, then the Dynamic version on top of that.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Example Use Cases"
				},
				{
					type = "Section",
					text = "Selected entities:"
				},
				{
					type = "Bullet",
					text = {
						"that aren't bosses should have 50% more health, otherwise they should have 100% more",
						"should have a 10% increase every Game Level until IRN_Main_A, at which point they start losing 5% every Game level",
						"gain 5% every Game Level, subtracting 1% for every rung up on the XPReward ladder (so Bosses will be (5% - 5% = 0%) on the TUT ship)"
					}
				} --[[@as MazzleDoctsBullet]],
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function HealthMutator:generateChangelog()
	return {
		["1.8.4"] = {
			type = "Bullet",
			text = {
				"Decreases the priority to run after (Sub)Classes and Boosts Mutators, to try and help with predictability"
			}
		},
		["1.8.0"] = {
			type = "Bullet",
			text = {
				"Rework the server-side applicaiton, using an IncreaseMaxHP boost instead of direct component changes"
			}
		},
		["1.7.3"] = {
			type = "Bullet",
			text = {
				"Fix the health listener running on entities that already had their mutations undone"
			}
		},
		["1.7.1"] = {
			type = "Bullet",
			text = {
				"Added a Health Component Subscription to entities to reset their MaxHP to the Lab-set value whenever it's reset by the game"
			}
		},
		["1.6.0"] = {
			type = "Bullet",
			text = {
				"Fix execution when the math ain't whole numbers",
				"Changes Additive behavior for Health Mutators - Dynamic overwrites Dynamic, Static Overwrites Static, but Static and Dynamic can be run together (Static will always run first)"
			}
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
