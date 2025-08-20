BoostsProxy = ResourceProxy:new()

BoostsProxy.fieldsToParse = {
}

ResourceProxy:RegisterResourceProxy("Boosts", BoostsProxy)

---@param boostString string
function BoostsProxy:RenderDisplayableValue(parent, boostString, statType)
	if boostString and type(boostString) == "string" and boostString ~= "" then
		local boostTable = {}
		if type(boostString) == "string" then
			for val in self:SplitSpring(boostString) do
				table.insert(boostTable, val)
			end
		else
			boostTable = boostString
		end

		if #boostTable >= 10 then
			parent = parent:AddCollapsingHeader("Boosts")
			parent:SetColor("Header", { 1, 1, 1, 0 })
		end

		for _, boostEntry in ipairs(boostTable) do
			FunctorsProxy:parseHyperlinks(parent, boostEntry)
		end
	else
		EntityManager:RenderDisplayableValue(parent, boostString)
	end
end
