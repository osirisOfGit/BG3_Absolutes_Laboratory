XPRewardProxy = ResourceProxy:new()

XPRewardProxy.fieldsToParse = {
	"LevelSource",
	"Name",
	"PerLevelRewards",
	"RewardType",
}

ResourceProxy:RegisterResourceProxy("XPReward", XPRewardProxy)

---@param xpRewardId string
function XPRewardProxy:RenderDisplayableValue(parent, xpRewardId, statType)
	---@type ResourceExperienceRewards?
	local xpReward = Ext.StaticData.Get(xpRewardId, "ExperienceReward")

	if xpReward then
		CharacterIndex.displayNameMappings[xpReward] = xpReward.Name

		local hasKids = #parent.Children > 0
		local tagText = Styler:HyperlinkText(parent:AddText(xpReward.Name))
		tagText.SameLine = hasKids;
		self:RenderDisplayWindow(xpReward, tagText:Tooltip())

		parent:AddText(self.delimeter).SameLine = true
	end
end
