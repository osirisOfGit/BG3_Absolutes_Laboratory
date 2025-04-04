-- Holy moly scan the whole population of the world like Mark Zuckerberg and the lizard empire.
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level_name, is_editor_mode)
    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local charID = entity.Uuid and entity.Uuid.EntityUuid or entity
        if type(charID) == "string" then
            for classPassive, classFunction in pairs(ClassRouletteMap) do
                if HasPassive(charID, classPassive) then
                    Mods[ModTable].PersistentVars[charID] = Mods[ModTable].PersistentVars[charID] or {}
                    if next(Mods[ModTable].PersistentVars[charID]) == nil then
                        classFunction(charID)
                    end
                    ApplyLevelBasedBoosts(charID)
                    ApplyPersistentPassives(charID)
                end
            end
        end
    end
end)

-- Boost bars are worse than Snickers because Mr. T was never in a Boost commercial.
local function ApplyLevelBoosts(char)
    local level = Osi.GetLevel(char)

    for i = 1, level do
        if LevelBoosts[i] then
            LevelBoosts[i](char)
        end
    end
end

-- Apply previously stored values from PersistentVars (no rolling here)
local function ApplyPersistentPassives(character)
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

-- Yeah we classist.
local ClassRouletteMap = {
    ["Goon_Barbarian_NPC_Progressions"] = BarbarianRoulette,
    ["Goon_Bard_NPC_Progressions"] = BardRoulette,
    ["Goon_Cleric_NPC_Progressions"] = ClericRoulette,
    ["Goon_Druid_NPC_Progressions"] = DruidRoulette,
    ["Goon_Fighter_NPC_Progressions"] = FighterRoulette,
    ["Goon_Monk_NPC_Progressions"] = MonkRoulette,
    ["Goon_Paladin_NPC_Progressions"] = PaladinRoulette,
    ["Goon_Ranger_NPC_Progressions"] = RangerRoulette,
    ["Goon_Rogue_NPC_Progressions"] = RogueRoulette,
    ["Goon_Sorcerer_NPC_Progressions"] = SorcererRoulette,
    ["Goon_Warlock_NPC_Progressions"] = WarlockRoulette,
    ["Goon_Wizard_NPC_Progressions"] = WizardRoulette,
}