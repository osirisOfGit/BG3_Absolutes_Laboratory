PassivesProxy = StatProxy:new()

PassivesProxy.statsToParse = {
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

StatProxy:RegisterStatType("Passives", PassivesProxy)

function PassivesProxy:buildHyperlinkedStrings(parent, statString)
	if statString and statString ~= "" then
		for passiveName in self:SplitSpring(statString) do
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
