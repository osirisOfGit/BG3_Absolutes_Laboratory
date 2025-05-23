TagsProxy = ResourceProxy:new()

TagsProxy.fieldsToParse = {
	"Categories",
	"Description",
	"DisplayDescription",
	"DisplayName",
	"Icon",
	"Name",
	"Properties",
}

ResourceProxy:RegisterResourceProxy("Tags", TagsProxy)
ResourceProxy:RegisterResourceProxy("Tag", TagsProxy)
ResourceProxy:RegisterResourceProxy("ServerBoostTag", TagsProxy)
ResourceProxy:RegisterResourceProxy("resource::Tag", TagsProxy)

---@param tags string[]
function TagsProxy:RenderDisplayableValue(parent, tags, statType)
	for _, tagId in ipairs(tags) do
		---@type ResourceTag?
		local tag = Ext.StaticData.Get(tagId, "Tag")

		if tag then
			local hasKids = #parent.Children > 0
			local tagText = Styler:HyperlinkText(parent, tag.DisplayName:Get() or tag.Name, function (parent)
				self:RenderDisplayWindow(tag, parent)
			end)
			tagText.SameLine = hasKids;

			parent:AddText(self.delimeter).SameLine = true
		end
	end
end
