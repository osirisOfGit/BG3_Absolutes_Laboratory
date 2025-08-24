---@class BoostsMutatorClass : MutatorInterface
BoostsMutator = MutatorInterface:new("Boosts")

---@class BoostTable
---@field name string
---@field definition table

---@class BoostsMutator : Mutator
---@field values BoostTable[]

---@param mutator BoostsMutator
function BoostsMutator:renderMutator(parent, mutator)
	Helpers:KillChildren(parent)
	mutator.values = mutator.values or {}

	local popup = parent:AddPopup("boostPopup")

	local comboOpts = {}
	for name in TableUtils:OrderedPairs(self.BoostDefinitions) do
		table.insert(comboOpts, name)
	end

	local boostDisplayTable = parent:AddTable("boosts", 5)
	boostDisplayTable.BordersInnerH = true
	boostDisplayTable.RowBg = true
	boostDisplayTable:AddColumn("", "WidthFixed")

	local headers = boostDisplayTable:AddRow()
	headers.Headers = true
	headers:AddCell()
	headers:AddCell():AddText("Boost Type")
	headers:AddCell():AddText("Param 1")
	headers:AddCell():AddText("Param 2")
	headers:AddCell():AddText("Param 3")

	for i, boostTable in TableUtils:OrderedPairs(mutator.values, function(key, value)
		return value.name or ""
	end) do
		local boostDisplayRow = boostDisplayTable:AddRow()

		local deleteButton = Styler:ImageButton(boostDisplayRow:AddCell():AddImageButton("delete" .. i, "ico_red_x", { 16, 16 }))
		deleteButton.OnClick = function()
			mutator.values[i].delete = true
			TableUtils:ReindexNumericTable(mutator.values)
			self:renderMutator(parent, mutator)
		end

		local nameCombo = boostDisplayRow:AddCell():AddCombo("")
		nameCombo.Options = comboOpts
		nameCombo.SelectedIndex = (TableUtils:IndexOf(comboOpts, boostTable.name) or 0) - 1
		nameCombo.OnChange = function()
			boostTable.name = nameCombo.Options[nameCombo.SelectedIndex + 1]
			boostTable.definition = {}
			self:renderMutator(parent, mutator)
		end

		if boostTable.name then
			for d, boostDefType in ipairs(self.BoostDefinitions[boostTable.name]) do
				---@cast boostDefType string

				local cell = boostDisplayRow:AddCell()

				if type(boostDefType) == "table" then
					local enumCombo = cell:AddCombo("")
					enumCombo.WidthFitPreview = true
					enumCombo.Options = TableUtils:DeeplyCopyTable(boostDefType)
					enumCombo.SelectedIndex = (TableUtils:IndexOf(boostDefType, boostTable.definition[d]) or 0) - 1
					enumCombo.OnChange = function()
						boostTable.definition[d] = enumCombo.Options[enumCombo.SelectedIndex + 1]
					end
				elseif boostDefType:lower() == "number" or boostDefType:lower() == "percentage" then
					local numberInput = cell:AddInputInt("", boostTable.definition[d] or 0)
					numberInput.ItemWidth = 80
					numberInput.OnChange = function()
						boostTable.definition[d] = numberInput.Value[1]
					end

					if boostDefType:lower() == "percentage" then
						cell:AddText("%").SameLine = true
					end
				elseif boostDefType:lower() == "boolean" then
					local booleanBox = cell:AddCheckbox("", boostTable.definition[d] == "true")
					booleanBox.Label = booleanBox.Checked and "True" or "False"

					booleanBox.OnChange = function()
						boostTable.definition[d] = booleanBox.Checked
						booleanBox.Label = booleanBox.Checked and "True" or "False"
					end
				elseif boostDefType:lower() == "dice" then
					boostTable.definition[d] = boostTable.definition[d] or {}
					boostTable.definition[d]["diceNum"] = boostTable.definition[d]["diceNum"] or 1
					local numberOfDice = cell:AddInputInt("##diceNum", boostTable.definition[d]["diceNum"])
					numberOfDice.ItemWidth = 40
					numberOfDice.OnChange = function()
						if numberOfDice.Value[1] < 1 then
							numberOfDice.Value = { 1, 1, 1, 1 }
						end
						boostTable.definition[d]["diceNum"] = numberOfDice.Value[1]
					end

					cell:AddText("d").SameLine = true

					boostTable.definition[d]["diceSize"] = boostTable.definition[d]["diceSize"] or 1
					local diceSize = cell:AddInputInt("##diceSize", boostTable.definition[d]["diceSize"])
					diceSize.SameLine = true
					diceSize.ItemWidth = 40
					diceSize.OnChange = function()
						if diceSize.Value[1] < 1 then
							diceSize.Value = { 1, 1, 1, 1 }
						end
						boostTable.definition[d]["diceSize"] = diceSize.Value[1]
					end
				elseif Ext.Enums[boostDefType] then
					local enum = Ext.Enums[boostDefType]
					local options = {}
					for enumVal in TableUtils:OrderedPairs(enum, nil, function(key, value)
						return type(key) == "string"
					end) do
						table.insert(options, tostring(enumVal))
					end

					local enumCombo = cell:AddCombo("")
					enumCombo.WidthFitPreview = true
					enumCombo.Options = options
					enumCombo.SelectedIndex = (TableUtils:IndexOf(options, boostTable.definition[d]) or 0) - 1
					enumCombo.OnChange = function()
						boostTable.definition[d] = enumCombo.Options[enumCombo.SelectedIndex + 1]
					end
				else
					local success, data = pcall(
					---@return Guid[]
						function()
							return Ext.StaticData.GetAll(boostDefType)
						end)
					if success then
						local searchInput = cell:AddInputText("")
						searchInput.Text = (boostDefType == "Faction" and boostTable.definition[d])
							and Ext.StaticData.Get(boostTable.definition[d], boostDefType).Faction
							or boostTable.definition[d]
							or ""

						searchInput.AutoSelectAll = true
						searchInput.Hint = ("Search for %s, min 2 chars"):format(boostDefType)
						local timer
						searchInput.OnChange = function()
							if #searchInput.Text >= 2 then
								if timer then
									Ext.Timer.Cancel(timer)
								end
								timer = Ext.Timer.WaitFor(500, function()
									Helpers:KillChildren(popup)
									popup:Open()

									for _, resourceId in TableUtils:OrderedPairs(data, function(key, value)
										local resource = Ext.StaticData.Get(value, boostDefType)
										return (boostDefType == "Faction") and resource.Faction or resource.Name
									end) do
										---@type ResourceTag|ResourceActionResource|ResourceFaction
										local resource = Ext.StaticData.Get(resourceId, boostDefType)
										if ((boostDefType == "Faction") and resource.Faction or resource.Name):lower():find(searchInput.Text:lower()) then
											popup:AddSelectable((boostDefType == "Faction") and resource.Faction or resource.Name).OnClick = function(select)
												searchInput.Text = select.Label
												boostTable.definition[d] = (boostDefType == "Faction") and resourceId or select.Label
											end
										end
									end

									timer = nil
								end)
							end
						end
					else
						Logger:BasicWarning("Couldn't determine how to render Boost Def Type %s for Boost %s, report this to the idiot that coded it", boostDefType, boostTable.name)
					end
				end
			end
		end
	end

	parent:AddButton("Add Boost").OnClick = function()
		table.insert(mutator.values, { name = nil, definition = {} } --[[@as BoostTable]])
		self:renderMutator(parent, mutator)
	end
end

---@class BoostDefinition
BoostsMutator.BoostDefinitions = {
	Ability = {
		"AbilityId",
		"number"
	},
	AbilityFailedSavingThrow = {
		"AbilityId"
	},
	AC = {
		"number"
	},
	ActionResourceBlock = {
		"ActionResource"
	},
	ActionResourceConsumeMultiplier = {
		"ActionResource",
		"number",
		"number"
	},
	ActionResourceOverride = {
		"ActionResource",
		"number",
		"number"
	},
	Advantage = {
		"AdvantageContext"
	},
	BlockRegainHP = {},
	BlockSpellCast = {},
	BlockTravel = {},
	BlockVerbalComponent = {},
	CanShootThrough = {
		"boolean"
	},
	CanWalkThrough = {
		"boolean"
	},
	CharacterUnarmedDamage = {
		"dice",
		"DamageType"
	},
	CharacterWeaponDamage = {
		"dice",
		"DamageType"
	},
	CriticalDamageOnHit = {},
	DamageBonus = {
		"dice"
	},
	DamageReduction = {
		"DamageType",
		{
			"Flat",
			"Half"
		},
		"number"
	},
	DarkvisionRangeMin = {
		"number"
	},
	DetectDisturbancesBlock = {
		"boolean"
	},
	DialogueBlock = {},
	Disadvantage = {
		"AdvantageContext"
	},
	FactionOverride = {
		"Faction"
	},
	FallDamageMultiplier = {
		"number"
	},
	HalveWeaponDamage = {
		"AbilityId"
	},
	HorizontalFOVOverride = {
		"number"
	},
	IgnoreDamageThreshold = {
		"DamageType",
		"number"
	},
	IgnoreFallDamage = {},
	IgnoreLeaveAttackRange = {},
	IgnoreResistance = {
		"DamageType",
		{
			"Resistant",
			"Immune"
		}
	},
	IncreaseMaxHP = {
		"percentage"
	},
	Initiative = {
		"number"
	},
	Invulnerable = {},
	JumpMaxDistanceMultiplier = {
		"number"
	},
	MovementSpeedLimit = {
		{
			"Stroll",
			"Walk",
		}
	},
	ObjectSize = {
		"number"
	},
	Proficiency = {
		"ProficiencyGroupFlags"
	},
	ProjectileDeflect = {},
	RedirectDamage = {
		"number"
	},
	ReduceCriticalAttackThreshold = {
		"number"
	},
	Reroll = {
		"StatsRollType",
		"number",
		"boolean"
	},
	Resistance = {
		"DamageType",
		{
			"Vulnerable",
			"Resistant",
			"Immune"
		}
	},
	RollBonus = {
		"StatsRollType",
		"dice",
		"wildcard"
	},
	ScaleMultiplier = {
		"number"
	},
	SightRangeOverride = {
		"number"
	},
	SourceAdvantageOnAttack = {},
	SpellSaveDC = {
		"number"
	},
	StatusImmunity = {
		"status"
	},
	Tag = {
		"Tag"
	},
	TemporaryHP = {
		{
			"StrengthModifier",
			"DexterityModifier",
			"ConstitutionModifier",
			"IntelligenceModifier",
			"WisdomModifier",
			"CharismaModifier"
		}
	},
	WeaponEnchantment = {
		"number"
	},
	WeaponProperty = {
		"WeaponFlags"
	},
	WeightCategory = {
		"number"
	}
}

--[[
Boosts:
Ability Ability(Strength,2);
AbilityFailedSavingThrow AbilityFailedSavingThrow(Strength);
AC AC(1)
ActionResourceBlock ActionResourceBlock(Movement)
ActionResourceConsumeMultiplier ActionResourceConsumeMultiplier(ActionPoint,0,0);
ActionResourceOverride ActionResourceOverride(LegendaryResistanceCharge,99,0);
Advantage Advantage(AttackRoll)
BlockRegainHP BlockRegainHP()
BlockSpellCast BlockSpellCast()
BlockTravel BlockTravel
BlockVerbalComponent BlockVerbalComponent()
CanShootThrough CanShootThrough(true)
CanWalkThrough CanWalkThrough(true)
CharacterUnarmedDamage CharacterUnarmedDamage(1d4, Force)
CharacterWeaponDamage CharacterWeaponDamage(1d4, Radiant)
CriticalDamageOnHit CriticalDamageOnHit()
DamageBonus DamageBonus(2d8)
DamageReduction DamageReduction(All, Flat, 1000); DamageReduction(Force,Flat,100)
DarkvisionRangeMin DarkvisionRangeMin(24)
DetectDisturbancesBlock DetectDisturbancesBlock(true)
DialogueBlock DialogueBlock()
Disadvantage Disadvantage(AllSavingThrows);Disadvantage(AttackRoll);Disadvantage(AllAbilities);
FactionOverride FactionOverride(9c896609-f2f6-4f1a-8967-c83140977975)
FallDamageMultiplier FallDamageMultiplier(0.5)
HalveWeaponDamage HalveWeaponDamage(Strength);HalveWeaponDamage(Dexterity)
HorizontalFOVOverride HorizontalFOVOverride(10)
IgnoreDamageThreshold IgnoreDamageThreshold(Lightning,10)
IgnoreFallDamage IgnoreFallDamage()
IgnoreLeaveAttackRange IgnoreLeaveAttackRange()
IgnoreResistance IgnoreResistance(Bludgeoning, Resistant)
IncreaseMaxHP - IncreaseMaxHP(10%);
Initiative Initiative(-15)
Invulnerable Invulnerable()
JumpMaxDistanceMultiplier JumpMaxDistanceMultiplier(0.25)
MovementSpeedLimit MovementSpeedLimit(Stroll)
ObjectSize ObjectSize(-1)
Proficiency Proficiency(MusicalInstrument)
ProjectileDeflect ProjectileDeflect()
RedirectDamage RedirectDamage(1)
ReduceCriticalAttackThreshold ReduceCriticalAttackThreshold(1)
Reroll Reroll(Damage, 9, true)
Resistance Resistance(All, Resistant); Resistance(Cold, Immune)
RollBonus - RollBonus(SkillCheck,1d6);RollBonus(RawAbility,1d6);RollBonus(Attack,Owner.SpellCastingAbilityModifier)
ScaleMultiplier ScaleMultiplier(0.67)
SightRangeOverride SightRangeOverride(0)
SourceAdvantageOnAttack SourceAdvantageOnAttack()
SpellSaveDC SpellSaveDC(2)
StatusImmunity StatusImmunity(BANISHED)
Tag Tag(ACT2_SHADOW_CURSE_IMMUNE)
TemporaryHP TemporaryHP(ConstitutionModifier);TemporaryHP(10)
WeaponEnchantment WeaponEnchantment(1)
WeaponProperty WeaponProperty(Unstowable)
WeightCategory WeightCategory(-1)
===============
When it comes to these boosts we'll probably need an array of rudimentary conditions.
I'll list below:
Can probably just use the following instead of all those pre-made functions, let us pick and choose:
context.HitDescription.AttackType == AttackType.MeleeWeaponAttack
context.HitDescription.AttackType == AttackType.MeleeOffHandWeaponAttack
context.HitDescription.AttackType == AttackType.RangedWeaponAttack
context.HitDescription.AttackType == AttackType.RangedOffHandWeaponAttack
context.HitDescription.AttackType == AttackType.MeleeUnarmedAttack
context.HitDescription.AttackType == AttackType.RangedUnarmedAttack
context.HitDescription.AttackType == AttackType.MeleeSpellAttack
context.HitDescription.AttackType == AttackType.RangedSpellAttack

No offhand specification for unarmed, interesting
IsWeaponAttack Melee and ranged, no throwing
IsMainHandAttack Main hand + throwing
IsMainHandWeaponAttack Just main hand
IsOffHandAttack
IsMeleeWeaponAttack
IsRangedWeaponAttack
IsUnarmedAttack + throwing
IsMeleeUnarmedAttack no throwing
IsSpellAttack
IsMeleeSpellAttack
IsRangedSpellAttack

AttackingWithMeleeWeapon & AttackingWithRangedWeapon (with a context.Source declaration) - GetAttackWeapon / HasWeaponProperty
Don't know if there's a spell equivalent, but these are specifically for Reroll, as it can't be determined prior to the actual attack like say with Advantage
IsProficientWith(context.Source, GetAttackWeapon(context.Source)
HasAdvantage
HasDisadvantage
InMeleeRange
IsSneakingOrInvisible - HasStatus checks would be great yeah

======
BOOSTS HANDLED THROUGH FREEFORM
AbilityOverrideMinimum AbilityOverrideMinimum(Strength,23);
ActionResource ActionResource(SpellSlot,4,1);
ActiveCharacterLight ActiveCharacterLight(c46e7ba8-e746-7020-5146-287474d7b9f7)
AiArchetypeOverride AiArchetypeOverride(mage,1);
AttackSpellOverride AttackSpellOverride(Target_MainHandAttack_Sahuagin, Target_MainHandAttack);
Attribute Attribute(ObscurityWithoutSneaking)
CannotHarmCauseEntity CannotHarmCauseEntity(CannotHarmSanctuary)
CriticalHit CriticalHit(AttackRoll,Success,Always,18);
Detach N/A
DownedStatus DownedStatus(DOWNED); DownedStatus(STEEL_WATCHER_INVULNERABILITY,-1)
GameplayLight GameplayLight(6,false,0.1)
Immunity - N/A
Lootable N/A
MinimumRollResult MinimumRollResult(Damage,20)
MonkWeaponDamageDiceOverride MonkWeaponDamageDiceOverride(LevelMapValue(SpiritualWeapon_2d8))
Skill Skill(Intimidation, 2)
ProficiencyBonus ProficiencyBonus(Skill,Arcana)
ProficiencyBonusOverride ProficiencyBonusOverride(Owner.LevelMapValue(StandardProficiencyBonusScale))
UnlockInterrupt UnlockInterrupt(Interrupt_LegendaryResistance)
UnlockSpell UnlockSpell(Projectile_ChromaticOrb,,d136c5d9-0ff0-43da-acce-a74a07f8d6bf,,);
UnlockSpellVariant "UnlockSpellVariant(MindSanctuaryCheck(),ModifyTooltipDescription());
VoicebarkBlock N/A
====
]]
