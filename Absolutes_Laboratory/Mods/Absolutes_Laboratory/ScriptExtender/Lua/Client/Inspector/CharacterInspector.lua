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

function CharacterInspector:init(parent)
	self.parent = parent

	EntityRecorder:BuildButton(parent)

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

---@type ExtuiSelectable?
local selectedSelectable

---@type string?
local lastLevelName
function CharacterInspector:buildOutTree()
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
			end) do
				buildSelectable(levelTree, entityId, entities[entityId].Name)
			end
		end

		levelTree.OnCollapse = function()
			Helpers:KillChildren(levelTree)
			selectedSelectable = nil
		end

		levelTree:SetOpen(levelName == lastLevelName, "Always")
		if levelName == lastLevelName then
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
