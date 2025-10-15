---@class BoostsMutatorClass : MutatorInterface
BoostsMutator = MutatorInterface:new("Boosts")
BoostsMutator.affectedComponents = {
	"BoostsContainer"
}

function BoostsMutator:priority()
	return 99
end

function BoostsMutator:Transient()
	return false
end

function BoostsMutator:canBeAdditive()
	return true
end

function BoostsMutator:handleDependencies(export, mutator, removeMissingDependencies)
end

---@class BoostTable
---@field name string
---@field definition table

---@class BoostsMutator : Mutator
---@field values BoostTable[]
---@field customBoosts string

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

	for i, boostTable in TableUtils:OrderedPairs(mutator.values) do
		local boostDisplayRow = boostDisplayTable:AddRow()

		local actionCell = boostDisplayRow:AddCell()
		local deleteButton = Styler:ImageButton(actionCell:AddImageButton("delete" .. i, "ico_red_x", { 16, 16 }))
		deleteButton.OnClick = function()
			mutator.values[i].delete = true
			TableUtils:ReindexNumericTable(mutator.values)
			self:renderMutator(parent, mutator)
		end

		if i > 1 then
			local upArrow = Styler:ImageButton(actionCell:AddImageButton("moveup", "scroll_up_d", Styler:ScaleFactor({ 16, 16 })))
			upArrow.SameLine = true
			upArrow.OnClick = function()
				local boost = TableUtils:DeeplyCopyTable(boostTable._real)
				mutator.values[i].delete = true
				mutator.values[i] = TableUtils:DeeplyCopyTable(mutator.values[i - 1]._real)
				mutator.values[i - 1].delete = true
				mutator.values[i - 1] = boost
				self:renderMutator(parent, mutator)
			end
		end
		if i < #(mutator.values._real or mutator.values) then
			local downArrow = Styler:ImageButton(actionCell:AddImageButton("movedown", "scroll_down_d", Styler:ScaleFactor({ 16, 16 })))
			downArrow.SameLine = true
			downArrow.OnClick = function()
				local boost = TableUtils:DeeplyCopyTable(boostTable._real)
				mutator.values[i].delete = true
				mutator.values[i] = TableUtils:DeeplyCopyTable(mutator.values[i + 1]._real)
				mutator.values[i + 1].delete = true
				mutator.values[i + 1] = boost
				self:renderMutator(parent, mutator)
			end
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
				elseif boostDefType:lower() == "number" then
					boostTable.definition[d] = boostTable.definition[d] or 0

					local numberInput = cell:AddInputInt("", boostTable.definition[d])
					numberInput.ItemWidth = 80
					numberInput.OnChange = function()
						boostTable.definition[d] = numberInput.Value[1]
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

	parent:AddText("Add Custom Boosts (?):"):Tooltip():AddText(
		"\t You can arbitrarily add new lines and tab spacing - they'll be joined together later. Anything you can add to the Boost field in a stat, you can add here.")
	local boostsInput = parent:AddInputText("")
	boostsInput.Multiline = true
	boostsInput.AllowTabInput = true
	boostsInput.Text = mutator.customBoosts or ""
	boostsInput.OnChange = function()
		mutator.customBoosts = boostsInput.Text
	end

	parent:AddSeparatorText("OUTPUT")

	local refreshButton = parent:AddButton("Refresh Output")

	parent:AddText("Raw Stat Output - Validate at:")
	local validate = parent:AddInputText("")
	validate.Text = "https://bg3.norbyte.dev/stats-validator"
	validate.ReadOnly = true
	validate.AutoSelectAll = true
	validate.SameLine = true
	validate.ItemWidth = 400 * Styler:ScaleFactor()

	local rawOutput = parent:AddInputText("")
	rawOutput.Multiline = true
	rawOutput.ReadOnly = true
	rawOutput.AutoSelectAll = true

	parent:AddText("Prettified Boosts:")
	local pretty = parent:AddChildWindow("Prettified")
	pretty.Size = Styler:ScaleFactor({ 0, 400 })

	local function updateBoostOutput()
		local boostString, boostTable = self:buildBoost(mutator)

		rawOutput.Text = ([[
new entry "ABSOLUTES_LAB_BOOSTS_BOOST"
type "StatusData"
data "StatusType" "BOOST"
data "DisplayName" "he352e38cfac146a5a64e718bec47eea14f59;1"
data "StackId" "ABSOLUTES_LAB_BOOSTS_BOOST"
data "StatusPropertyFlags" "DisableOverhead;DisableCombatlog;DisablePortraitIndicator"
data "Boosts" "%s"]]):format(boostString)

		Helpers:KillChildren(pretty)
		for _, boost in ipairs(boostTable) do
			FunctorsProxy:parseHyperlinks(pretty, boost)
		end
	end
	updateBoostOutput()

	refreshButton.OnClick = updateBoostOutput
end

---@param mutator BoostsMutator
---@return string Boost
---@return string[] boosts
function BoostsMutator:buildBoost(mutator)
	local boostString = ""
	local boostsEntries = {}

	for _, boostTable in TableUtils:OrderedPairs(mutator.values, function(key, value)
		return value.name
	end, function(key, value)
		return value.name ~= nil
	end) do
		boostTable = TableUtils:DeeplyCopyTable(boostTable.__real or boostTable)

		local rawString = ""
		rawString = boostTable.name .. "("

		for i, param in ipairs(boostTable.definition) do
			if type(param) == "table" then
				param = ("%sd%s"):format(param["diceNum"], param["diceSize"])
			end
			rawString = rawString .. (i > 1 and "," or "") .. tostring(param)
		end

		rawString = rawString .. ");"

		table.insert(boostsEntries, rawString)
		boostString = boostString .. rawString
	end

	if mutator.customBoosts and mutator.customBoosts ~= "" then
		local cleanedBoosts = mutator.customBoosts:gsub("\n", ""):gsub("\t", "")
		boostString = boostString .. cleanedBoosts

		for boost in cleanedBoosts:gmatch("([^;]+)") do
			if boost ~= "" then
				table.insert(boostsEntries, boost .. ";")
			end
		end
	end

	return boostString, boostsEntries
end

function BoostsMutator:applyMutator(entity, entityVar)
	local boostsMutators = entityVar.appliedMutators[self.name]
	if not boostsMutators[1] then
		boostsMutators = { boostsMutators }
	end
	---@cast boostsMutators BoostsMutator[]

	local boostString = ""
	local boostTables = {}
	for _, boostMutator in ipairs(boostsMutators) do
		local bs, bt = self:buildBoost(boostMutator)
		boostString = boostString .. bs
		table.insert(boostTables, bt)
	end

	if boostString ~= "" then
		Logger:BasicDebug("Adding the following boosts: %s", boostTables)

		local statName = "ABSOLUTES_LAB_BOOSTS_BOOST_" .. string.sub(entity.Uuid.EntityUuid, #entity.Uuid.EntityUuid - 11)
		if not Ext.Stats.Get(statName) then
			Logger:BasicDebug("Creating Boost Stat %s", statName)
			---@type StatusData
			local newStat = Ext.Stats.Create(statName, "StatusData", "ABSOLUTES_LAB_BOOSTS_BOOST")
			newStat.Boosts = boostString
			newStat:Sync()
		else
			Logger:BasicDebug("Updating Boost Stat %s", statName)
			---@type StatusData
			local stat = Ext.Stats.Get(statName)
			if stat.Boosts ~= boostString then
				stat.Boosts = boostString
				stat:Sync()
			end
		end

		entityVar.originalValues[self.name] = boostString
		Osi.ApplyStatus(entity.Uuid.EntityUuid, statName, -1, 1, "Lab")
	else
		Logger:BasicError("Boost string is empty despite boosts mutator being configured?")
	end
end

function BoostsMutator:undoMutator(entity, entityVar, primedEntityVar, reprocessTransient)
	if not primedEntityVar or not primedEntityVar.appliedMutators[self.name] then
		local statName = "ABSOLUTES_LAB_BOOSTS_BOOST_" .. string.sub(entity.Uuid.EntityUuid, #entity.Uuid.EntityUuid - 11)
		if not Ext.Stats.Get(statName) then
			Logger:BasicDebug("Creating Boost Stat %s for proper removal", statName)
			---@type StatusData
			local newStat = Ext.Stats.Create(statName, "StatusData", "ABSOLUTES_LAB_BOOSTS_BOOST")
			newStat.Boosts = entityVar.originalValues[self.name] or ""
			newStat:Sync()
		end

		Logger:BasicDebug("Removed status %s as no boosts mutator will be executed for this entity", statName)
		Osi.RemoveStatus(entity.Uuid.EntityUuid, statName)
	else
		Logger:BasicDebug("Skipping undoing as there is a boosts mutator primed for this entity")
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
		"StatsStatusGroup"
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
IncreaseMaxHP - IncreaseMaxHP(10%);
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

---@return MazzleDocsDocumentation
function BoostsMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Boosts",
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "",
					prefix_color = "Yellow",
					text = [[
Dependency On: None, but priority is set to run last
Transient: No, unless the game is restarted
Composable: Yes - Boosts will be merged together into one pool, allowing duplicate boosts of the same type to persist]]
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
					text = [[This mutator allows you the most amount of freedom to mutate the selected entities; anything you can do in a boost, you can do here.]]
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
There are three main components to this mutator:
At the top are the Boost Builders, which provide a convenient WYSIWIG builder for the simpler but cumbersome Boosts. Boosts that were considered but ultimately excluded are listed at the bottom of the page.

Next is the Custom Boosts section - this is a freeform text box that allows you to specify as many boosts as you want, in any format - Lab will automatically handle spacing, newlines, and semi-colons for you where required.

Last up is purely a display section - it gives you a sample of the Raw Boost status that will be applied so you can validate your work in the NorbDev validator; it'll also render your boosts using Lab's Functor Parser, providing the same behavior available in the Inspector.

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
					text =
					[[Much like the Action Resource Mutator, this mutator constructs a unique status for each entity it applies to, in the form of `ABSOLUTES_LAB_BOOSTS_BOOST_{last 12 characters of the entity's UUID}`
This allows all boosts to persist through reloads, preventing any refreshing of values affected - this behavior will _not_ be prevented if the game is restarted however, as the created status isn't backed by a file and can't be created until a save is loaded into.
This only matters when a player saves mid-combat and restarts the game, so it should very rarely impact their experience.]]
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
						"TODO"
					}
				} --[[@as MazzleDoctsBullet]],
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Short List of Possible Boosts for use in the Custom Boosts section"
				},
				{
					type = "Code",
					text =
					[[See the master list of boosts and their parameters at https://github.com/Norbyte/lslib/blob/master/LSLibDefinitions.xml#L653
====================================
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
IncreaseMaxHP - IncreaseMaxHP(10%);
Lootable N/A
MinimumRollResult MinimumRollResult(Damage,20)
MonkWeaponDamageDiceOverride MonkWeaponDamageDiceOverride(LevelMapValue(SpiritualWeapon_2d8))
Skill Skill(Intimidation, 2)
ProficiencyBonus ProficiencyBonus(Skill,Arcana)
ProficiencyBonusOverride ProficiencyBonusOverride(Owner.LevelMapValue(StandardProficiencyBonusScale))
UnlockInterrupt UnlockInterrupt(Interrupt_LegendaryResistance)
UnlockSpell UnlockSpell(Projectile_ChromaticOrb,,d136c5d9-0ff0-43da-acce-a74a07f8d6bf,,);
UnlockSpellVariant "UnlockSpellVariant(MindSanctuaryCheck(),ModifyTooltipDescription());
VoicebarkBlock N/A]]
				}
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function BoostsMutator:generateChangelog()
	return {
		["1.6.0"] = {
			type = "Bullet",
			text = {
				"Adds up/down arrows to allow sorting the Boosts in the Builder section",
				"Cleans up logic around semicolons for the pretty output"
			}
		} --[[@as MazzleDocsContentItem]]
	}
end
