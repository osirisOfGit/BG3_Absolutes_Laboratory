CharacterWindow = {}

---@param parent ExtuiTreeParent
---@param id string
function CharacterWindow:BuildWindow(parent, id)
	local displayTable = parent:AddTable("characterDisplayWindow", 3)
	displayTable:AddColumn("", "WidthStretch")
	displayTable:AddColumn("", "WidthFixed", 300)
	displayTable:AddColumn("", "WidthStretch")

	local row = displayTable:AddRow()
	row:AddCell()
	local displayCell = row:AddCell()
	row:AddCell()

	---@type EntityHandle
	local entity = Ext.Entity.Get(id)

	if entity then
		Styler:MiddleAlignedColumnLayout(displayCell, function(ele)
			Channels.GetEntityIcon:RequestToServer({
				target = id
			}, function(data)
				ele:AddImage(data.Result, { 128, 128 })
			end)
		end)

		Styler:CheapTextAlign(CharacterIndex.displayNameMappings[id], displayCell, "Big")

		local tabBar = parent:AddTabBar("Tabs")

		local entityTab = tabBar:AddTabItem("Entity")
		local statTab = tabBar:AddTabItem("Stat")
		local templateTab = tabBar:AddTabItem("Template")
		entityTab.OnActivate = function()
			Helpers:KillChildren(statTab, templateTab)
			Helpers:ForceGarbageCollection("swapping to entity view for " .. CharacterIndex.displayNameMappings[id])
			EntityManager:RenderDisplayWindow(entity, entityTab)
		end

		statTab.OnActivate = function()
			Helpers:KillChildren(entityTab, templateTab)
			Helpers:ForceGarbageCollection("swapping to stat view for " .. CharacterIndex.displayNameMappings[id])

			Channels.GetEntityStat:RequestToServer({ target = id }, function(data)
				if data.Result then
					local stat = Ext.Stats.Get(data.Result)
					if stat then
						ResourceManager:RenderDisplayWindow(stat, statTab)
					end
				end
			end)
		end

		templateTab.OnActivate = function()
			Helpers:KillChildren(statTab, entityTab)
			Helpers:ForceGarbageCollection("swapping to template view for " .. CharacterIndex.displayNameMappings[id])

			local template = entity.ClientCharacter.Template
			if template then
				ResourceManager:RenderDisplayWindow(template, templateTab)
			end
		end

		entityTab:Activate()
	else
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
		end
	end
end
