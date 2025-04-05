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

-- Holy moly scan the whole population of the world like Mark Zuckerberg and the lizard empire.
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level_name, is_editor_mode)
    print("== LevelGameplayStarted Triggered ==")
    if not LevelBoostTables then
        print("Error: LevelBoostTables is nil!")
        return
    end

    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local charID = entity.Uuid and entity.Uuid.EntityUuid or entity
        if type(charID) == "string" then
            print("[CHARACTER] Checking:", charID)

            for classPassive, classFunction in pairs(LevelBoostTables) do
                if HasPassive(charID, classPassive) then
                    print("  [CLASS MATCH] Found class passive:", classPassive)

                    -- Ensure PersistentVars entry exists
                    Mods[ModTable].PersistentVars[charID] = Mods[ModTable].PersistentVars[charID] or {}
                    local charVars = Mods[ModTable].PersistentVars[charID]

                    if next(charVars) == nil then
                        print("  [ROULETTE] No PersistentVars found. Running class function (roulette)...")
                        classFunction(charID)
                    else
                        print("  [SKIP ROULETTE] PersistentVars already exist. Skipping class function.")
                    end

                    print("  [LEVEL BOOSTS] Applying level-based boosts...")
                    ApplyLevelBasedBoosts(charID)

                    print("  [PERSISTENT PASSIVES] Applying stored passives from PersistentVars...")
                    ApplyPersistantVars(charID)
                end
            end
        end
    end

    print("== LevelGameplayStarted Complete ==")
end)


local function ApplyLevelBasedBoosts(character)
    -- Iterate through the LevelBoostTables to find the matching class progression passive
    for classPassive, levelBoostTable in pairs(LevelBoostTables) do
        if HasPassive(character, classPassive) then
            local level = Osi.GetLevel(character) -- Get the character's level
            for i = 1, level do
                if levelBoostTable[i] then
                    levelBoostTable[i](character) -- Apply the level boost
                end
            end
            -- break -- Exit the loop once the correct class is found (nah)
        end
    end
end