Ext.Require("Client/Inspector/CharacterWindow.lua")
Ext.Require("Client/Inspector/ResourceProcessors/ResourceProxy.lua")
Ext.Require("Client/Inspector/EntityProcessors/EntityProxy.lua")

CharacterInspector = {
	---@type ExtuiTreeParent
	parent = nil,
	---@type ExtuiChildWindow
	selectionTreeCell = nil,
	---@type ExtuiChildWindow
	configCell = nil,
	---@type ExtuiProgressBar
	progressBar = nil,
	---@type "template"|"entities"
	typeToPopulate = "template"
}


Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Inspector",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		CharacterInspector.parent = tabHeader

		EntityRecorder:BuildButton(tabHeader)

		CharacterInspector.selectionTreeCell = tabHeader:AddChildWindow("selectionTree")
		CharacterInspector.selectionTreeCell.ChildAlwaysAutoResize = true
		CharacterInspector.selectionTreeCell.Size = { 400 * Styler:ScaleFactor(), 0 }

		CharacterInspector.configCell = tabHeader:AddChildWindow("configCell")
		CharacterInspector.configCell.AlwaysHorizontalScrollbar = true
		CharacterInspector.configCell.SameLine = true
		CharacterInspector.configCell.NoSavedSettings = true
		CharacterInspector.configCell.AlwaysAutoResize = true
		CharacterInspector.configCell.ChildAlwaysAutoResize = true

		CharacterInspector:buildOutTree()
	end
)

---@type ExtuiSelectable?
local selectedSelectable

---@type string?
local lastLevelName
function CharacterInspector.buildOutTree()
	local self = CharacterInspector

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
			selectable:SetColor("Text", Styler:ConvertRGBAToIMGUI({1, 1, 1, 0.5}))
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
