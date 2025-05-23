Ext.Require("Client/Inspector/CharacterWindow.lua")
Ext.Require("Client/Inspector/ResourceProcessors/ResourceProxy.lua")
Ext.Require("Client/Inspector/EntityProcessors/EntityProxy.lua")

Main = {
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
		Main.parent = tabHeader

		EntityRecorder:BuildButton(tabHeader)

		Main.selectionTreeCell = tabHeader:AddChildWindow("selectionTree")
		Main.selectionTreeCell.ChildAlwaysAutoResize = true
		Main.selectionTreeCell.Size = { 400 * Styler:ScaleFactor(), 0 }

		Main.configCell = tabHeader:AddChildWindow("configCell")
		Main.configCell.AlwaysHorizontalScrollbar = true
		Main.configCell.SameLine = true
		Main.configCell.NoSavedSettings = true
		Main.configCell.AlwaysAutoResize = true
		Main.configCell.ChildAlwaysAutoResize = true

		Main:buildOutTree()
	end
)

---@type ExtuiSelectable?
local selectedSelectable

function Main.buildOutTree()
	local self = Main

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

			CharacterWindow:BuildWindow(self.configCell, selectable.UserData)
		end
	end

	for levelName, entities in pairs(EntityRecorder:GetEntities()) do
		local levelTree = universalSelection:AddTree(levelName)
		levelTree:SetOpen(false, "Always")

		levelTree.OnExpand = function()
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
	end
end
