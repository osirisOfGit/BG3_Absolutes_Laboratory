CharacterWindow = {}

---@param parent ExtuiTreeParent
---@param templateId string
function CharacterWindow:BuildWindow(parent, templateId)
	local displayTable = parent:AddTable("characterDisplayWindow", 3)
	displayTable:AddColumn("", "WidthStretch")
	displayTable:AddColumn("", "WidthFixed")
	displayTable:AddColumn("", "WidthStretch")

	local row = displayTable:AddRow()
	row:AddCell()
	local displayCell = row:AddCell()
	row:AddCell()

	---@type CharacterTemplate
	local characterTemplate = Ext.Template.GetRootTemplate(templateId)

	if characterTemplate then
		Styler:CheapTextAlign(CharacterIndex.displayNameMappings[templateId], displayCell, "Big")
		Styler:CheapTextAlign(string.gsub(characterTemplate.FileName, "^.*[\\/]Mods[\\/]", ""), displayCell)
		Styler:MiddleAlignedColumnLayout(displayCell, function (ele)
			ele:AddImage(characterTemplate.Icon, {128, 128})
		end)
	end
end
