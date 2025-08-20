PassivesProxy = ResourceProxy:new()

PassivesProxy.fieldsToParse = {
	"BoostConditions",
	"BoostContext",
	"Boosts",
	"Conditions",
	"Description",
	"DescriptionRef",
	"DescriptionParams",
	"DisplayName",
	"DisplayNameRef",
	"DynamicAnimationTag",
	"EnabledConditions",
	"EnabledContext",
	"ExtraDescription",
	"ExtraDescriptionRef",
	"ExtraDescriptionParams",
	"Icon",
	"LoreDescription",
	"LoreDescriptionRef",
	"PriorityOrder",
	"Properties",
	"StatsFunctorContext",
	"StatsFunctors",
	"ToggleGroup",
	"ToggleOffContext",
	"ToggleOffEffect",
	"ToggleOffFunctors",
	"ToggleOnEffect",
	"ToggleOnFunctors",
	"TooltipConditionalDamage",
	"TooltipPermanentWarnings",
	"TooltipSave",
	"TooltipUseCosts",
}

ResourceProxy:RegisterResourceProxy("Passives", PassivesProxy)
ResourceProxy:RegisterResourceProxy("PassiveId", PassivesProxy)
ResourceProxy:RegisterResourceProxy("PassiveData", PassivesProxy)
ResourceProxy:RegisterResourceProxy("ServerPassiveBase", PassivesProxy)
ResourceProxy:RegisterResourceProxy("PassivesAdded", PassivesProxy)
ResourceProxy:RegisterResourceProxy("PassivesRemoved", PassivesProxy)

function PassivesProxy:RenderDisplayableValue(parent, statString)
	if statString and statString ~= "" then
		local passiveTable = {}
		if type(statString) == "string" then
			for val in self:SplitSpring(statString) do
				table.insert(passiveTable, val)
			end
		else
			passiveTable = statString
		end

		if type(passiveTable) == "table" then
			if #passiveTable >= 10 then
				parent = parent:AddCollapsingHeader("Passives")
				parent:SetColor("Header", { 1, 1, 1, 0 })
			end
			for _, passiveName in ipairs(passiveTable) do
				---@type PassiveData?
				local passive = Ext.Stats.Get(passiveName)

				if passive then
					Styler:HyperlinkText(parent, passiveName, function(parent)
						self:RenderDisplayWindow(passive, parent)
					end)
				end
			end
		else
			parent:AddText(passiveTable)
		end
	end
end
