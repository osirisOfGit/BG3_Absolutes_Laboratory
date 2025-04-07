Mods[ModTable].RouletteSubclasses = function(character, class, level)
    -- Check if the class exists in the SubclassTables
    if SubclassTables[class] then
        Mods[ModTable].subclassTable = SubclassTables[class]

        -- Check if the character already has any of the subclass passives
        for _, passive in ipairs(subclassTable) do
            if HasPassive(character, passive) then
                return -- Exit if any passive is already applied
            end
        end

        -- Randomly select a subclass passive from the table
        Mods[ModTable].selectedPassive = subclassTable[math.random(#subclassTable)]
        -- Add the selected passive to the character
        Osi.AddPassive(character, selectedPassive)
    end
end

-- Map all subclass tables to their respective classes
Mods[ModTable].SubclassTables = {
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

Mods[ModTable].BarbarianSubclassTable = {
    "CX_Barbarian_WildMagic_Boost",
    "CX_Barbarian_Berserker_Boost",
    "CX_Barbarian_TotemWarriorPath_Boost"
}

Mods[ModTable].BardSubclassTable = {
    -- "CX_Bard_CollegeOfLore_Boost",
    -- "CX_Bard_CollegeOfValor_Boost",
    -- "CX_Bard_CollegeOfSwords_Boost",
    -- "CX_Bard_CollegeOfWhispers_Boost"
}

Mods[ModTable].ClericSubclassTable = {
    -- "CX_Cleric_LifeDomain_Boost",
    -- "CX_Cleric_LightDomain_Boost",
    -- "CX_Cleric_ForgeDomain_Boost",
    -- "CX_Cleric_TempestDomain_Boost",
    -- "CX_Cleric_KnowledgeDomain_Boost",
    -- "CX_Cleric_WarDomain_Boost",
    -- "CX_Cleric_TrickeryDomain_Boost",
    -- "CX_Cleric_CreationDomain_Boost"
}

Mods[ModTable].DruidSubclassTable = {
    "CX_Druid_CircleOfTheLand_Boost",
    "CX_Druid_CircleOfTheMoon_Boost",
    "CX_Druid_CircleOfSpores_Boost",
    "CX_Druid_CircleOfTheShepherd_Boost"
}

Mods[ModTable].FighterSubclassTable = {
    "CX_Fighter_BattleMaster_Boost",
    "CX_Fighter_EldritchKnight_Boost"
}

Mods[ModTable].MonkSubclassTable = {
    "CX_Monk_OpenHand_Boost",
    "CX_Monk_FourElements_Boost"

}

Mods[ModTable].PaladinSubclassTable = {
    "CX_Paladin_Devotion_Boost",
    "CX_Paladin_Vengeance_Boost",
    "CX_Paladin_Oathbreaker_Boost"
}

Mods[ModTable].RangerSubclassTable = {
    "CX_Ranger_Hunter_Boost",
    "CX_Ranger_BeastMaster_Boost"
    -- "CX_Ranger_GloomStalker_Boost",
    -- "CX_Ranger_Swarmkeeper_Boost"
}

Mods[ModTable].RogueSubclassTable = {
    -- "CX_Rogue_Thief_Boost",
    -- "CX_Rogue_Assassin_Boost",
    -- "CX_Rogue_ArcaneTrickster_Boost",
    -- "CX_Rogue_Scout_Boost"
}

Mods[ModTable].SorcererSubclassTable = {
    -- "CX_Sorcerer_StormSorcery_Boost",
    -- "CX_Sorcerer_DraconicBloodline_Boost",
    -- "CX_Sorcerer_WildMagic_Boost",
    -- "CX_Sorcerer_ShadowMagic_Boost"
}

Mods[ModTable].WarlockSubclassTable = {
    -- "CX_Warlock_TheArchfey_Boost",
    -- "CX_Warlock_TheFiend_Boost",
    -- "CX_Warlock_TheGreatOldOne_Boost",
    -- "CX_Warlock_TheHexblade_Boost",
    -- "CX_Warlock_TheUndying_Boost"
}

Mods[ModTable].WizardSubclassTable = {
    -- "CX_Wizard_Abjuration_Boost",
    -- "CX_Wizard_Conjuration_Boost",
    -- "CX_Wizard_Divination_Boost",
    -- "CX_Wizard_Enchantment_Boost",
    "CX_Wizard_Evocation_Boost",
    -- "CX_Wizard_Illusion_Boost",
    "CX_Wizard_Necromancy_Boost"
    -- "CX_Wizard_Transmutation_Boost"
}
