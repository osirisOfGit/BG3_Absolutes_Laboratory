-- Map class progression passives to their respective level boosts tables
local LevelBoostTables = {
    ["Goon_Barbarian_NPC_Progressions"] = BarbarianLevelBoosts,
    ["Goon_Bard_NPC_Progressions"] = BardLevelBoosts,
    ["Goon_Cleric_NPC_Progressions"] = ClericLevelBoosts,
    ["Goon_Druid_NPC_Progressions"] = DruidLevelBoosts,
    ["Goon_Fighter_NPC_Progressions"] = FighterLevelBoosts,
    ["Goon_Monk_NPC_Progressions"] = MonkLevelBoosts,
    ["Goon_Paladin_NPC_Progressions"] = PaladinLevelBoosts,
    ["Goon_Ranger_NPC_Progressions"] = RangerLevelBoosts,
    ["Goon_Rogue_NPC_Progressions"] = RogueLevelBoosts,
    ["Goon_Sorcerer_NPC_Progressions"] = SorcererLevelBoosts,
    ["Goon_Warlock_NPC_Progressions"] = WarlockLevelBoosts,
    ["Goon_Wizard_NPC_Progressions"] = WizardLevelBoosts
}

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level_name, is_editor_mode)
    print("== LevelGameplayStarted Triggered ==")

    if not LevelBoostTables then
        print("Error: LevelBoostTables is nil!")
        return
    end

    local entityCount = 0
    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local charID = entity.Uuid and entity.Uuid.EntityUuid or entity
        print("[DEBUG] Entity:", entity, "CharID:", charID)

        if type(charID) == "string" then
            entityCount = entityCount + 1
            print("[CHARACTER] Valid CharID:", charID)

            for classPassive, classFunction in pairs(LevelBoostTables) do
                if HasPassive(charID, classPassive) then
                    print("[CLASS MATCH] Found class passive:", classPassive, "for CharID:", charID)

                    -- Ensure PersistentVars entry exists
                    Mods[ModTable].PersistentVars[charID] = Mods[ModTable].PersistentVars[charID] or {}
                    local charVars = Mods[ModTable].PersistentVars[charID]

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
                else
                    print("[NO MATCH] CharID:", charID, "does not have passive:", classPassive)
                end
            end
        else
            print("[WARNING] Invalid CharID or entity skipped.")
        end
    end

    print("[DEBUG] Total entities processed:", entityCount)
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