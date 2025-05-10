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

		for _, passiveName in ipairs(passiveTable) do
			---@type PassiveData?
			local passive = Ext.Stats.Get(passiveName)

			if passive then
				local hasKids = #parent.Children > 0
				local passiveText = Styler:HyperlinkText(parent, passiveName, function(parent)
					self:RenderDisplayWindow(passive, parent)
				end)
				passiveText.SameLine = hasKids;

				if #passiveTable > 1 then
					parent:AddText(self.delimeter).SameLine = true
				end
			end
		end
	end
end
