ConditionsProxy = ResourceProxy:new()
ConditionsProxy.delimeter = "(and|or)"
ConditionsProxy.fieldsToParse = {
}

ResourceProxy:RegisterResourceProxy("Conditions", ConditionsProxy)
ResourceProxy:RegisterResourceProxy("RequirementConditions", ConditionsProxy)
ResourceProxy:RegisterResourceProxy("StatsConditions", ConditionsProxy)

---@param conditionsString string
function ConditionsProxy:RenderDisplayableValue(parent, conditionsString, statType)
	if conditionsString and type(conditionsString) == "string" and conditionsString ~= "" then
		FunctorsProxy:parseHyperlinks(parent, conditionsString)
	else
		EntityManager:RenderDisplayableValue(parent, conditionsString)
	end
end
