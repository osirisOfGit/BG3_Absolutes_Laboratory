CharacterProxy = StatProxy:new()
CharacterProxy.statsToParse = {
	["Resistances"] = {
		"AcidResistance",
		"BludgeoningResistance",
		"ColdResistance",
		"FireResistance",
		"ForceResistance",
		"LightningResistance",
		"NecroticResistance",
		"PiercingResistance",
		"PoisonResistance",
		"PsychicResistance",
		"RadiantResistance",
		"SlashingResistance",
		"ThunderResistance",
	},
	["Abilities"] = {
		"Strength",
		"Dexterity",
		"Constitution",
		"Intelligence",
		"Wisdom",
		"Charisma",
	},
	"ActionResources",
	"Armor",
	"ArmorType",
	"Class",
	"DarkvisionRange",
	"DefaultBoosts",
	"DifficultyStatuses",
	"ExtraProperties",
	"Flags",
	"FOV",
	"GameSize",
	"Hearing",
	"Initiative",
	"Level",
	"MinimumDetectionRange",
	"Passives",
	"PersonalStatusImmunities",
	"ProficiencyBonusScaling",
	"ProficiencyBonus",
	"Progressions",
	"Sight",
	"SpellCastingAbility",
	"UnarmedAttackAbility",
	"UnarmedRangedAttackAbility",
	"VerticalFOV",
	"Vitality",
	"Weight",
	"XPReward",
}


StatProxy:RegisterStatType("Character", CharacterProxy)

function CharacterProxy:buildHyperlinkedStrings(parent, statString, _)
	if statString and statString ~= "" then
		for statGroup in self:SplitSpring(statString) do
			-- Accounting for `STATUS_EASY: HEALTHREDUCTION_EASYMODE;` type stats
			for stat in string.gmatch(statString, "([^:]+)") do

			end
		end
	end
end
