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
ResourceProxy:RegisterResourceProxy("StatusContainer", StatusDataProxy)


function StatusDataProxy:RenderDisplayableValue(parent, statString)
	if statString and statString ~= "" then
		local statusTable = {}
		if type(statString) == "string" then
			for val in self:SplitSpring(statString) do
				table.insert(statusTable, val)
			end
		else
			statusTable = statString
		end

		for _, statGroup in ipairs(statusTable) do
			local leftSide, rightSide = statGroup:match("([^:]*):?(.*)")
			if rightSide and rightSide ~= "" then
				rightSide = rightSide:match("^%s*(.-)%s*$")
				---@type StatusData?
				local statusData = self:GetStat(rightSide)

				if statusData then
					local hasKids = #parent.Children > 0
					parent:AddText(leftSide .. ":").SameLine = hasKids

					local text = Styler:HyperlinkText(parent, rightSide, function(parent)
						self:RenderDisplayWindow(statusData, parent)
					end)
					text.SameLine = true

					parent:AddText(";").SameLine = true
				end
			else
				Logger:BasicInfo(leftSide)
				---@type StatusData?
				local statusData = self:GetStat(leftSide:match("^%s*(.-)%s*$"))

				if statusData then
					local hasKids = #parent.Children > 0

					local text = Styler:HyperlinkText(parent, leftSide .. ";", function(parent)
						self:RenderDisplayWindow(statusData, parent)
					end)

					text.SameLine = hasKids
				end
			end
		end
	end
end
