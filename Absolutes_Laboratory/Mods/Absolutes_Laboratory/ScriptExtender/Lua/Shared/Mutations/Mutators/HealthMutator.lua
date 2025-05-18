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

	parent:AddText("% Base Health Increase")
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
		value = 1,
		extraData = {}
	} --[[@as HealthClassLevelModifier]]

	modifiers["CharacterLevel"] = characterLevelModifier

	characterLevelModifier.extraData = characterLevelModifier.extraData or {}

	parent:AddText("Each level adds")
	local baseCLevelMod = parent:AddInputInt("% to the % Base Health Mutator##characterLevel", characterLevelModifier.value)
	baseCLevelMod.ItemWidth = 40
	baseCLevelMod.SameLine = true
	baseCLevelMod.OnChange = function()
		characterLevelModifier.value = baseCLevelMod.Value[1]
	end

	local cLevelInfoText = parent:AddSeparatorText("Character Level Modifiers ( ? )")
	cLevelInfoText:SetStyle("SeparatorTextAlign", 0, 0.3)
	cLevelInfoText:SetStyle("Alpha", 1)
	cLevelInfoText:Tooltip():AddText(
		"Set the levels at which the modifier changes - for example, setting the modifier to 10% at level 5\nwhen the base modifier is 5% means the modifier will be 5% levels 1-4 and 10% levels 5+")

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
end
