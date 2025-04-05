function Timestamp()
    return "[" .. tostring(Osi.GetGameTime()) .. "]"
end

function Goon_DebugForceReapply()
    print(Timestamp(), "== Manual Debug Force Reapply ==")

    if not LevelBoostTables then
        print(Timestamp(), "[ERROR] LevelBoostTables is nil!")
        return
    end

    for _, entity in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ServerCharacter")) do
        local charID = entity.Uuid and entity.Uuid.EntityUuid or entity
        if type(charID) == "string" then
            local name = Osi.GetDisplayName(charID) or "Unknown"
            local level = Osi.GetLevel(charID) or 0

            print(Timestamp(), "[CHARACTER]", name, "(", charID, ") | Level:", level)

            for classPassive, classFunction in pairs(LevelBoostTables) do
                if HasPassive(charID, classPassive) then
                    print(Timestamp(), "  [CLASS DETECTED]", classPassive)

                    -- Force wipe and reapply
                    Mods[ModTable].PersistentVars[charID] = {}

                    print(Timestamp(), "  [ROULETTE] Running class function...")
                    classFunction(charID)

                    print(Timestamp(), "  [LEVEL BOOSTS] Reapplying boosts...")
                    ApplyLevelBasedBoosts(charID)

                    print(Timestamp(), "  [PASSIVES] Reapplying persistent passives...")
                    ApplyPersistantVars(charID)

                    print(Timestamp(), "  [COMPLETE] All reapplication done for", name)
                    break -- Stop checking further class passives
                end
            end
        end
    end

    -- Print the entire PersistentVars table for debug
    print(Timestamp(), "[DEBUG] Full PersistentVars Table:")
    Ext.Utils.PrintLuaTable(Mods[ModTable].PersistentVars)

    print(Timestamp(), "== Manual Debug Force Reapply Complete ==")
end

Ext.RegisterConsoleCommand("Goon_DebugForceReapply", function()
    Goon_DebugForceReapply()
end)
