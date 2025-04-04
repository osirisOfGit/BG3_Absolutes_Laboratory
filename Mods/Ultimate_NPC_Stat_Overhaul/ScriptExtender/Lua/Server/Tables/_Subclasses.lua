function SubclassSelection(character, class, level)
    if SubclassPassives[class] and SubclassPassives[class][level] then
        local passives = SubclassPassives[class][level]
        for _, passive in ipairs(passives) do
            -- Check if the character already has the passive
            if not HasPassive(character, passive) then
                -- Add the selected passive to the character
                Osi.AddPassive(character, passive)
            end
        end
    end
end

-- Map all subclass tables to their respective classes
local SubclassTables = {
    Barbarian = BarbarianSubclassTable,
    Bard = BardSubclassTable,
    Cleric = ClericSubclassTable,
    Druid = DruidSubclassTable,
    Fighter = FighterSubclassTable,
    Monk = MonkSubclassTable,
    Paladin = PaladinSubclassTable,
    Ranger = RangerSubclassTable,
    Rogue = RogueSubclassTable,
    Sorcerer = SorcererSubclassTable,
    Warlock = WarlockSubclassTable,
    Wizard = WizardSubclassTable
}

local BarbarianSubclassTable = {
    "CX_Barbarian_WildMagic_Boost",
    "CX_Barbarian_Berserker_Boost",
    -- "CX_Barbarian_TotemWarriorPath_Boost"
}

local BardSubclassTable = {
    -- "CX_Bard_CollegeOfLore_Boost",
    -- "CX_Bard_CollegeOfValor_Boost",
    -- "CX_Bard_CollegeOfSwords_Boost",
    -- "CX_Bard_CollegeOfWhispers_Boost"
}

local ClericSubclassTable = {
    -- "CX_Cleric_LifeDomain_Boost",
    -- "CX_Cleric_LightDomain_Boost",
    -- "CX_Cleric_ForgeDomain_Boost",
    -- "CX_Cleric_TempestDomain_Boost",
    -- "CX_Cleric_KnowledgeDomain_Boost",
    -- "CX_Cleric_WarDomain_Boost",
    -- "CX_Cleric_TrickeryDomain_Boost",
    -- "CX_Cleric_CreationDomain_Boost"
}

local DruidSubclassTable = {
    "CX_Druid_CircleOfTheLand_Boost",
    "CX_Druid_CircleOfTheMoon_Boost",
    "CX_Druid_CircleOfSpores_Boost",
    "CX_Druid_CircleOfTheShepherd_Boost"
}

local FighterSubclassTable = {
    "CX_Fighter_BattleMaster_Boost",
    "CX_Fighter_Champion_Boost",
    "CX_Fighter_EldritchKnight_Boost",
    "CX_Fighter_Gunslinger_Boost"
}

local MonkSubclassTable = {
    "CX_Monk_WayOfTheOpenHand_Boost",
    "CX_Monk_WayOfTheShadow_Boost",
    "CX_Monk_WayOfTheFourElements_Boost",
    "CX_Monk_WayOfTheDrunkenMaster_Boost"
}

local PaladinSubclassTable = {
    "CX_Paladin_OathOfDevotion_Boost",
    "CX_Paladin_OathOfTheAncients_Boost",
    "CX_Paladin_OathOfVengeance_Boost",
    "CX_Paladin_OathOfConquest_Boost",
    "CX_Paladin_OathOfGlory_Boost"
}

local RangerSubclassTable = {
    "CX_Ranger_Hunter_Boost",
    "CX_Ranger_BeastMaster_Boost",
    "CX_Ranger_GloomStalker_Boost",
    "CX_Ranger_Swarmkeeper_Boost"
}

local RogueSubclassTable = {
    "CX_Rogue_Thief_Boost",
    "CX_Rogue_Assassin_Boost",
    "CX_Rogue_ArcaneTrickster_Boost",
    "CX_Rogue_Scout_Boost"
}

local SorcererSubclassTable = {
    "CX_Sorcerer_StormSorcery_Boost",
    "CX_Sorcerer_DraconicBloodline_Boost",
    "CX_Sorcerer_WildMagic_Boost",
    "CX_Sorcerer_ShadowMagic_Boost"
}

local WarlockSubclassTable = {
    "CX_Warlock_TheArchfey_Boost",
    "CX_Warlock_TheFiend_Boost",
    "CX_Warlock_TheGreatOldOne_Boost",
    "CX_Warlock_TheHexblade_Boost",
    "CX_Warlock_TheUndying_Boost"
}

local WizardSubclassTable = {
    "CX_Wizard_Abjuration_Boost",
    "CX_Wizard_Conjuration_Boost",
    "CX_Wizard_Divination_Boost",
    "CX_Wizard_Enchantment_Boost",
    "CX_Wizard_Evocation_Boost",
    "CX_Wizard_Illusion_Boost",
    "CX_Wizard_Necromancy_Boost",
    "CX_Wizard_Transmutation_Boost"
}
