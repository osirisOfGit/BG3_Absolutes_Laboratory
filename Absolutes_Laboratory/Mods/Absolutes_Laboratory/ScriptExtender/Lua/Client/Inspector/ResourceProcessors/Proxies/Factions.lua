FactionsProxy = ResourceProxy:new()

FactionsProxy.fieldsToParse = {
	"Faction",
	"ResourceUUID",
	"ParentGuid"
}

ResourceProxy:RegisterResourceProxy("Faction", FactionsProxy)
ResourceProxy:RegisterResourceProxy("resource::Faction", FactionsProxy)

---@param faction GUIDSTRING
function FactionsProxy:RenderDisplayableValue(parent, faction, statType)
	if type(faction) == "string" then
		if #faction == 36 then
			FactionsProxy:RenderDisplayWindow(Ext.StaticData.Get(faction, "Faction"), parent)
		else
			if CharacterIndex.displayNameMappings[faction] then
				parent:AddText(string.format("%s (%s)", CharacterIndex.displayNameMappings[faction], faction))
			else
				parent:AddText(faction)
			end
		end
	end
end

---@param faction ResourceFaction
function FactionsProxy:RenderDisplayWindow(faction, parent)
	local display = Styler:TwoColumnTable(parent, faction.ResourceUUID)

	for key, value in TableUtils:OrderedPairs(Ext.Types.Serialize(faction)) do
		if value ~= "00000000-0000-0000-0000-000000000000" then
			local row = display:AddRow()
			row:AddCell():AddText(key)
			if key == "ParentGuid" and value ~= "00000000-0000-0000-0000-000000000000" then
				self:RenderDisplayWindow(Ext.StaticData.Get(value, "Faction"), row:AddCell())
			else
				row:AddCell():AddText(value)
			end
		end
	end
end
