HealthMutator = MutatorInterface:new("Health")

---@class HealthMutator : Mutator
---@field criteriaValue number

---@class HealthClassLevelModifier : MutationModifier
---@field value number
---@field extraData {[number] : number}

---@param mutator HealthMutator
function HealthMutator:renderMutator(parent, mutator)
	if not mutator.criteriaValue then
		mutator.criteriaValue = 10
	end

	parent:AddText("% Base Health Increase")
	local input = parent:AddInputInt("%", mutator.criteriaValue)
	input.SameLine = true

	input.OnChange = function()
		mutator.criteriaValue = input.Value[1]
	end

	self:renderModifiers(parent, mutator.modifiers)
end

function HealthMutator:renderModifiers(parent, modifiers)
	local modifierParent = parent:AddCollapsingHeader("Modifiers")
	modifierParent:SetColor("Header", {1, 1, 1, 0})

	--#region Character Level
	---@type HealthClassLevelModifier
	local characterLevelModifier = modifiers["CharacterLevel"] or {
		value = 1,
		extraData = {}
	} --[[@as HealthClassLevelModifier]]

	modifierParent:AddText("Each level adds")
	local baseCLevelMod = modifierParent:AddInputInt("% to the % Base Health Mutator##characterLevel", characterLevelModifier.value)
	baseCLevelMod.OnChange = function()
		characterLevelModifier.value = baseCLevelMod.Value[1]
	end

	local cLevelCustomHeader = modifierParent:AddCollapsingHeader("Customize Character Level Modifiers")
	cLevelCustomHeader:SetColor("Header", { 1, 1, 1, 0 })

	local cLevelInfoText = cLevelCustomHeader:AddText(
	"Set the levels at which the modifier changes - for example, setting the modifier to 10% at level 5 when the base modifier is 5% means the modifier will be 5% levels 1-4 and 10% levels 5+")
	cLevelInfoText.TextWrapPos = 200 * Styler:ScaleFactor()
	cLevelInfoText:SetColor("Text", { 1, 1, 1, 0.6 })

	local cLevelTable = cLevelCustomHeader:AddTable("characterModifierCustomizer", 2)
	local headers = cLevelTable:AddRow()
	headers.Headers = true
	headers:AddCell():AddText("Level")
	headers:AddCell():AddText("% Modifier")

	for level, modifier in TableUtils:OrderedPairs(characterLevelModifier.extraData) do
		local row = cLevelTable:AddRow()
		local levelInput = row:AddCell():AddInputInt("##" .. level, level)
		local modInput = row:AddCell():AddInputInt("##" .. level .. modifier, modifier)

		levelInput.OnChange = function ()
			characterLevelModifier.extraData[levelInput.Value[1]] = modInput.Value[1]
			characterLevelModifier.extraData[level] = nil
			Helpers:KillChildren(parent)
			self:renderModifiers(parent, modifiers)
		end

		modInput.OnChange = function ()
			Helpers:KillChildren(parent)
			self:renderModifiers(parent, modifiers)
			characterLevelModifier.extraData[levelInput.Value[1]] = modInput.Value[1]
		end
	end

	--#endregion
end
