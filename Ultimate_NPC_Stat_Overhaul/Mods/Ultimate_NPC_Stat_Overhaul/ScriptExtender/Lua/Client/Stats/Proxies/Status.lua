StatusDataProxy = StatProxy:new()

StatusDataProxy.statsToParse = {
	"StatusType",
	"AbsorbSurfaceRange",
	"AbsorbSurfaceType",
	"AiCalculationSpellOverride",
	"AnimationEnd",
	"AnimationLoop",
	"AnimationStart",
	"ApplyEffect",
	"AuraFlags",
	"AuraFX",
	"AuraRadius",
	"AuraStatuses",
	"BeamEffect",
	"BonusFromSkill",
	"Boosts",
	"Charges",
	"DefendTargetPosition",
	"Description",
	"DescriptionRef",
	"DescriptionParams",
	"DieAction",
	"DisableInteractions",
	"DisplayName",
	"DisplayNameRef",
	"DynamicAnimationTag",
	"EndEffect",
	"ForceStackOverwrite",
	"FreezeTime",
	"HealEffectId",
	"HealMultiplier",
	"HealStat",
	"HealType",
	"HealValue",
	"HideOverheadUI",
	"ImmuneFlag",
	"Instant",
	"Items",
	"LeaveAction",
	"ManagedStatusEffectGroup",
	"ManagedStatusEffectType",
	"Necromantic",
	"NumStableFailed",
	"NumStableSuccess",
	"OnApplyConditions",
	"OnApplyFail",
	"OnApplyFunctors",
	"OnApplyRoll",
	"OnApplySuccess",
	"OnRemoveFail",
	"OnRemoveFunctors",
	"OnRemoveRoll",
	"OnRemoveSuccess",
	"OnRollsFailed",
	"OnSuccess",
	"OnTickFail",
	"OnTickRoll",
	"OnTickSuccess",
	"Passives",
	"PeaceOnly",
	"PerformEventName",
	"PlayerHasTag",
	"PlayerSameParty",
	"PolymorphResult",
	"Projectile",
	"Radius",
	"RemoveConditions",
	"RemoveEvents",
	"ResetCooldowns",
	"RetainSpells",
	"Rules",
	"Sheathing",
	"Spells",
	"StableRoll",
	"StableRollDC",
	"StackId",
	"StackPriority",
	"StackType",
	"StatsId",
	"StatusEffect",
	"StatusEffectOnTurn",
	"StatusEffectOverride",
	"StatusEffectOverrideForItems",
	"StatusGroups",
	"StatusPropertyFlags",
	"SurfaceChange",
	"TargetConditions",
	"TargetEffect",
	"TemplateID",
	"TickFunctors",
	"TickType",
	"Toggle",
	"TooltipDamage",
	"TooltipPermanentWarnings",
	"TooltipSave",
	"UseLyingPickingState",
	"WeaponOverride",

}

StatProxy:RegisterStatType("StatusData", StatusDataProxy)
StatProxy:RegisterStatType("DifficultyStatuses", StatusDataProxy)


function StatusDataProxy:buildHyperlinkedStrings(parent, statString)
	if statString and statString ~= "" then
		for statGroup in self:SplitSpring(statString) do
			local leftSide, rightSide = statGroup:match("([^:]*):?(.*)")
			if rightSide then
				---@type StatusData?
				local statusData = self:Get(rightSide:match("^%s*(.-)%s*$"))

				if statusData then
					local hasKids = #parent.Children > 0
					parent:AddText(leftSide .. " : ").SameLine = hasKids

					local text = parent:AddText(rightSide .. ";")
					text.SameLine = true
					text:SetColor("Text", { 173 / 255, 216 / 255, 230 / 255, 1 })
					self:RenderDisplayWindow(statusData, text:Tooltip())
				end
			else
				---@type StatusData?
				local statusData = self:Get(leftSide:match("^%s*(.-)%s*$"))

				if statusData then
					local hasKids = #parent.Children > 0

					local text = parent:AddText(leftSide .. ";")
					text.SameLine = hasKids
					text:SetColor("Text", { 173 / 255, 216 / 255, 230 / 255, 1 })

					self:RenderDisplayWindow(statusData, text:Tooltip())
				end
			end
		end
	end
end
