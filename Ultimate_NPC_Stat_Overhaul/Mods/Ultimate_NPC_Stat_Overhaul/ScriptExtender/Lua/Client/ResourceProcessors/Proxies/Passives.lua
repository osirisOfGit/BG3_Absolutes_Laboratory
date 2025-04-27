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
		if type(statString) == "string" then
			local passiveTable = {}
			for val in self:SplitSpring(statString) do
				table.insert(passiveTable, val)
			end
		end

		for _, passiveName in ipairs(statString) do
			---@type PassiveData?
			local passive = Ext.Stats.Get(passiveName)

			if passive then
				local hasKids = #parent.Children > 0
				local passiveText = Styler:HyperlinkText(parent:AddText(passiveName))
				passiveText.SameLine = hasKids;
				self:RenderDisplayWindow(passive, passiveText:Tooltip())

				parent:AddText(self.delimeter).SameLine = true
			end
		end
	end
end
