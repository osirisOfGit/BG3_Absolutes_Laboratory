-- ==================================== Main functions ====================================

-- Fetch a list based on category, UUID, and optional tag
local function GetRouletteList(category, uuid, tag)
    print("[DEBUG] Fetching Roulette List for Category:", category, "UUID:", uuid, "Tag:", tag)
    local data = Mods[ModTable].RouletteData and Mods[ModTable].RouletteData[category]
    if not data then
        print("[ERROR] No data found for category:", category)
        return {}
    end

    local list = data[uuid]
    if not list then
        print("[ERROR] No list found for UUID:", uuid, "in category:", category)
        return {}
    end

    -- Filter by tag if provided
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

-- Shuffle a list to randomize its order
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

-- Add unique entries to a character
local function AddUniqueEntries(character, items, checkFn, addFn, label, amount)
    local addedCount = 0
    for _, entry in ipairs(items) do
        if not checkFn(character, entry) then
            addFn(character, entry)
            print("[DEBUG] Added", label, ":", entry, "to Character:", character)
            addedCount = addedCount + 1
            if addedCount >= amount then
                break
            end
        end
    end
    return addedCount
end

-- ==================================== Roulettes ====================================

-- Skills
Mods[ModTable].RouletteSkills = function(character, uuid, amount)
    local list = GetRouletteList("Skills", uuid)
    if #list == 0 then
        print("[ERROR] No skills available for UUID:", uuid)
        return
    end

    local shuffledList = ShuffleList(list)
    AddUniqueEntries(character, shuffledList, HasSkill, Osi.AddSkill, "Skill", amount)
end

-- Abilities
Mods[ModTable].RouletteAbilities = function(character, uuid, tag, amount)
    local list = GetRouletteList("Abilities", uuid, tag)
    if #list == 0 then
        print("[ERROR] No abilities available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffledList = ShuffleList(list)
    AddUniqueEntries(character, shuffledList, HasAbility, AddAbilityModifiers, "Ability", amount)
end

-- Subclasses
Mods[ModTable].RouletteSubclasses = function(character, class)
    local subclassTable = Mods[ModTable].SubclassTables[class]
    if not subclassTable then
        print("[ERROR] No subclass table found for class:", class)
        return
    end

    local shuffledList = ShuffleList(subclassTable)
    AddUniqueEntries(character, shuffledList, HasPassive, Osi.AddPassive, "Subclass Passive", 1)
end

-- Feats
Mods[ModTable].RouletteFeats = function(class, level)
    local featTable = Mods[ModTable].FeatTables[class]
    if not featTable or not featTable["Level" .. level] then
        print("[ERROR] No feats found for class:", class, "at level:", level)
        return
    end

    local list = featTable["Level" .. level]
    local shuffledList = ShuffleList(list)
    AddUniqueEntries(character, shuffledList, HasPassive, Osi.AddPassive, "Feat", 1)
end

-- Spells
Mods[ModTable].RouletteSpells = function(character, uuid, tag, amount)
    print("[DEBUG] RouletteSpells called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)

    local list = GetRouletteList("Spells", uuid, tag)
    if #list == 0 then
        print("[ERROR] No spells available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffledList = ShuffleList(list)
    AddUniqueEntries(character, shuffledList, HasSpell, function(char, spell)
        print("[DEBUG] Adding Spell:", spell, "to Character:", char)
        Osi.AddSpell(char, spell)
    end, "Spell", amount)
end

-- Passives
Mods[ModTable].RoulettePassives = function(character, uuid, tag, amount)
    print("[DEBUG] RoulettePassives called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)

    local list = GetRouletteList("Passives", uuid, tag)
    if #list == 0 then
        print("[ERROR] No passives available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffledList = ShuffleList(list)
    AddUniqueEntries(character, shuffledList, HasPassive, function(char, passive)
        print("[DEBUG] Adding Passive:", passive, "to Character:", char)
        Osi.AddPassive(char, passive)
    end, "Passive", amount)
end