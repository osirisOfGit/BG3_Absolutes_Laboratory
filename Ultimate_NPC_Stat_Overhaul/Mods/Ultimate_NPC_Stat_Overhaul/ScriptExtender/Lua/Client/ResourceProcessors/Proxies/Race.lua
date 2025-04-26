RaceProxy = ResourceProxy:new()

RaceProxy.fieldsToParse = {
	"Description",
	"DisplayName",
	"ExcludedGods",
	"Gods",
	"MergedInto",
	"Name",
	"ParentGuid",
	"ProgressionTableUUID",
	"Tags",
}

ResourceProxy:RegisterResourceProxy("Race", RaceProxy)
ResourceProxy:RegisterResourceProxy("ParentGuid", RaceProxy)

---@param raceId string
function RaceProxy:RenderDisplayableValue(parent, raceId, statType)
	---@type ResourceRace?
	local race = Ext.StaticData.Get(raceId, "Race")

	if race then
		CharacterIndex.displayNameMappings[race] = race.DisplayName:Get() or race.Name

		if statType ~= "ParentGuid" then
			local hasKids = #parent.Children > 0
			local tagText = Styler:HyperlinkText(parent:AddText(race.DisplayName:Get() or race.Name))
			tagText.SameLine = hasKids;
			self:RenderDisplayWindow(race, tagText:Tooltip())

			parent:AddText(self.delimeter).SameLine = true
		else
			self:RenderDisplayWindow(race, parent)
		end
	elseif statType == "ParentGuid" then
		ResourceManager:RenderDisplayableValue(parent, raceId)
	end
end
