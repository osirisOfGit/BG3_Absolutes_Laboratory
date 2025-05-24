FunctorsProxy = ResourceProxy:new()

FunctorsProxy.fieldsToParse = {
}

ResourceProxy:RegisterResourceProxy("StatsFunctors", FunctorsProxy)
ResourceProxy:RegisterResourceProxy("Array<stats::FunctorGroup>", FunctorsProxy)

local levelMapMap = {}

local function mapLevelMap()
	if not next(levelMapMap) then
		for _, levelMapId in pairs(Ext.StaticData.GetAll("LevelMap")) do
			---@type ResourceLevelMap
			local levelMap = Ext.StaticData.Get(levelMapId, "LevelMap")
			levelMapMap[levelMap.Name] = levelMapId
		end
	end
end

---@type {[string]: fun(functor: StatsFunctor):string}
local registeredFunctorTypes = {}

---@param parent ExtuiTreeParent
---@param text string
local function parseHyperlinks(parent, text)
	local list = {}

	for wordOrNonAlnum in text:gmatch("([%w%._]+)") do
		table.insert(list, wordOrNonAlnum)
	end

	local label = ""
	local counter = 0
	for i, section in ipairs(list) do
		local resourceText, resource

		if section == "HasPassive" then
			resourceText = list[i + 1]
			resource = Ext.Stats.Get(resourceText)
		elseif section == "LevelMapValue" then
			mapLevelMap()

			resourceText = list[i + 1]
			resource = Ext.StaticData.Get(levelMapMap[resourceText], "LevelMap")
		end

		if resourceText then
			section = section .. "("
			parent:AddText(label .. section).SameLine = not label:find("IF")
			counter = counter + #section
			label = ""

			local hyperLink = Styler:HyperlinkText(parent, resourceText, function(parent)
				ResourceManager:RenderDisplayWindow(resource, parent)
			end)
			hyperLink.SameLine = true
			hyperLink.AllowDuplicateId = true

			counter = counter + (#hyperLink.Label)

			table.remove(list, i + 1)
		else
			counter = counter + #section
			label = label .. section
		end

		local nextChars = text:sub(counter):match("([^%w%']+)%w")
		counter = counter + (nextChars and #nextChars or 0)
		label = label .. (nextChars or "")
	end
	if label ~= "" then
		local nextChars = text:sub(counter + 1)
		counter = counter + (nextChars and #nextChars or 0)
		label = label .. (nextChars or "")

		parent:AddText(label).SameLine = true
	end
end

---@param functors StatsFunctorGroup[]
function FunctorsProxy:RenderDisplayableValue(parent, functors)
	if functors and functors ~= "" then
		for _, functorList in pairs(functors) do
			for _, functor in pairs(functorList.Functors) do
				if registeredFunctorTypes[functor.TypeId] then
					parseHyperlinks(parent, registeredFunctorTypes[functor.TypeId](functor, parent))
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
registeredFunctorTypes["DealDamage"] = function(functor)
	local text = ""
	if functor.StatsConditions ~= "" then
		text = text .. string.format("IF (%s):", tostring(functor.StatsConditions))
	end

	text = text .. string.format("%s(%s,%s,%s)", functor.TypeId, functor.Damage.Code, functor.DamageType, functor.Magical and "Magical" or "")

	return text
end

---@param functor StatsApplyStatusFunctor
registeredFunctorTypes["ApplyStatus"] = function(functor)
	local text = ""
	if functor.StatsConditions ~= "" then
		text = text .. string.format("IF (%s):", tostring(functor.StatsConditions))
	end

	text = text .. string.format("%s(%s,%s,%s)",
		functor.TypeId,
		functor.StatusId,
		functor.StatusSpecificParam2 > -1 and functor.StatusSpecificParam2 or 100,
		functor.StatusSpecificParam3 > -1 and functor.StatusSpecificParam3 or 0)

	return text
end

--[[
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
]
]]
