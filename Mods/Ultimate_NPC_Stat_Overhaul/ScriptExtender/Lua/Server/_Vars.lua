-- Initialize ModTable and Mods
ModTable = "Ultimate_NPC_Stat_Overhaul" -- Declare ModTable globally
Mods = Mods or {} -- Ensure the global Mods table exists
Mods[ModTable] = Mods[ModTable] or {} -- Initialize the ModTable
Mods[ModTable].PersistentVars = Mods[ModTable].PersistentVars or {} -- Initialize PersistentVars

-- Debug print to confirm Mods[ModTable] initialization
print("[DEBUG] Mods[ModTable] initialized:", Mods[ModTable])

-- Utility: Ensures category and key structure exists
local function EnsureVarStructure(character, category)
    if not character or not category then
        print("[ERROR] EnsureVarStructure called with invalid arguments. Character:", character, "Category:", category)
        return {}
    end

    Mods[ModTable].PersistentVars[character] = Mods[ModTable].PersistentVars[character] or {}
    Mods[ModTable].PersistentVars[character][category] = Mods[ModTable].PersistentVars[character][category] or {}
    print(string.format("[DEBUG] EnsureVarStructure: Initialized structure for Character: %s, Category: %s", character, category))
    return Mods[ModTable].PersistentVars[character][category]
end

-- Set a single value
function SetCharacterVar(character, category, key, value)
    if not character or not category or not key then
        print("[ERROR] SetCharacterVar called with invalid arguments. Character:", character, "Category:", category, "Key:", key)
        return
    end

    local cat = EnsureVarStructure(character, category)
    cat[key] = value
    print(string.format("[SetCharacterVar] %s - %s[%s] = %s", character, category, key, value))
end

-- Add to a list
function AddToCharacterList(character, category, value)
    if not character or not category or not value then
        print("[ERROR] AddToCharacterList called with invalid arguments. Character:", character, "Category:", category, "Value:", value)
        return
    end

    local cat = EnsureVarStructure(character, category)
    table.insert(cat, value)
    print(string.format("[AddToCharacterList] %s - Added %s to %s", character, value, category))
end

-- Apply all stored values
function ApplyPersistentVars(character)
    if not character then
        print("[ERROR] ApplyPersistentVars called with invalid character:", character)
        return
    end

    local vars = Mods[ModTable].PersistentVars[character]
    if not vars then
        print("[ApplyPersistentVars] No vars found for character:", character)
        return
    end

    print("[DEBUG] ApplyPersistentVars: Applying vars for character:", character)

    if vars.Skills then
        for _, skillUUID in ipairs(vars.Skills) do
            Osi.SelectSkills(character, skillUUID, 2)
            print("[ApplyPersistentVars] Skill applied:", skillUUID)
        end
    end

    if vars.Spells then
        for _, spellUUID in ipairs(vars.Spells) do
            Osi.AddSpell(character, spellUUID, 1, 0)
            print("[ApplyPersistentVars] Spell applied:", spellUUID)
        end
    end

    if vars.AbilityBonus then
        Osi.SelectAbilityBonus(character, vars.AbilityBonus, "AbilityBonus", 2, 1)
        print("[ApplyPersistentVars] Ability Bonus applied:", vars.AbilityBonus)
    end

    if vars.SubclassPassive then
        Osi.AddPassive(character, vars.SubclassPassive)
        print("[ApplyPersistentVars] Subclass Passive applied:", vars.SubclassPassive)
    end

    if vars.Feats then
        for _, feat in ipairs(vars.Feats) do
            Osi.AddPassive(character, feat)
            print("[ApplyPersistentVars] Feat applied:", feat)
        end
    end
end

-- Console helper for debugging a character's vars
function DumpCharacterVars(character)
    if not character then
        print("[ERROR] DumpCharacterVars called with invalid character:", character)
        return
    end

    local vars = Mods[ModTable].PersistentVars[character]
    if not vars then
        print("[DumpCharacterVars] No vars found for character:", character)
        return
    end

    print("=== DumpCharacterVars for", character, "===")
    for category, data in pairs(vars) do
        print("Category:", category)
        if type(data) == "table" then
            for k, v in pairs(data) do
                print("   ", k, "=", v)
            end
        else
            print("   Value:", data)
        end
    end
    print("======================================")
end

-- Debug print to confirm PersistentVars structure
print("[DEBUG] PersistentVars initialized:", Mods[ModTable].PersistentVars)