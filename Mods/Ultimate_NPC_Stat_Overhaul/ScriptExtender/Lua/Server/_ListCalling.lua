-- SelectRandomPassivesFromUUID(char, "some-uuid-for-passives", "PassivesTag", 2)
-- SelectRandomSkillsFromUUID(char, "some-uuid-for-skills", "SkillTag", 2)
-- SelectRandomSpellsFromUUID(char, "some-uuid-for-spells", "SpellTag", 3)
-- SelectRandomAbilitiesFromUUID(char, "some-uuid-for-abilities", "AbilityTag", 1)

local ModTable = "Ultimate_NPC_Stat_Overhaul"

Mods = Mods or {}
Mods[ModTable] = Mods[ModTable] or {}


-- ==================================== 🎲 Data Table ====================================

Mods[ModTable].RouletteData = {
    Passives = {
        ["UUID_EXAMPLE_PASSIVES"] = {
            "GOON_PASSIVE_WILD", "GOON_PASSIVE_BRAVE", "GOON_PASSIVE_SHADOWSTEP"
        }
    },
    Skills = {
        ["UUID_EXAMPLE_SKILLS"] = {
            "Skill_Stealth", "Skill_Perception", "Skill_Arcana"
        }
    },
    Spells = {
        ["UUID_EXAMPLE_SPELLS"] = {
            "Target_Firebolt", "Target_HealingWord", "Zone_FogCloud"
        }
    },
    Abilities = {
        ["UUID_EXAMPLE_ABILITIES"] = {
            "Ability_Strength", "Ability_Dexterity", "Ability_Charisma"
        }
    }
}

-- ==================================== 🔧 Utility Functions ====================================

local function GetRouletteList(category, uuid, tag)
    local data = Mods[ModTable].RouletteData and Mods[ModTable].RouletteData[category]
    if not data then
        print("[ROULETTE] No data for category:", category)
        return {}
    end

    local list = data[uuid]
    if not list then
        print("[ROULETTE] No list for UUID:", uuid, "in category:", category)
        return {}
    end

    if tag then
        local filtered = {}
        for _, entry in ipairs(list) do
            if entry:find(tag) then
                table.insert(filtered, entry)
            end
        end
        return filtered
    end

    return list
end

local function ShuffleList(inputList)
    local list = {}
    for _, item in ipairs(inputList) do
        table.insert(list, item)
    end
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function AddUniqueEntries(char, items, checkFn, addFn, label, amount)
    local selected = 0
    for _, entry in ipairs(items) do
        if not checkFn(char, entry) then
            addFn(char, entry)
            print("[ROULETTE]", label, "added:", entry, "->", char)
            selected = selected + 1
            if selected >= amount then break end
        end
    end
    if selected < amount then
        print("[ROULETTE] Only", selected, label, "added to", char, "- not enough unique entries")
    end
end

-- ==================================== 🌀 Roulette Functions ====================================

Mods[ModTable].RoulettePassives = function(character, uuid, tag, amount)
    local list = GetRouletteList("Passives", uuid, tag)
    if #list == 0 then return end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasPassive, Osi.AddPassive, "Passive", amount)
end

Mods[ModTable].RouletteSkills = function(character, uuid, tag, amount)
    local list = GetRouletteList("Skills", uuid, tag)
    if #list == 0 then return end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasSkill, function(char, skill) Osi.AddSkill(char, skill, 1) end, "Skill", amount)
end

Mods[ModTable].RouletteSpells = function(character, uuid, tag, amount)
    local list = GetRouletteList("Spells", uuid, tag)
    if #list == 0 then return end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasSpell, Osi.AddSpell, "Spell", amount)
end

Mods[ModTable].RouletteAbilities = function(character, uuid, tag, amount)
    local list = GetRouletteList("Abilities", uuid, tag)
    if #list == 0 then return end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasAbility, function(char, ab) Osi.AddAbility(char, ab, 1) end, "Ability", amount)
end

Mods[ModTable].RouletteFeats = function(class, level)
    local featTables = Mods[ModTable].FeatTables
    if featTables[class] and featTables[class][level] then
        local featList = featTables[class][level]
        local selectedFeat
        repeat
            selectedFeat = featList[math.random(#featList)]
        until not Mods[ModTable].selectedFeats[selectedFeat]  -- Ensure no duplicates
        Mods[ModTable].selectedFeats[selectedFeat] = true  -- Mark feat as selected
        return selectedFeat
    else
        print("[DEBUG] No feats found for class:", class, "level:", level)
    end
end