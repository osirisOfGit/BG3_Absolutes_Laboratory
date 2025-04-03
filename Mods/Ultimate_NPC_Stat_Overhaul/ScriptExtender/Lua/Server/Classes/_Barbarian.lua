local function ApplyLevelBasedPassives(character)
    local level = Osi.GetLevel(character) -- Get the character's level
    local levelToPassiveMap = {
        [1] = "Goon_Barbarian_NPC_Progressions_Level_1",
        [2] = "Goon_Barbarian_NPC_Progressions_Level_2",
        [3] = "Goon_Barbarian_NPC_Progressions_Level_3",
        [4] = "Goon_Barbarian_NPC_Progressions_Level_4",
        [5] = "Goon_Barbarian_NPC_Progressions_Level_5",
        [6] = "Goon_Barbarian_NPC_Progressions_Level_6",
        [7] = "Goon_Barbarian_NPC_Progressions_Level_7",
        [8] = "Goon_Barbarian_NPC_Progressions_Level_8",
        [9] = "Goon_Barbarian_NPC_Progressions_Level_9",
        [10] = "Goon_Barbarian_NPC_Progressions_Level_10",
        [11] = "Goon_Barbarian_NPC_Progressions_Level_11",
        [12] = "Goon_Barbarian_NPC_Progressions_Level_12",
        [13] = "Goon_Barbarian_NPC_Progressions_Level_13",
        [14] = "Goon_Barbarian_NPC_Progressions_Level_14",
        [15] = "Goon_Barbarian_NPC_Progressions_Level_15",
        [16] = "Goon_Barbarian_NPC_Progressions_Level_16",
        [17] = "Goon_Barbarian_NPC_Progressions_Level_17",
        [18] = "Goon_Barbarian_NPC_Progressions_Level_18",
        [19] = "Goon_Barbarian_NPC_Progressions_Level_19",
        [20] = "Goon_Barbarian_NPC_Progressions_Level_20"
    }

    -- Check if the level has a corresponding passive
    local passive = levelToPassiveMap[level]
    if passive then
        Osi.AddPassive(character, passive) -- Apply the passive
    end
end

local function BarbarianRoulette(character)
    Mods[ModTable].PersistentVars[character] = Mods[ModTable].PersistentVars[character] or {}
    local rolls = {}
    local selectedFeats = {} -- Table to track selected feats

    if HasPassive(character, "Goon_NPC_Roulette_Barbarian_Level_1_Selectors") then
        local spellList = "233793b3-838a-4d4e-9d68-1e0a1089aba5"
        local abilityBonus = "b9149c8e-52c8-46e5-9cb6-fc39301c05fe"
        table.insert(rolls, {type = "SpellList", value = spellList})
        table.insert(rolls, {type = "AbilityBonus", value = abilityBonus})
        
        if HasPassive(character, "Goon_NPC_Roulette_Barbarian_Level_3_Subclass") then
            local subclassPassives = {"CX_Barbarian_WildMagic_Boost", "CX_Barbarian_Berserker_Boost"}
            local selectedPassive = subclassPassives[math.random(#subclassPassives)]
            table.insert(rolls, {type = "SubclassPassive", value = selectedPassive})
        end
    end

    if HasPassive(character, "Goon_NPC_Roulette_Barbarian_Level_4_Feat") then
        local barbarianFeats = {
            "Feat_Barbarian_Fury",
            "Feat_Barbarian_Resilience",
            "Feat_Barbarian_Savagery"
        }
        local selectedFeat
        repeat
            selectedFeat = barbarianFeats[math.random(#barbarianFeats)]
        until not selectedFeats[selectedFeat] -- Ensure no duplicates
        selectedFeats[selectedFeat] = true -- Mark feat as selected
        table.insert(rolls, {type = "Feat", value = selectedFeat})
    end

    -- Add more checks for feats here if needed, ensuring no duplicates using `selectedFeats`.

    for _, roll in ipairs(rolls) do
        Mods[ModTable].PersistentVars[character][roll.type] = roll.value
    end
end

local function ApplyPersistentPassives(character)
    local storedRolls = Mods[ModTable].PersistentVars[character] or {} -- Default to an empty table if nil

    for _, roll in ipairs(storedRolls) do
        if roll.type == "SpellList" then
            Osi.SelectSkills(character, roll.value, 2)
        elseif roll.type == "AbilityBonus" then
            Osi.SelectAbilityBonus(character, roll.value, "AbilityBonus", 2, 1)
        elseif roll.type == "SubclassPassive" then
            Osi.AddPassive(character, roll.value)
        end
    end
end

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level_name, is_editor_mode)
    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local charID = entity.Uuid and entity.Uuid.EntityUuid or entity
        if type(charID) == "string" and HasPassive(charID, "Goon_Barbarian_NPC_Progressions") then
            if not Mods[ModTable].PersistentVars[charID] or next(Mods[ModTable].PersistentVars[charID]) == nil then
                BarbarianRoulette(charID)
            end
            ApplyPersistentPassives(charID)
        end
    end
end)