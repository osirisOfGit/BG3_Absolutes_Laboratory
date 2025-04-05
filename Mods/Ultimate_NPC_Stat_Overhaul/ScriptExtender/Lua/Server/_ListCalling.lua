-- SelectRandomPassivesFromUUID(char, "some-uuid-for-passives", "PassivesTag", 2)
-- SelectRandomSkillsFromUUID(char, "some-uuid-for-skills", "SkillTag", 2)
-- SelectRandomSpellsFromUUID(char, "some-uuid-for-spells", "SpellTag", 3)
-- SelectRandomAbilitiesFromUUID(char, "some-uuid-for-abilities", "AbilityTag", 1)

-- ==================================== Passives ====================================

local function RoulettePassives(character, uuid, tag, amount)
    -- Query the game for the list of passives associated with the UUID
    local passiveList = Osi.GetPassivesByUUID(uuid, tag) -- Replace with the correct Osi function if available

    -- Ensure the passive list is valid and not empty
    if not passiveList or #passiveList == 0 then
        print("Error: No passives found for UUID:", uuid)
        return
    end

    -- Shuffle the passive list to ensure randomness
    local shuffledPassives = {}
    for _, passive in ipairs(passiveList) do
        table.insert(shuffledPassives, passive)
    end
    for i = #shuffledPassives, 2, -1 do
        local j = math.random(i)
        shuffledPassives[i], shuffledPassives[j] = shuffledPassives[j], shuffledPassives[i]
    end

    -- Select the specified number of passives
    local selectedCount = 0
    for _, passive in ipairs(shuffledPassives) do
        if not HasPassive(character, passive) then
            Osi.AddPassive(character, passive)
            print("Added passive:", passive, "to character:", character)
            selectedCount = selectedCount + 1
            if selectedCount >= amount then
                break
            end
        end
    end

    if selectedCount < amount then
        print("Warning: Only", selectedCount, "passives were added. Not enough unique passives available.")
    end
end

-- ==================================== Skills ====================================

local function RouletteSkills(character, uuid, tag, amount)
    -- Query the game for the list of skills associated with the UUID
    local skillList = Osi.GetSkillsByUUID(uuid, tag) -- Replace with the correct Osi function if available

    -- Ensure the skill list is valid and not empty
    if not skillList or #skillList == 0 then
        print("Error: No skills found for UUID:", uuid)
        return
    end

    -- Shuffle the skill list to ensure randomness
    local shuffledSkills = {}
    for _, skill in ipairs(skillList) do
        table.insert(shuffledSkills, skill)
    end
    for i = #shuffledSkills, 2, -1 do
        local j = math.random(i)
        shuffledSkills[i], shuffledSkills[j] = shuffledSkills[j], shuffledSkills[i]
    end

    -- Select the specified number of skills
    local selectedCount = 0
    for _, skill in ipairs(shuffledSkills) do
        if not HasSkill(character, skill) then
            Osi.AddSkill(character, skill, 1) -- Add the skill to the character
            print("Added skill:", skill, "to character:", character)
            selectedCount = selectedCount + 1
            if selectedCount >= amount then
                break
            end
        end
    end

    if selectedCount < amount then
        print("Warning: Only", selectedCount, "skills were added. Not enough unique skills available.")
    end
end

-- ==================================== Abilities ====================================

local function RouletteAbilities(character, uuid, tag, amount)
    -- Query the game for the list of abilities associated with the UUID
    local abilityList = Osi.GetAbilitiesByUUID(uuid, tag) -- Replace with the correct Osi function if available

    -- Ensure the ability list is valid and not empty
    if not abilityList or #abilityList == 0 then
        print("Error: No abilities found for UUID:", uuid)
        return
    end

    -- Shuffle the ability list to ensure randomness
    local shuffledAbilities = {}
    for _, ability in ipairs(abilityList) do
        table.insert(shuffledAbilities, ability)
    end
    for i = #shuffledAbilities, 2, -1 do
        local j = math.random(i)
        shuffledAbilities[i], shuffledAbilities[j] = shuffledAbilities[j], shuffledAbilities[i]
    end

    -- Select the specified number of abilities
    local selectedCount = 0
    for _, ability in ipairs(shuffledAbilities) do
        if not HasAbility(character, ability) then
            Osi.AddAbility(character, ability, 1) -- Add the ability to the character
            print("Added ability:", ability, "to character:", character)
            selectedCount = selectedCount + 1
            if selectedCount >= amount then
                break
            end
        end
    end

    if selectedCount < amount then
        print("Warning: Only", selectedCount, "abilities were added. Not enough unique abilities available.")
    end
end

-- ==================================== Spells ====================================

local function RouletteSpells(character, uuid, tag, amount)
    -- Query the game for the list of spells associated with the UUID
    local spellList = Osi.GetSpellsByUUID(uuid, tag) -- Replace with the correct Osi function if available

    -- Ensure the spell list is valid and not empty
    if not spellList or #spellList == 0 then
        print("Error: No spells found for UUID:", uuid)
        return
    end

    -- Shuffle the spell list to ensure randomness
    local shuffledSpells = {}
    for _, spell in ipairs(spellList) do
        table.insert(shuffledSpells, spell)
    end
    for i = #shuffledSpells, 2, -1 do
        local j = math.random(i)
        shuffledSpells[i], shuffledSpells[j] = shuffledSpells[j], shuffledSpells[i]
    end

    -- Select the specified number of spells
    local selectedCount = 0
    for _, spell in ipairs(shuffledSpells) do
        if not HasSpell(character, spell) then
            Osi.AddSpell(character, spell) -- Add the spell to the character
            print("Added spell:", spell, "to character:", character)
            selectedCount = selectedCount + 1
            if selectedCount >= amount then
                break
            end
        end
    end

    if selectedCount < amount then
        print("Warning: Only", selectedCount, "spells were added. Not enough unique spells available.")
    end
end