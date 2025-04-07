-- Initialize ModTable and Mods
ModTable = "Ultimate_NPC_Stat_Overhaul" -- Declare ModTable globally
Mods = Mods or {} -- Ensure the global Mods table exists
Mods[ModTable] = Mods[ModTable] or {} -- Initialize the ModTable
Mods[ModTable].PersistentVars = Mods[ModTable].PersistentVars or {} -- Initialize PersistentVars

-- Initialize global feats list
Mods[ModTable].PersistentVars.selectedFeats = Mods[ModTable].PersistentVars.selectedFeats or {}

-- Debug print to confirm Mods[ModTable] initialization
print("[DEBUG] Mods[ModTable] initialized:", Mods[ModTable])
print("[DEBUG] PersistentVars initialized:", Mods[ModTable].PersistentVars)

-- Utility: Ensures category and key structure exists for a character
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

-- === Global Feat Tracking === --

-- Add a feat to selectedFeats
function AddSelectedFeat(feat)
    if not feat then
        print("[ERROR] AddSelectedFeat called with invalid feat:", feat)
        return
    end

    Mods[ModTable].PersistentVars.selectedFeats[feat] = true
    print("[AddSelectedFeat] Feat added:", feat)
end

-- Check if a feat is already selected
function IsFeatSelected(feat)
    if not feat then
        print("[ERROR] IsFeatSelected called with invalid feat:", feat)
        return false
    end

    return Mods[ModTable].PersistentVars.selectedFeats[feat] or false
end

-- Clear all selected feats
function ClearSelectedFeats()
    Mods[ModTable].PersistentVars.selectedFeats = {}
    print("[ClearSelectedFeats] All selected feats cleared.")
end
