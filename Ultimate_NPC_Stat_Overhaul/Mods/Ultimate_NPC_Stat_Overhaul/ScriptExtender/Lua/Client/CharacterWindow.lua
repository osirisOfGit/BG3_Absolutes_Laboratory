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
		displayCell:AddText(string.gsub(characterTemplate.FileName, "^.*[\\/]Mods[\\/]", ""))
	end
end
