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
	if type(tags) ~= "table" and tags ~= "" then
		tags = { tags }
	end
	if #tags >= 10 then
		parent = parent:AddCollapsingHeader("Tags")
		parent:SetColor("Header", { 1, 1, 1, 0 })
	end
	for _, tagId in ipairs(tags) do
		---@type ResourceTag?
		local tag = Ext.StaticData.Get(tagId, "Tag")

		if tag then
			Styler:HyperlinkText(parent, tag.DisplayName:Get() ~= "" and tag.DisplayName:Get() or tag.Name, function(parent)
				ResourceManager:RenderDisplayWindow(tag, parent)
			end)
		else
			parent:AddText(tagId)
		end
	end
end
