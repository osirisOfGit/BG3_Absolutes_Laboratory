SpellProxy = ResourceProxy:new()
SpellProxy.fieldsToParse = {
	"SpellType",
	"Acceleration",
	"AddRangeFromAbility",
	"AiCalculationSpellOverride",
	"AIFlags",
	"AlternativeCastTextEvents",
	"AmountOfTargets",
	"SpellAnimationIntentType",
	"AreaRadius",
	"Autocast",
	"Base",
	"CastTargetHitDelay",
	"CombatAIOverrideSpell",
	"ConcentrationSpellID",
	"ContainerSpells",
	"Cooldown",
	"CycleConditions",
	"Damage",
	"Damage",
	"DamageType",
	"DeathType",
	"DelayRollDie",
	"DelayRollTarget",
	"DelayTurnsCount",
	"Description",
	"DescriptionRef",
	"DescriptionParams",
	"DisappearEffect",
	"DisplayName",
	"DisplayNameRef",
	"Distribution",
	"DualWieldingUseCosts",
	"EndPosRadius",
	"ExplodeRadius",
	"ExtraDescription",
	"ExtraDescriptionRef",
	"ExtraDescriptionParams",
	"ExtraProjectileTargetConditions",
	"FollowUpOriginalSpell",
	"ForceTarget",
	"ForkChance",
	"ForkingConditions",
	"ForkLevels",
	"Height",
	"HighlightConditions",
	"HitCosts",
	"HitDelay",
	"HitEffect",
	"HitExtension",
	"HitRadius",
	"Icon",
	"IgnoreTeleport",
	"InterruptPrototype",
	"ItemWall",
	"ItemWallStatus",
	"JumpDelay",
	"Level",
	"Lifetime",
	"LineOfSightFlags",
	"MaxAttacks",
	"MaxDistance",
	"MaxForkCount",
	"MaxHitsPerTurn",
	"MaximumTargets",
	"MaximumTotalTargetHP",
	"MemorizationRequirements",
	"MinHitsPerTurn",
	"MinJumpDistance",
	"MovementSpeed",
	"MovingObjectSummonTemplate",
	"NextAttackChance",
	"NextAttackChanceDivider",
	"OnlyHit1Target",
	"OriginSpellFail",
	"OriginSpellProperties",
	"OriginSpellRoll",
	"OriginSpellSuccess",
	"OriginTargetConditions",
	"OverrideSpellLevel",
	"PowerLevel",
	"PreviewCursor",
	"PreviewEffect",
	"PreviewStrikeHits",
	"ProjectileCount",
	"ProjectileDelay",
	"ProjectileSpells",
	"ProjectileTerrainOffset",
	"ProjectileType",
	"Range",
	"ReappearEffect",
	"ReappearEffectTextEvent",
	"RechargeValues",
	"Requirement",
	"RequirementConditions",
	"RequirementEvents",
	"Requirements",
	"RitualCosts",
	"RootSpellID",
	"Sheathing",
	"ShortDescription",
	"ShortDescriptionRef",
	"ShortDescriptionParams",
	"Shuffle",
	"SingleSource",
	"SpawnEffect",
	"SpellActionType",
	"SpellActionTypePriority",
	"Spellbook",
	"SpellCategory",
	"SpellContainerID",
	"SpellEffect",
	"SpellFail",
	"SpellFlags",
	"SpellJumpType",
	"MemoryCost",
	"SpellProperties",
	"SpellRoll",
	"SpellSchool",
	"SpellStyleGroup",
	"SpellSuccess",
	"Stealth",
	"StopAtFirstContact",
	"StormEffect",
	"StrikeCount",
	"SurfaceGrowInterval",
	"SurfaceGrowStep",
	"SurfaceLifetime",
	"SurfaceRadius",
	"SurfaceType",
	"TargetCeiling",
	"TargetConditions",
	"TargetFloor",
	"TargetGroundEffect",
	"TargetHitEffect",
	"TargetProjectiles",
	"TargetRadius",
	"TeleportDelay",
	"TeleportSelf",
	"TeleportSurface",
	"Template",
	"ThrowableSpellFail",
	"ThrowableSpellProperties",
	"ThrowableSpellRoll",
	"ThrowableSpellSuccess",
	"ThrowableTargetConditions",
	"ThrowOrigin",
	"TooltipAttackSave",
	"TooltipDamageList",
	"TooltipOnMiss",
	"TooltipOnSave",
	"TooltipPermanentWarnings",
	"TooltipSpellDCAbilities",
	"TooltipStatusApply",
	"TooltipUpcastDescription",
	"TooltipUpcastDescriptionParams",
	"UseCosts",
	"UseWeaponDamage",
	"UseWeaponProperties",
	"VerbalIntent",
	"WallEndEffect",
	"WallStartEffect",
	"WeaponBones",
	"WeaponTypes",
}

ResourceProxy:RegisterResourceProxy("Spell", SpellProxy)
ResourceProxy:RegisterResourceProxy("SpellData", SpellProxy)

---@param resourceValue string
function SpellProxy:RenderDisplayableValue(parent, resourceValue)
	if resourceValue then
		---@type SpellData
		local spell = Ext.Stats.Get(resourceValue)

		if spell then
			local statText = Styler:HyperlinkText(parent:AddText(resourceValue))
			ResourceManager:RenderDisplayWindow(spell, statText:Tooltip())
		else
			parent:AddText(spell)
		end
	end
end

SpellRollProxy = ResourceProxy:new()

ResourceProxy:RegisterResourceProxy("SpellRoll", SpellRollProxy)

---@param resourceValue table
function SpellRollProxy:RenderDisplayableValue(parent, resourceValue)
	if resourceValue then
		local displayTable = parent:AddTable("spellRoll", 2)
		displayTable.Borders = true
		displayTable:AddColumn("", "WidthFixed")
		displayTable:AddColumn("", "WidthStretch")

		for property, value in TableUtils:OrderedPairs(resourceValue) do
			local row = displayTable:AddRow()
			row:AddCell():AddText(property)
			row:AddCell():AddText(tostring(value))
		end
	end
end
