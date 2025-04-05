local ModTable = "Ultimate_NPC_Stat_Overhaul"
Mods[ModTable] = Mods[ModTable] or {}
Mods[ModTable].PersistentVars = Mods[ModTable].PersistentVars or {}

function SetCharacterVar(character, category, key, value)
    local vars = Mods[ModTable].PersistentVars
    vars[character] = vars[character] or {}
    vars[character][category] = vars[character][category] or {}
    vars[character][category][key] = value
end

function AddToCharacterList(character, category, value)
    local vars = Mods[ModTable].PersistentVars
    vars[character] = vars[character] or {}
    vars[character][category] = vars[character][category] or {}
    table.insert(vars[character][category], value)
end

-- Apply previously stored values from PersistentVars (no rolling here)
local function ApplyPersistantVars(character)
    local stored = Mods[ModTable].PersistentVars[character]
    if not stored then return end

    if stored.Skills then
        for _, skillUUID in ipairs(stored.Skills) do
            Osi.SelectSkills(character, skillUUID, 2)
        end
    end

    if stored.Spells then
        for _, spell in ipairs(stored.Spells) do
            Osi.AddSpell(character, spell, 1, 0)
        end
    end

    if stored.AbilityBonus then
        Osi.SelectAbilityBonus(character, stored.AbilityBonus, "AbilityBonus", 2, 1)
    end

    if stored.SubclassPassive then
        Osi.AddPassive(character, stored.SubclassPassive)
    end

    if stored.Feats then
        for _, feat in ipairs(stored.Feats) do
            Osi.AddPassive(character, feat)
        end
    end
end

-- Vars stuff
local selectedFeats = {}
local rolls = rolls or {} -- Ensure rolls is initialized as an empty table if nil

for _, roll in ipairs(rolls) do
    Mods[ModTable].PersistentVars[character][roll.type] = roll.value
end