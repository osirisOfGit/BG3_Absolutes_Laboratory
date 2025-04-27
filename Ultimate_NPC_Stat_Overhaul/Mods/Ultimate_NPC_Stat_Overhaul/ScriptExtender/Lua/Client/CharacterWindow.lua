CharacterWindow = {}

---@param parent ExtuiTreeParent
---@param id string
function CharacterWindow:BuildWindow(parent, id)
	local displayTable = parent:AddTable("characterDisplayWindow", 3)
	displayTable:AddColumn("", "WidthStretch")
	displayTable:AddColumn("", "WidthFixed")
	displayTable:AddColumn("", "WidthStretch")

	local row = displayTable:AddRow()
	row:AddCell()
	local displayCell = row:AddCell()
	row:AddCell()

	---@type CharacterTemplate
	local characterTemplate = Ext.Template.GetRootTemplate(id)

	if characterTemplate then
		Styler:MiddleAlignedColumnLayout(displayCell, function(ele)
			ele:AddImage(characterTemplate.Icon, { 128, 128 })
		end)

		Styler:CheapTextAlign(CharacterIndex.displayNameMappings[id], displayCell, "Big")
		Styler:CheapTextAlign(characterTemplate.LevelName, displayCell)

		local tabBar = parent:AddTabBar("Tabs")

		local templateTab = tabBar:AddTabItem("Template")
		ResourceManager:RenderDisplayWindow(characterTemplate, templateTab)

		if characterTemplate.Stats and characterTemplate.Stats ~= "" then
			local statTab = tabBar:AddTabItem("Stats")
			---@type Character
			local characterStat = Ext.Stats.Get(characterTemplate.Stats)

			if characterStat then
				ResourceManager:RenderDisplayWindow(characterStat, statTab)
			end
		end
	else
		local entity = Ext.Entity.Get(id)

		Styler:MiddleAlignedColumnLayout(displayCell, function(ele)
			Channels.GetEntityIcon:RequestToServer({
				target = id
			}, function (data)
				ele:AddImage(data.Result, { 128, 128 })
			end)
		end)

		Styler:CheapTextAlign(CharacterIndex.displayNameMappings[id], displayCell, "Big")

		EntityManager:RenderDisplayWindow(entity, parent)
	end
end
