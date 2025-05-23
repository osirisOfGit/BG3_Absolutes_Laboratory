FunctorsProxy = ResourceProxy:new()

FunctorsProxy.fieldsToParse = {
}

ResourceProxy:RegisterResourceProxy("StatsFunctors", FunctorsProxy)
ResourceProxy:RegisterResourceProxy("Array<stats::FunctorGroup>", FunctorsProxy)

---@type {[string]: fun(functor: StatsFunctor, parent: ExtuiTreeParent)}
local registeredFunctorTypes = {}

---@param functors StatsFunctorGroup[]
function FunctorsProxy:RenderDisplayableValue(parent, functors)
	if functors and functors ~= "" then
		for _, functorList in pairs(functors) do
			for _, functor in pairs(functorList.Functors) do
				if registeredFunctorTypes[functor.TypeId] then
					registeredFunctorTypes[functor.TypeId](functor, parent)
				else
					Styler:HyperlinkText(parent, functor.UniqueName, function(parent)
						ResourceManager:RenderDisplayableValue(parent, Ext.Types.Serialize(functor))
					end)
				end
			end
		end
	end
end

---@param functor StatsDealDamageFunctor
registeredFunctorTypes["DealDamage"] = function(functor, parent)
	if functor.StatsConditions ~= "" then
		parent:AddText("IF ")

		-- Example input: "HasPassive('PotentCantrip',context.Source)"
		local str = tostring(functor.StatsConditions)
		local before, middle, after = str:match("^(.-%(')(.-)('.*)$")

		-- Fallback if pattern doesn't match
		if not before or not middle or not after then
			before, middle, after = str, "", ""
		end

		parent:AddText(before).SameLine = true
		Styler:HyperlinkText(parent, middle, function(parent)
			ResourceManager:RenderDisplayWindow(Ext.Stats.Get(middle), parent)
		end).SameLine = true
		parent:AddText(after .. ":").SameLine = true
	end

	parent:AddText(string.format("%s(%s,%s,%s)", functor.TypeId, functor.Damage.Code, functor.DamageType, functor.Magical)).SameLine = true
end

--[[
[
        {
                "Functors" :
                [
                        {
                                "CoinMultiplier" : 0,
                                "ConsumeCoin" : false,
                                "Damage" :
                                {
                                        "Code" : "(LevelMapValue(D12Cantrip))/2",
                                        "Params" :
                                        [
                                                "Divide",
                                                "Variable",
                                                "LevelMapValue",
                                                "D12Cantrip",
                                                [],
                                                "Unspecified",
                                                "Roll",
                                                {
                                                        "AmountOfDices" : 0,
                                                        "DiceAdditionalValue" : 2,
                                                        "DiceNegative" : false,
                                                        "DiceValue" : "D20"
                                                }
                                        ]
                                },
                                "DamageType" : "Poison",
                                "Flags" : [],
                                "FunctorUuid" : "c206933a-f876-a664-7dae-2da41db784b4",
                                "IgnoreDamageBonus" : false,
                                "IgnoreEvents" : false,
                                "IgnoreImmunities" : false,
                                "Magical" : true,
                                "Nonlethal" : false,
                                "ObserverType" : "None",
                                "PropertyContext" :
                                [
                                        "TARGET",
                                        "AOE"
                                ],
                                "RollConditions" : [],
                                "StatsConditions" : "HasPassive('PotentCantrip',context.Source)",
                                "StoryActionId" : 0,
                                "TypeId" : "DealDamage",
                                "UniqueName" : "DealDamageTARGETAOE_IF(HasPassive('PotentCantrip',context.Source))_0",
                                "WeaponDamageType" : "None",
                                "WeaponType" : "None"
                        },
                        {
                                "Conditions" : "",
                                "Flags" : [],
                                "FunctorUuid" : "c2e676aa-c5ed-d708-2331-468b3045108a",
                                "KeepAlive" : false,
                                "ObserverType" : "None",
                                "PropertyContext" :
                                [
                                        "TARGET",
                                        "AOE"
                                ],
                                "RequiresConcentration" : false,
                                "RollConditions" : [],
                                "StatsConditions" : "not HasPassive('PotentCantrip',context.Source)",
                                "StatusConditions" : "",
                                "StatusId" : "SAVED_AGAINST_HOSTILE_SPELL",
                                "StatusSpecificParam1" : "",
                                "StatusSpecificParam2" : -1,
                                "StatusSpecificParam3" : -1,
                                "StoryActionId" : 0,
                                "TypeId" : "ApplyStatus",
                                "UniqueName" : "SAVED_AGAINST_HOSTILE_SPELLTARGETAOE_IF(not HasPassive('PotentCantrip',context.Source))_1"
                        }
                ],
                "TextKey" : "Default"
        }
]
]]
