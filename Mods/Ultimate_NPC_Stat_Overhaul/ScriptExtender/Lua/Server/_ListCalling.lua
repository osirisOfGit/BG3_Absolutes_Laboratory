function ShuffleList(inputList)
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

-- ==================================== Passives ====================================

function HasPassive(character, passive)
    return Osi.HasPassive(character, passive) == 1
end

function RoulettePassives(character, uuid, tag, amount)
    print("[DEBUG] RoulettePassives called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)

    -- Fetch the passive list using the UUID
    local passiveList = Ext.StaticData.Get(uuid, "PassiveList")
    if not passiveList or not passiveList.Passives then
        print("[ERROR] No passives found for UUID:", uuid)
        return
    end

    -- Filter passives by tag if provided
    local filteredPassives = {}
    for _, passive in ipairs(passiveList.Passives) do
        if not tag or passive:find(tag) then
            table.insert(filteredPassives, passive)
        end
    end

    if #filteredPassives == 0 then
        print("[ROULETTE] No passives available after filtering for UUID:", uuid, "and Tag:", tag)
        return
    end

    -- Shuffle the filtered passives
    local shuffledPassives = ShuffleList(filteredPassives)
    print("[DEBUG] Shuffled Passive List:", shuffledPassives)

    -- Add unique passives to the character
    local addedCount = 0
    for _, passive in ipairs(shuffledPassives) do
        if not HasPassive(character, passive) then
            print("[DEBUG] Adding Passive:", passive, "to Character:", character)
            Osi.AddPassive(character, passive)
            addedCount = addedCount + 1
            if addedCount >= amount then
                break
            end
        else
            print("[DEBUG] Character already has Passive:", passive)
        end
    end

    if addedCount == 0 then
        print("[ROULETTE] No new passives were added to Character:", character)
    else
        print("[ROULETTE] Added", addedCount, "passives to Character:", character)
    end
end

-- ==================================== Spells ====================================

function HasSpell(character, spell)
    return Osi.HasSpell(character, spell) == 1
end

function RouletteSpells(character, uuid, tag, amount)
    print("[DEBUG] RouletteSpells called for Character:", character, "UUID:", uuid, "Tag:", tag, "Amount:", amount)

    -- Fetch the spell list using the UUID
    local spellList = Ext.StaticData.Get(uuid, "SpellList")
    if not spellList or not spellList.Spells then
        print("[ERROR] No spells found for UUID:", uuid)
        return
    end

    -- Filter spells by tag if provided
    local filteredSpells = {}
    for _, spell in ipairs(spellList.Spells) do
        if not tag or spell:find(tag) then
            table.insert(filteredSpells, spell)
        end
    end

    if #filteredSpells == 0 then
        print("[ROULETTE] No spells available after filtering for UUID:", uuid, "and Tag:", tag)
        return
    end

    -- Sort the filtered spells (optional, based on level or name)
    local sortedSpells = DWE_SortSpellList(filteredSpells)
    if sortedSpells then
        filteredSpells = sortedSpells
    end

    -- Shuffle the filtered spells
    local shuffledSpells = ShuffleList(filteredSpells)
    print("[DEBUG] Shuffled Spell List:", shuffledSpells)

    -- Add unique spells to the character
    local addedCount = 0
    for _, spell in ipairs(shuffledSpells) do
        if not HasSpell(character, spell) then
            print("[DEBUG] Adding Spell:", spell, "to Character:", character)
            Osi.AddSpell(character, spell)
            addedCount = addedCount + 1
            if addedCount >= amount then
                break
            end
        else
            print("[DEBUG] Character already has Spell:", spell)
        end
    end

    if addedCount == 0 then
        print("[ROULETTE] No new spells were added to Character:", character)
    else
        print("[ROULETTE] Added", addedCount, "spells to Character:", character)
    end
end