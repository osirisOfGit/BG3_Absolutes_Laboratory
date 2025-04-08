-- Ensure the Queue table exists
Queue = Queue or {}

-- Ensure the CLUtils and Utils tables exist
CLUtils = CLUtils or {}
Utils = Utils or {}

-- Debug print helper
local function DebugPrintList(label, list)
    print("[DEBUG] " .. label .. ":")
    for i, item in ipairs(list) do
        print("  [" .. i .. "] " .. tostring(item))
    end
end

function Queue.Commit()
    print("[DEBUG] Entering Queue.Commit")
    Queue.CommitLists()
    Queue.CommitFeatsAndProgressions()
    Queue.CommitRaces()
    -- Uncomment if needed
    -- Queue.CommitSpellData()
end

function Queue.CommitLists()
    print("[DEBUG] Entering Queue.CommitLists")
    for type, listList in pairs(Queue.Lists) do
        for listId, list in pairs(listList) do
            local gameList = CLUtils.CacheOrRetrieve(listId, type)
            for _, item in pairs(gameList[CLGlobals.ListNodes[type]]) do
                if not CLUtils.IsInTable(list, item) then
                    table.insert(list, item)
                end
            end
            local res = Utils.StripInvalidStatData(list)
            gameList[CLGlobals.ListNodes[type]] = res
        end
    end
end

function CLUtils.CacheOrRetrieve(listId, type)
    -- Retrieve the game list based on the list ID and type
    local gameList = Ext.Stats.Get(listId, nil, false)
    if not gameList then
        print("[ERROR] Failed to retrieve game list for ListID:", listId, "Type:", type)
        return {}
    end
    return gameList
end

function Utils.StripInvalidStatData(arr)
    print("[DEBUG] Cleaning up list:", arr)
    for key, value in pairs(arr) do
        if value == '' or value == ' ' then
            arr[key] = nil
        elseif Ext.Stats.Get(value, nil, false) == nil then
            arr[key] = nil
        end
    end
    return arr
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
        return Utils.StripInvalidStatData(filtered) -- Clean up the filtered list
    end

    DebugPrintList("Full List", list)
    return Utils.StripInvalidStatData(list) -- Clean up the full list
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

-- ==================================== 🌀 Generic Roulette Processor ====================================

local function ProcessList(category, uuid, tag, blacklist, comparator)
    print("[DEBUG] Processing List for Category:", category, "UUID:", uuid, "Tag:", tag)

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

    -- Filter by tag
    if tag then
        local filtered = {}
        for _, entry in ipairs(list) do
            if entry:find(tag) then
                table.insert(filtered, entry)
            end
        end
        list = filtered
    end

    -- Apply blacklist
    if blacklist then
        local filtered = {}
        for _, entry in ipairs(list) do
            if not blacklist[entry] then
                table.insert(filtered, entry)
            else
                print("[DEBUG] Blacklisted entry:", entry)
            end
        end
        list = filtered
    end

    -- Sort the list
    if comparator then
        table.sort(list, comparator)
    end

    DebugPrintList("Processed List", list)
    return Utils.StripInvalidStatData(list) -- Clean up the list
end

-- ==================================== 🌀 Roulette Functions ====================================

Mods[ModTable].RoulettePassives = function(character, uuid, tag, amount)
    print("[DEBUG] RoulettePassives called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)

    local blacklist = {
        -- Add any passives you want to blacklist here
        ["Passive_To_Blacklist"] = true
    }

    local list = ProcessList("Passives", uuid, tag, blacklist, nil)
    if #list == 0 then
        print("[ROULETTE] No passives available for UUID:", uuid, "and Tag:", tag)
        return
    end

    AddUniqueEntries(character, list, HasPassive, function(char, passive)
        print("[DEBUG] Adding Passive:", passive, "to Character:", char)
        Osi.AddPassive(char, passive)
    end, "Passive", amount)

    Queue.CommitLists()
end

Mods[ModTable].RouletteSkills = function(character, uuid, tag, amount)
    print("[DEBUG] RouletteSkills called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)

    local blacklist = {
        -- Add any skills you want to blacklist here
        ["Skill_To_Blacklist"] = true
    }

    local list = ProcessList("Skills", uuid, tag, blacklist, nil)
    if #list == 0 then
        print("[ROULETTE] No skills available for UUID:", uuid, "and Tag:", tag)
        return
    end

    AddUniqueEntries(character, list, HasSkill, function(char, skill)
        print("[DEBUG] Adding Skill:", skill, "to Character:", char)
        Osi.AddSkill(char, skill, 1)
    end, "Skill", amount)

    Queue.CommitLists()
end

Mods[ModTable].RouletteSpells = function(character, uuid, tag, amount)
    print("[DEBUG] RouletteSpells called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)
    local list = GetRouletteList("Spells", uuid, tag)
    if #list == 0 then
        print("[ROULETTE] No spells available for UUID:", uuid, "and Tag:", tag)
        return
    end

    print("[DEBUG] Full Spell List:", list)
    local shuffled = ShuffleList(list)
    print("[DEBUG] Shuffled Spell List:", shuffled)
    AddUniqueEntries(character, shuffled, HasSpell, function(char, spell)
        print("[DEBUG] Adding Spell:", spell, "to Character:", char)
        Osi.AddSpell(char, spell)
    end, "Spell", amount)
end

Mods[ModTable].RouletteAbilities = function(character, uuid, tag, amount)
    print("[DEBUG] RouletteAbilities called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)
    local list = GetRouletteList("Abilities", uuid, tag)
    if #list == 0 then
        print("[ROULETTE] No abilities available for UUID:", uuid, "and Tag:", tag)
        return
    end

    local shuffled = ShuffleList(list)
    AddUniqueEntries(character, shuffled, HasAbility, function(char, ab)
        print("[DEBUG] Adding Ability Modifier:", ab, "to Character:", char)
        AddAbilityModifiers(char, ab) -- Use AddAbilityModifiers instead of Osi.AddAbility
    end, "Ability", amount)
end

Mods[ModTable].RouletteFeats = function(character, class, level)
    print("[DEBUG] RouletteFeats called for Character:", character, "Class:", class, "Level:", level)
    local featTables = Mods[ModTable].FeatTables

    if featTables[class] and featTables[class][level] then
        local featList = featTables[class][level]
        DebugPrintList("Available Feats", featList)

        local selectedFeat
        local attempts = 0
        repeat
            selectedFeat = featList[math.random(#featList)]
            attempts = attempts + 1
            if attempts > 100 then
                print("[ERROR] Too many attempts to find a unique feat for", character)
                return
            end
        until not IsFeatSelected(character, selectedFeat)

        AddSelectedFeat(character, selectedFeat)
        print("[RouletteFeats] Selected feat:", selectedFeat)

        -- Optional: apply the feat as a passive (if that's how your feats work)
        Osi.AddPassive(character, selectedFeat)

        return selectedFeat
    else
        print("[DEBUG] No feats found for class:", class, "level:", level)
    end
end

Mods[ModTable].RouletteSubclasses = function(character, class, level)
    print("[DEBUG] RouletteSubclasses called for Character:", character, "Class:", class, "Level:", level)

    -- Ensure the class exists in the SubclassTables
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