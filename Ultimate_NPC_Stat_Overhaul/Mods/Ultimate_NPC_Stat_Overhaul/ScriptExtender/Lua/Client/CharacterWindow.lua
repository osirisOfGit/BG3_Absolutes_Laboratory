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
		Styler:MiddleAlignedColumnLayout(displayCell, function(ele)
			ele:AddImage(characterTemplate.Icon, { 128, 128 })
		end)

		Styler:CheapTextAlign(CharacterIndex.displayNameMappings[templateId], displayCell, "Big")
		Styler:CheapTextAlign(characterTemplate.LevelName, displayCell)

		local tabBar = parent:AddTabBar("Tabs")

		local templateTab = tabBar:AddTabItem("Template")
		StatManager:RenderDisplayWindow(characterTemplate, templateTab)

		if characterTemplate.Stats and characterTemplate.Stats ~= "" then
			local statTab = tabBar:AddTabItem("Stats")
			---@type Character
			local characterStat = Ext.Stats.Get(characterTemplate.Stats)

			if characterStat then
				StatManager:RenderDisplayWindow(characterStat, statTab)
			end
		end
	end
end
