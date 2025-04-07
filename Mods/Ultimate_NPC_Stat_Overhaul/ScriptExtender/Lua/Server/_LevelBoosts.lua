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

-- Helper to count entries in a table
local function TableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level_name, is_editor_mode)
    print("== LevelGameplayStarted Triggered ==")

    if not LevelBoostTables then
        print("[ERROR] LevelBoostTables is nil!")
        return
    end

    -- 1. Print how many entries are in LevelBoostTables
    local boostCount = 0
    for _ in pairs(LevelBoostTables) do
        boostCount = boostCount + 1
    end
    print("[DEBUG] LevelBoostTables entries:", boostCount)

    local entityCount = 0
    local matchedCount = 0

    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local charID = entity.Uuid and entity.Uuid.EntityUuid or entity
        print("[DEBUG] Entity:", entity, "CharID:", charID)

        if type(charID) == "string" then
            entityCount = entityCount + 1
            print("[CHARACTER] Valid CharID:", charID)

            for classPassive, classFunction in pairs(LevelBoostTables) do
                if HasPassive(charID, classPassive) then
                    matchedCount = matchedCount + 1
                    print("[CLASS MATCH] Found class passive:", classPassive, "for CharID:", charID)

                    -- Ensure PersistentVars entry exists
                    Mods[ModTable].PersistentVars[charID] = Mods[ModTable].PersistentVars[charID] or {}
                    local charVars = Mods[ModTable].PersistentVars[charID]

                    -- 2. Show what PersistentVars looked like before applying
                    print("[PERSISTENT VARS - BEFORE]", Ext.JsonStringify(charVars))

                    -- Apply boosts if needed
                    if not charVars.boostsApplied then
                        print("[BOOSTS] Applying boosts for CharID:", charID)
                        classFunction(charID)
                        charVars.boostsApplied = true
                    else
                        print("[BOOSTS] Boosts already applied for CharID:", charID)
                    end

                    -- Apply level-based boosts
                    print("[LEVEL BOOSTS] Applying level-based boosts...")
                    ApplyLevelBasedBoosts(charID)

                    -- Apply persistent passives
                    print("[PERSISTENT PASSIVES] Applying stored passives from PersistentVars...")
                    ApplyPersistantVars(charID)

                    -- 3. Show what PersistentVars looks like after
                    print("[PERSISTENT VARS - AFTER]", Ext.JsonStringify(Mods[ModTable].PersistentVars[charID]))
                else
                    print("[NO MATCH] CharID:", charID, "does not have passive:", classPassive)
                end
            end
        else
            print("[WARNING] Invalid CharID or entity skipped.")
        end
    end

    print("[DEBUG] Total entities processed:", entityCount)
    print("[DEBUG] Total characters with matched class passives:", matchedCount)
    print("== LevelGameplayStarted Complete ==")
end)

local function ApplyLevelBasedBoosts(character)
    for classPassive, levelBoostTable in pairs(LevelBoostTables) do
        if HasPassive(character, classPassive) then
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
    end
end

-- Debug print to confirm initialization
print("[DEBUG] LevelBoostTables initialized:", Mods[ModTable].LevelBoostTables)