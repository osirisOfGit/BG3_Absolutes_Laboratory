FactionsProxy = ResourceProxy:new()

FactionsProxy.fieldsToParse = {
	"Amount",
	"CanBePickpocketed",
	"Conditions",
	"IsDroppedOnDeath",
	"IsTradable",
	"ItemName",
	"LevelName",
	"TemplateID",
	"Type",
	"UUID",
}

ResourceProxy:RegisterResourceProxy("Faction", FactionsProxy)

---@param faction GUIDSTRING
function FactionsProxy:RenderDisplayableValue(parent, faction)
	parent:AddText(string.format("%s (%s)", CharacterIndex.displayNameMappings[faction], faction))
end
