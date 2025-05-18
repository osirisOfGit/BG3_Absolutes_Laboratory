XPRewardProxy = ResourceProxy:new()

XPRewardProxy.fieldsToParse = {
	"LevelSource",
	"Name",
	"PerLevelRewards",
	"RewardType",
}

ResourceProxy:RegisterResourceProxy("XPReward", XPRewardProxy)
ResourceProxy:RegisterResourceProxy("resource::ExperienceRewards", XPRewardProxy)

---@param xpRewardId string
function XPRewardProxy:RenderDisplayableValue(parent, xpRewardId, statType)
	---@type ResourceExperienceRewards?
	local xpReward = type(xpRewardId) == "string" and Ext.StaticData.Get(xpRewardId, "ExperienceReward") or xpRewardId

	if xpReward then
		CharacterIndex.displayNameMappings[xpReward] = xpReward.Name

		local hasKids = #parent.Children > 0
		local tagText = Styler:HyperlinkText(parent, xpReward.Name, function(parent)
			self:RenderDisplayWindow(xpReward, parent)
		end)

		tagText.SameLine = hasKids;

		parent:AddText(self.delimeter).SameLine = true
	end
end
