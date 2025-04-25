StatusDataProxy = ResourceProxy:new()

StatusDataProxy.fieldsToParse = {
	"StatusType",
	"AbsorbSurfaceRange",
	"AbsorbSurfaceType",
	"AiCalculationSpellOverride",
	"ApplyEffect",
	"AuraFlags",
	"AuraRadius",
	"AuraStatuses",
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
	"WeaponOverride",
}

ResourceProxy:RegisterResourceProxy("StatusData", StatusDataProxy)
ResourceProxy:RegisterResourceProxy("DifficultyStatuses", StatusDataProxy)


function StatusDataProxy:buildHyperlinkedStrings(parent, statString)
	if statString and statString ~= "" then
		for statGroup in self:SplitSpring(statString) do
			local leftSide, rightSide = statGroup:match("([^:]*):?(.*)")
			if rightSide then
				rightSide = rightSide:match("^%s*(.-)%s*$")
				---@type StatusData?
				local statusData = self:GetStat(rightSide)

				if statusData then
					local hasKids = #parent.Children > 0
					parent:AddText(leftSide .. ":").SameLine = hasKids

					local text = Styler:HyperlinkText(parent:AddText(rightSide))
					text.SameLine = true

					parent:AddText(";").SameLine = true
					self:RenderDisplayWindow(statusData, text:Tooltip())
				end
			else
				---@type StatusData?
				local statusData = self:GetStat(leftSide:match("^%s*(.-)%s*$"))

				if statusData then
					local hasKids = #parent.Children > 0

					local text = Styler:HyperlinkText(parent:AddText(leftSide .. ";"))
					text.SameLine = hasKids

					self:RenderDisplayWindow(statusData, text:Tooltip())
				end
			end
		end
	end
end
