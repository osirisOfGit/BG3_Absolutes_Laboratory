HealthMutator = MutatorInterface:new("Health")

---@class HealthMutator : Mutator
---@field values number

---@class HealthClassLevelModifier : MutationModifier
---@field value number
---@field extraData {[number] : number}

---@param mutator HealthMutator
function HealthMutator:renderMutator(parent, mutator)
	if not mutator.values then
		mutator.values = 10
	end

	parent:AddText("Base Health Increases by ")
	local input = parent:AddInputInt("%", mutator.values)
	input.ItemWidth = 40
	input.SameLine = true

	input.OnChange = function()
		mutator.values = input.Value[1]
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
	local baseCLevelMod = parent:AddInputInt("% to the % Base Health Mutator##characterLevel", characterLevelModifier.value)
	baseCLevelMod.ItemWidth = 40
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

		local modInput = row:AddCell():AddInputInt("##" .. level .. modifier, modifier)

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
	gLevelInfoText:Tooltip():AddText(
		"\t Set the levels at which the modifier changes - for example, setting the modifier to 10% for SCL_MAIN_A\nwhen the base modifier is 5% means the modifier will be 5% on TUT, WLD, and SCL and 10% after. Setting to 0 will just use base.")

	parent:AddText("Each game level adds")
	local baseGLevelMod = parent:AddInputInt("% to the % Base Health Mutator##gameLevel", gameLevelModifier.value)
	baseGLevelMod.ItemWidth = 40
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

		local modInput = row:AddCell():AddInputInt("##" .. level, gameLevelModifier.extraData[level] or 0)

		modInput.OnDeactivate = function()
			gameLevelModifier.extraData[level] = modInput.Value[1] > 0 and modInput.Value[1] or nil
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
	xpLevelInfoText:Tooltip():AddText(
		"\t Set the XPReward Categories at which the modifier changes - for example, setting the modifier to 10% for Elites\nwhen the base modifier is 5% means the modifier will be 5% for Pack/Combatant and 10% levels for elites and above")

	parent:AddText("Each XPReward level adds")
	local baseXPLevelMod = parent:AddInputInt("% to the % Base Health Mutator##xpRewardLevel", xpRewardLevelModifier.value)
	baseXPLevelMod.ItemWidth = 40
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

			local modInput = row:AddCell():AddInputInt("##" .. xpReward, xpRewardLevelModifier.extraData[xpReward] or 0)

			modInput.OnDeactivate = function()
				xpRewardLevelModifier.extraData[xpReward] = modInput.Value[1] > 0 and modInput.Value[1] or nil
			end
		end
	end

	--#endregion
end
