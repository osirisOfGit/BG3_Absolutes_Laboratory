Ext.Require("Client/Inspector/CharacterWindow.lua")
Ext.Require("Client/Inspector/ResourceProcessors/ResourceProxy.lua")
Ext.Require("Client/Inspector/EntityProcessors/EntityProxy.lua")

CharacterInspector = {
	---@type ExtuiTreeParent
	parent = nil,
	---@type ExtuiWindow?
	window = nil,
	---@type ExtuiChildWindow
	selectionTreeCell = nil,
	---@type ExtuiChildWindow
	configCell = nil,
	---@type ExtuiProgressBar
	progressBar = nil,
	---@type "template"|"entities"
	typeToPopulate = "template"
}

function CharacterInspector:LaunchIndependentWindow()
	if not self.window then
		self.window = Ext.IMGUI.NewWindow("Absolute's Laboratory - Inspector")
		self.window.Closeable = true
		self.window:SetStyle("WindowMinSize", 300 * Styler:ScaleFactor(), 500 * Styler:ScaleFactor())
		self.window.OnClose = function()
			if self.parent then
				for _, child in pairs(self.window.Children) do
					self.window:DetachChild(child)
					self.parent:AttachChild(child)
				end
			end
		end
	else
		self.window.Open = true
		self.window:SetFocus()
	end

	if not self.selectionTreeCell then
		self:init(self.window)
		self:buildOutTree()
	else
		if self.selectionTreeCell.ParentElement ~= self.window then
			for _, child in pairs(self.parent.Children) do
				self.parent:DetachChild(child)
				self.window:AttachChild(child)
			end
		end
	end
end

---@param parent ExtuiTreeParent
function CharacterInspector:init(parent)
	self.parent = parent

	EntityRecorder:BuildButton(parent)

	local searchButton = parent:AddButton("Search Entities (?)")
	searchButton:Tooltip():AddText("\t Click to toggle the Search section - closing a section will clear all filters, but your current selected entity will be preserved")
	searchButton.SameLine = true
	local searchGroup = parent:AddGroup("Search Section")
	searchGroup.Visible = false
	searchButton.OnClick = function()
		if searchGroup.Visible then
			searchGroup.Visible = false
			Helpers:KillChildren(searchGroup)
			self:buildOutTree()
		else
			searchGroup.Visible = true
			self:searchSection(searchGroup)
		end
	end

	self.selectionTreeCell = parent:AddChildWindow("selectionTree")
	self.selectionTreeCell.ChildAlwaysAutoResize = true
	self.selectionTreeCell.Size = { 400 * Styler:ScaleFactor(), 0 }

	self.configCell = parent:AddChildWindow("configCell")
	self.configCell.AlwaysHorizontalScrollbar = true
	self.configCell.SameLine = true
	self.configCell.NoSavedSettings = true
	self.configCell.AlwaysAutoResize = true
	self.configCell.ChildAlwaysAutoResize = true

	self:buildOutTree()
end

---@param parent ExtuiTreeParent
function CharacterInspector:searchSection(parent)
	local clearResultsButton = parent:AddButton("Clear Results and Filters")
	clearResultsButton:Tooltip():AddText("\t Clicking the Search button will also do this, and hide this section")
	clearResultsButton.Visible = false

	local pickEntityButton = Styler:ImageButton(parent:AddImageButton("PickBaseCoords", "Spell_Divination_TrueStrike", Styler:ScaleFactor({ 48, 48 })))
	pickEntityButton.SameLine = clearResultsButton.Visible
	pickEntityButton:Tooltip():AddText(
		"\t After clicking this button, press any button on your mouse while hovering over an entity to show them in the Inspector. Hovering will prefill the filter fields.")

	local searchTable = Styler:TwoColumnTable(parent, "Search")
	searchTable.Resizable = false
	searchTable.Borders = false

	clearResultsButton.OnClick = function()
		for _, rowChild in pairs(searchTable.Children) do
			for _, cellChild in pairs(rowChild.Children) do
				for _, inputEle in pairs(cellChild.Children) do
					if inputEle.UserData then
						inputEle.Text = ""
					end
				end
			end
		end

		self:buildOutTree()
	end

	local row = searchTable:AddRow()

	local timer
	local function filterRecords()
		if timer then
			Ext.Timer.Cancel(timer)
		end
		timer = Ext.Timer.WaitFor(300, function()
			---@type InspectorFilter
			local filters = {}

			for _, rowChild in pairs(searchTable.Children) do
				for _, cellChild in pairs(rowChild.Children) do
					for _, inputEle in pairs(cellChild.Children) do
						---@cast inputEle ExtuiInputText
						if inputEle.UserData and #inputEle.Text > 1 then
							filters[inputEle.UserData] = Helpers:SanitizeStringForFind(inputEle.Text:lower())
						end
					end
				end
			end

			if next(filters) then
				clearResultsButton.Visible = true
				self:buildOutTree(filters)
			else
				clearResultsButton.Visible = false
				self:buildOutTree()
			end
			pickEntityButton.SameLine = clearResultsButton.Visible
			timer = nil
		end)
	end


	pickEntityButton.OnClick = function()
		local lastEntity
		local tickSub = Ext.Events.Tick:Subscribe(function(e)
			local entity = Ext.ClientUI.GetPickingHelper(1).Inner.Inner[1].GameObject
			if entity and entity.ClientCharacter then
				if lastEntity ~= entity.Uuid.EntityUuid
					and not entity.Vars.AbsolutesLaboratory_MonsterLab_Entity
					and EntityRecorder:GetEntity(entity.Uuid.EntityUuid)
				then
					lastEntity = entity.Uuid.EntityUuid
					local entityRecord = EntityRecorder:GetEntity(entity.Uuid.EntityUuid)

					for _, rowChild in pairs(searchTable.Children) do
						for _, cellChild in pairs(rowChild.Children) do
							for _, inputEle in pairs(cellChild.Children) do
								if inputEle.UserData then
									inputEle.Text = entityRecord[inputEle.UserData]
								end
							end
						end
					end
				end
			else
				if lastEntity then
					for _, rowChild in pairs(searchTable.Children) do
						for _, cellChild in pairs(rowChild.Children) do
							for _, inputEle in pairs(cellChild.Children) do
								if inputEle.UserData then
									inputEle.Text = ""
								end
							end
						end
					end
					lastEntity = nil
				end
			end
		end)

		local mouseSub
		mouseSub = Ext.Events.MouseButtonInput:Subscribe(
		---@param e EclLuaMouseButtonEvent
			function(e)
				if e.Pressed then
					Ext.Events.Tick:Unsubscribe(tickSub)
					Ext.Events.MouseButtonInput:Unsubscribe(mouseSub)
					if lastEntity then
						self:buildOutTree({
							Id = Helpers:SanitizeStringForFind(lastEntity):lower()
						})
					end
				end
			end)
	end

	row:AddCell():AddText("Display Name")
	local nameFilter = row:AddCell():AddInputText("##name")
	nameFilter.SameLine = true
	nameFilter.UserData = "Name"
	nameFilter.OnChange = filterRecords

	row:AddCell():AddText("Entity UUID")
	local uuidFilter = row:AddCell():AddInputText("##uuid")
	uuidFilter.SameLine = true
	uuidFilter.UserData = "Id"
	uuidFilter.OnChange = filterRecords

	row:AddCell():AddText("Character Template (?)"):Tooltip():AddText("Can specify the UUID or the internal name (not the display name)")
	local templateFilter = row:AddCell():AddInputText("##template")
	templateFilter.SameLine = true
	templateFilter.UserData = "Template"
	templateFilter.OnChange = filterRecords

	row:AddCell():AddText("Character Stat Name")
	local statFilter = row:AddCell():AddInputText("##stat")
	statFilter.SameLine = true
	statFilter.UserData = "Stat"
	statFilter.OnChange = filterRecords

	row:AddCell():AddText("Race (?)"):Tooltip():AddText("Can specify the UUID or the internal name (not the display name)")
	local raceFilter = row:AddCell():AddInputText("##race")
	raceFilter.SameLine = true
	raceFilter.UserData = "Race"
	raceFilter.OnChange = filterRecords

	row:AddCell():AddText("Combat Group UUID")
	local combatGroup = row:AddCell():AddInputText("##combatGroup")
	combatGroup.SameLine = true
	combatGroup.UserData = "CombatGroupId"
	combatGroup.OnChange = filterRecords
end

---@type ExtuiSelectable?
local selectedSelectable

---@type string?
local lastLevelName

---@class InspectorFilter
---@field Name string?
---@field Id string?
---@field Stat string?
---@field Template string?
---@field Race string?
---@field CombatGroupId string?

---@param filter InspectorFilter?
function CharacterInspector:buildOutTree(filter)
	local selectedID = selectedSelectable and selectedSelectable.UserData
	selectedSelectable = nil
	Helpers:KillChildren(self.selectionTreeCell)

	local universalSelection = self.selectionTreeCell:AddTree("Levels")
	universalSelection.NoAutoOpenOnLog = true

	---@param parent ExtuiTree
	---@param id GUIDSTRING
	---@param displayName string
	local function buildSelectable(parent, id, displayName)
		---@type ExtuiSelectable
		local selectable = parent:AddSelectable(string.format("%s (%s)",
			displayName,
			string.sub(id, #id - 5)))

		selectable.UserData = id

		selectable.OnClick = function()
			if selectedSelectable then
				selectedSelectable.Selected = false
			end
			selectedSelectable = selectable

			lastLevelName = parent.Label

			Helpers:KillChildren(self.configCell)

			self.configCell:SetScroll({ 0, 0 })
			CharacterWindow:BuildWindow(self.configCell, selectable.UserData)
		end

		local newlyScannedEntities = EntityRecorder.newlyScannedEntities[next(EntityRecorder.newlyScannedEntities)]
		if newlyScannedEntities and newlyScannedEntities[id] then
			selectable:SetColor("Text", Styler:ConvertRGBAToIMGUI({ 1, 1, 1, 0.5 }))
			selectable:Tooltip():AddText("\t Picked up from the Created Entities Scan")
		end

		if id == selectedID then
			selectable.Selected = true
			selectable:OnClick()
		end
	end

	for levelName, entities in pairs(EntityRecorder:GetEntities()) do
		local levelTree = universalSelection:AddTree(levelName)

		levelTree.OnExpand = function()
			lastLevelName = levelName
			for entityId in TableUtils:OrderedPairs(entities, function(key)
				return entities[key].Name
			end, function(key, record)
				if filter then
					for filterKey, filterValue in pairs(filter) do
						if not record[filterKey]:lower():find(filterValue) then
							---@type string?
							local newValue
							if filterKey == "Template" then
								---@type CharacterTemplate
								local charTemplate = Ext.Template.GetTemplate(record.Template)
								if charTemplate then
									newValue = charTemplate.Name
								end
							elseif filterKey == "Race" then
								---@type ResourceRace
								local race = Ext.StaticData.Get(record.Race, "Race")
								if race then
									newValue = race.Name
								end
							end

							if newValue and newValue:lower():find(filterValue) then
								goto continue
							end
							return false
						end
						::continue::
					end
				end
				return true
			end) do
				buildSelectable(levelTree, entityId, entities[entityId].Name)
			end

			if #levelTree.Children == 0 then
				levelTree.Visible = false
			end
		end

		levelTree.OnCollapse = function()
			Helpers:KillChildren(levelTree)
			selectedSelectable = nil
		end

		levelTree:SetOpen(filter ~= nil or levelName == lastLevelName, "Always")
		if filter or levelName == lastLevelName then
			levelTree:OnExpand()
		end
	end
end

if Ext.Mod.IsModLoaded("755a8a72-407f-4f0d-9a33-274ac0f0b53d") then
	Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Inspector",
		--- @param tabHeader ExtuiTreeParent
		function(tabHeader)
			CharacterInspector:init(tabHeader)
		end
	)

	MCM.SetKeybindingCallback('LaunchInspector', function(e)
		CharacterInspector:LaunchIndependentWindow()
	end)
else
	--- Thanks Scribe!
	Ext.Events.KeyInput:Subscribe(
	---@param e EclLuaKeyInputEvent
		function(e)
			if e.Event == "KeyDown" and e.Repeat == false then
				local lshift, lalt = Ext.Enums.SDLKeyModifier.LShift, Ext.Enums.SDLKeyModifier.LAlt
				if e.Key == "A" and e.Modifiers & lshift == lshift and e.Modifiers & lalt == lalt then
					CharacterInspector:LaunchIndependentWindow()
				end
			end
		end)
end
