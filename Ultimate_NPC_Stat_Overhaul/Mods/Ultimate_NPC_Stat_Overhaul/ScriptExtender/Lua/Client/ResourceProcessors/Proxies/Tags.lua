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

---@param tags string[]
function TagsProxy:RenderDisplayableValue(parent, tags)
	for _, tagId in ipairs(tags) do
		---@type ResourceTag?
		local tag = Ext.StaticData.Get(tagId, "Tag")

		if tag then
			CharacterIndex.displayNameMappings[tag] = tag.DisplayName:Get() or tag.Name

			local hasKids = #parent.Children > 0
			local tagText = Styler:HyperlinkText(parent:AddText(tag.DisplayName:Get() or tag.Name))
			tagText.SameLine = hasKids;
			self:RenderDisplayWindow(tag, tagText:Tooltip())

			parent:AddText(self.delimeter).SameLine = true
		end
	end
end
