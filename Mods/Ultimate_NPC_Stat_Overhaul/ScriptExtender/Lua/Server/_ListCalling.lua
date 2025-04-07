-- SelectRandomPassivesFromUUID(char, "some-uuid-for-passives", "PassivesTag", 2)
-- SelectRandomSkillsFromUUID(char, "some-uuid-for-skills", "SkillTag", 2)
-- SelectRandomSpellsFromUUID(char, "some-uuid-for-spells", "SpellTag", 3)
-- SelectRandomAbilitiesFromUUID(char, "some-uuid-for-abilities", "AbilityTag", 1)

-- Debug print helper
local function DebugPrintList(label, list)
    print("[DEBUG] " .. label .. ":")
    for i, item in ipairs(list) do
        print("  [" .. i .. "] " .. tostring(item))
    end
end

-- ==================================== 🔧 Utility Functions ====================================

local function GetRouletteList(category, uuid, tag)
    print("[DEBUG] Fetching Roulette List for Category:", category, "UUID:", uuid, "Tag:", tag)
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
        DebugPrintList("Filtered List", filtered)
        return filtered
    end

    DebugPrintList("Full List", list)
    return list
end

local function ShuffleList(inputList)
    print("[DEBUG] Shuffling List...")
    local list = {}
    for _, item in ipairs(inputList) do
        table.insert(list, item)
    end
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    DebugPrintList("Shuffled List", list)
    return list
end

local function AddUniqueEntries(char, items, checkFn, addFn, label, amount)
    print("[DEBUG] Adding Unique Entries for:", label, "Character:", char, "Amount:", amount)
    local selected = 0
    for _, entry in ipairs(items) do
        print("[DEBUG] Checking entry:", entry)
        if not checkFn(char, entry) then
            print("[DEBUG] Entry not found on character. Adding:", entry)
            addFn(char, entry)
            print("[ROULETTE]", label, "added:", entry, "->", char)
            selected = selected + 1
            if selected >= amount then break end
        else
            print("[DEBUG] Entry already exists on character. Skipping:", entry)
        end
    end
    if selected < amount then
        print("[ROULETTE] Only", selected, label, "added to", char, "- not enough unique entries")
    end
end

-- ==================================== 🌀 Roulette Functions ====================================

Mods[ModTable].RoulettePassives = function(character, uuid, tag, amount)
    print("[DEBUG] RoulettePassives called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)
    local list = GetRouletteList("Passives", uuid, tag)
    if #list == 0 then
        print("[ROULETTE] No passives available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasPassive, Osi.AddPassive, "Passive", amount)
end

Mods[ModTable].RouletteSkills = function(character, uuid, tag, amount)
    print("[DEBUG] RouletteSkills called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)
    local list = GetRouletteList("Skills", uuid, tag)
    if #list == 0 then
        print("[ROULETTE] No skills available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasSkill, function(char, skill) Osi.AddSkill(char, skill, 1) end, "Skill", amount)
end

Mods[ModTable].RouletteSpells = function(character, uuid, tag, amount)
    print("[DEBUG] RouletteSpells called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)
    local list = GetRouletteList("Spells", uuid, tag)
    if #list == 0 then
        print("[ROULETTE] No spells available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasSpell, Osi.AddSpell, "Spell", amount)
end

Mods[ModTable].RouletteAbilities = function(character, uuid, tag, amount)
    print("[DEBUG] RouletteAbilities called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)
    local list = GetRouletteList("Abilities", uuid, tag)
    if #list == 0 then
        print("[ROULETTE] No abilities available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasAbility, function(char, ab) Osi.AddAbility(char, ab, 1) end, "Ability", amount)
end

Mods[ModTable].RouletteFeats = function(class, level)
    print("[DEBUG] RouletteFeats called for Class:", class, "Level:", level)
    local featTables = Mods[ModTable].FeatTables
    if featTables[class] and featTables[class][level] then
        local featList = featTables[class][level]
        DebugPrintList("Available Feats", featList)
        local selectedFeat
        repeat
            selectedFeat = featList[math.random(#featList)]
            print("[DEBUG] Rolled Feat:", selectedFeat)
        until not Mods[ModTable].selectedFeats[selectedFeat]  -- Ensure no duplicates
        Mods[ModTable].selectedFeats[selectedFeat] = true  -- Mark feat as selected
        print("[RouletteFeats] Selected feat:", selectedFeat)
        return selectedFeat
    else
        print("[DEBUG] No feats found for class:", class, "level:", level)
    end
end

Mods[ModTable].RouletteSubclasses = function(character, class, level)
    print("[DEBUG] RouletteSubclasses called for Character:", character, "Class:", class, "Level:", level)

    -- Check if the class exists in the SubclassTables
    local subclassTable = Mods[ModTable].SubclassTables[class]
    if not subclassTable then
        print("[ERROR] No subclass table found for class:", class)
        return
    end

    print("[DEBUG] Subclass table found for class:", class)
    DebugPrintList("Available Subclasses", subclassTable)

    -- Check if the character already has any of the subclass passives
    for _, passive in ipairs(subclassTable) do
        if HasPassive(character, passive) then
            print("[DEBUG] Character already has subclass passive:", passive)
            return -- Exit if any passive is already applied
        end
    end

    -- Randomly select a subclass passive from the table
    local selectedPassive = subclassTable[math.random(#subclassTable)]
    print("[DEBUG] Rolled subclass passive:", selectedPassive)

    -- Add the selected passive to the character
    Osi.AddPassive(character, selectedPassive)
    print("[RouletteSubclasses] Subclass passive added:", selectedPassive, "to Character:", character)
end