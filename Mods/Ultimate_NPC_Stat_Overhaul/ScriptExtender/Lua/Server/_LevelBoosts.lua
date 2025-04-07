-- Helper to count entries in a table
local function TableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Map class progression passives to their respective level boosts tables
Mods[ModTable].LevelBoostTables = {
    ["Goon_Barbarian_NPC_Progressions"] = Mods[ModTable].BarbarianLevelBoosts,
    ["Goon_Bard_NPC_Progressions"] = Mods[ModTable].BardLevelBoosts,
    ["Goon_Cleric_NPC_Progressions"] = Mods[ModTable].ClericLevelBoosts,
    ["Goon_Druid_NPC_Progressions"] = Mods[ModTable].DruidLevelBoosts,
    ["Goon_Fighter_NPC_Progressions"] = Mods[ModTable].FighterLevelBoosts,
    ["Goon_Monk_NPC_Progressions"] = Mods[ModTable].MonkLevelBoosts,
    ["Goon_Paladin_NPC_Progressions"] = Mods[ModTable].PaladinLevelBoosts,
    ["Goon_Ranger_NPC_Progressions"] = Mods[ModTable].RangerLevelBoosts,
    ["Goon_Rogue_NPC_Progressions"] = Mods[ModTable].RogueLevelBoosts,
    ["Goon_Sorcerer_NPC_Progressions"] = Mods[ModTable].SorcererLevelBoosts,
    ["Goon_Warlock_NPC_Progressions"] = Mods[ModTable].WarlockLevelBoosts,
    ["Goon_Wizard_NPC_Progressions"] = Mods[ModTable].WizardLevelBoosts
}

local function ApplyLevelBasedBoosts(character, classPassive, levelBoostTable)
    local level = Osi.GetLevel(character)
    print("[LEVEL BOOSTS] Applying boosts for CharID:", character, "ClassPassive:", classPassive, "Level:", level)

    for i = 1, level do
        if levelBoostTable[i] then
            print("[BOOST] Applying level", i, "boost for CharID:", character)
            levelBoostTable[i](character)
        else
            print("[NO BOOST] No boost defined for level", i, "for CharID:", character)
        end
    end
end

local function ApplyPersistentVars(character)
    local charVars = Mods[ModTable].PersistentVars[character]
    if not charVars then
        print("[DEBUG] No PersistentVars found for CharID:", character)
        return
    end

    print("[DEBUG] Applying PersistentVars for CharID:", character)

    if charVars.passives then
        for _, passive in ipairs(charVars.passives) do
            Osi.AddPassive(character, passive)
            print("[DEBUG] Applied passive:", passive, "to CharID:", character)
        end
    end

    if charVars.skills then
        for _, skill in ipairs(charVars.skills) do
            Osi.AddSkill(character, skill, 1)
            print("[DEBUG] Applied skill:", skill, "to CharID:", character)
        end
    end
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level_name, is_editor_mode)
    print("== LevelGameplayStarted Triggered ==")

    if not Mods[ModTable].LevelBoostTables then
        print("[ERROR] LevelBoostTables is nil!")
        return
    end

    local boostCount = TableLength(Mods[ModTable].LevelBoostTables)
    print("[DEBUG] LevelBoostTables entries:", boostCount)

    local entityCount = 0
    local matchedCount = 0

    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local charID = entity.Uuid and entity.Uuid.EntityUuid or entity
        print("[DEBUG] Entity:", entity, "CharID:", charID)

        if type(charID) == "string" then
            entityCount = entityCount + 1
            print("[CHARACTER] Valid CharID:", charID)

            local matched = false
            for classPassive, levelBoostTable in pairs(Mods[ModTable].LevelBoostTables) do
                print("[DEBUG] Checking passive:", classPassive, "for CharID:", charID)
                if HasPassive(charID, classPassive) then
                    matchedCount = matchedCount + 1
                    print("[CLASS MATCH] Found class passive:", classPassive, "for CharID:", charID)

                    -- Apply boosts and persistent vars
                    ApplyLevelBasedBoosts(charID, classPassive, levelBoostTable)
                    ApplyPersistentVars(charID)

                    matched = true
                else
                    print("[NO MATCH] CharID:", charID, "does not have passive:", classPassive)
                end
            end

            if not matched then
                print("[WARNING] No matching class passive found for CharID:", charID)
            end
        else
            print("[WARNING] Invalid CharID or entity skipped.")
        end
    end

    print("[DEBUG] Total entities processed:", entityCount)
    print("[DEBUG] Total characters with matched class passives:", matchedCount)
    print("== LevelGameplayStarted Complete ==")
end)

print("[DEBUG] LevelBoostTables initialized:", Mods[ModTable].LevelBoostTables)