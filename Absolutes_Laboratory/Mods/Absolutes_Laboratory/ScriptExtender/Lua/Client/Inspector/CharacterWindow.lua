CharacterWindow = {}

---@param parent ExtuiTreeParent
---@param id string
function CharacterWindow:BuildWindow(parent, id)
	local group = parent:AddGroup("CharacterWindow")
	local displayTable = group:AddTable("characterDisplayWindow", 3)
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
				local image = ele:AddImage(data.Result, { 128, 128 })
				if image.ImageData.Icon == "" then
					image:Destroy()
					ele:AddImage("Item_Unknown", { 128, 128 })
				end
			end)
		end)

		Styler:CheapTextAlign((entity.DisplayName and entity.DisplayName.Name:Get()) or entity.ClientCharacter.Template.DisplayName:Get() or entity.ClientCharacter.Template.Name,
			displayCell, "Big")

		local tabBar = group:AddTabBar("Tabs")

		local entityTab = tabBar:AddTabItem("Entity")
		local statTab = tabBar:AddTabItem("Stat")
		local templateTab = tabBar:AddTabItem("Template")
		entityTab.OnActivate = function()
			Helpers:KillChildren(statTab, templateTab)
			EntityManager:RenderDisplayWindow(entity, entityTab)
		end

		statTab.OnActivate = function()
			Helpers:KillChildren(entityTab, templateTab)

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

			local template = entity.ClientCharacter.Template
			if template then
				ResourceManager:RenderDisplayWindow(template, templateTab)
			end
		end

		if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS] then
			local mutationTab = tabBar:AddTabItem("Mutations")
			mutationTab.OnActivate = function()
				Helpers:KillChildren(mutationTab)

				---@type MutatorEntityVar
				local entityVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS]

				local displayTable = Styler:TwoColumnTable(mutationTab)
				for targetProperty in TableUtils:OrderedPairs(entityVar.appliedMutators) do
					local row = displayTable:AddRow()
					row:AddCell():AddText(targetProperty)

					local displayCell = row:AddCell()

					local appliedMutators = Styler:TwoColumnTable(displayCell, "appliedMutators" .. targetProperty)
					local aMRow = appliedMutators:AddRow()
					aMRow:AddCell():AddText("Applied Mutators")
					Styler:SimpleRecursiveTwoColumnTable(aMRow:AddCell(), entityVar.appliedMutators[targetProperty])

					local appliedMutatorRules = Styler:TwoColumnTable(displayCell, "appliedMutatorRules" .. targetProperty)
					local aMRRow = appliedMutatorRules:AddRow()
					aMRRow:AddCell():AddText("Applied Mutator Rules")
					Styler:SimpleRecursiveTwoColumnTable(aMRRow:AddCell(), entityVar.appliedMutatorsPath[targetProperty])

					local originalValue = Styler:TwoColumnTable(displayCell, "originalValues" .. targetProperty)
					local oVRow = originalValue:AddRow()
					oVRow:AddCell():AddText("Original Values")
					if type(entityVar.originalValues[targetProperty]) == "table" then
						Styler:SimpleRecursiveTwoColumnTable(oVRow:AddCell(), entityVar.originalValues[targetProperty])
					else
						oVRow:AddCell():AddText(tostring(entityVar.originalValues[targetProperty]))
					end
				end
			end
		end

		entityTab:Activate()
		return
	else
		local entityLevel = EntityRecorder:GetLevelForEntity(id)
		if entityLevel then
			Styler:MiddleAlignedColumnLayout(displayCell, function(ele)
				ele:AddButton("Teleport To Level").OnClick = function()
					Channels.TeleportToLevel:SendToServer({
						LevelName = entityLevel,
						Id = id
					})

					local sub
					sub = Ext.Events.GameStateChanged:Subscribe(function(e)
						---@cast e EclLuaGameStateChangedEvent
						if e.ToState == "Running" then
							Ext.Events.GameStateChanged:Unsubscribe(sub)
							Helpers:KillChildren(group)
							self:BuildWindow(parent, id)
						end
					end)
				end
			end)
		end
	end

	local entityRecord = EntityRecorder:GetEntity(id)
	---@type CharacterTemplate
	local characterTemplate = entityRecord and Ext.Template.GetRootTemplate(entityRecord.Template) or Ext.Template.GetRootTemplate(id)

	if characterTemplate then
		Styler:MiddleAlignedColumnLayout(displayCell, function(ele)
			local image = ele:AddImage(characterTemplate.Icon, { 128, 128 })
			if image.ImageData.Icon == "" then
				image:Destroy()
				ele:AddImage("Item_Unknown", { 128, 128 })
			end
		end)

		Styler:CheapTextAlign(entityRecord and entityRecord.Name or characterTemplate.DisplayName:Get() or characterTemplate.Name, displayCell, "Big")
		Styler:CheapTextAlign(characterTemplate.LevelName, displayCell)

		local tabBar = group:AddTabBar("Tabs")

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
