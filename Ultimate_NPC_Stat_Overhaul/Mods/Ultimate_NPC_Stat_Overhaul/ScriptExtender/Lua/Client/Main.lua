Ext.Require("Client/CharacterWindow.lua")
Ext.Require("Client/ResourceProcessors/ResourceProxy.lua")

Main = {
	---@type ExtuiTreeParent
	parent = nil,
	---@type ExtuiChildWindow
	selectionTreeCell = nil,
	---@type ExtuiChildWindow
	configCell = nil,
	---@type ExtuiProgressBar
	progressBar = nil
}

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Configuration",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		Main.parent = tabHeader

		---@type ExtuiProgressBar
		Main.progressBar = tabHeader:AddProgressBar()
		Main.progressBar.Visible = false

		Main.displayTable = tabHeader:AddTable("allConfigs", 2)
		Main.displayTable:AddColumn("", "WidthFixed")
		Main.displayTable:AddColumn("", "WidthStretch")

		local row = Main.displayTable:AddRow()

		Main.selectionTreeCell = row:AddCell()

		Main.configCell = row:AddCell()
		-- Main.configCell.AlwaysAutoResize = true
		-- Main.configCell.ChildAlwaysAutoResize = true
		-- Main.configCell.NoSavedSettings = true
	end
)

local hasBeenActivated = false

Ext.ModEvents.BG3MCM["MCM_Mod_Tab_Activated"]:Subscribe(function(payload)
	if not hasBeenActivated then
		-- Mod variables load in after the InsertModMenuTab function runs
		if ModuleUUID == payload.modUUID then
			hasBeenActivated = true
			Main.progressBar.Visible = true

			local function doIt(func, secondFunc)
				local percentageComplete = func()
				if percentageComplete then
					Main.progressBar.Value = percentageComplete
					Ext.Timer.WaitFor(1, function()
						doIt(func, secondFunc)
					end)
				elseif secondFunc then
					doIt(secondFunc)
				end
			end
			doIt(CharacterIndex:hydrateIndex(), Main.buildOutTree())
		end
	end
end)

---@type ExtuiSelectable
local selectedSelectable

---@return fun():number
function Main.buildOutTree()
	local self = Main

	local universalSelection = self.selectionTreeCell:AddTree("Acts")
	universalSelection.NoAutoOpenOnLog = true

	---@param parent ExtuiTree
	---@param template GUIDSTRING
	local function buildSelectable(parent, template)
		---@type ExtuiSelectable
		local selectable = parent:AddSelectable(string.format("%s (%s)",
			CharacterIndex.displayNameMappings[template],
			string.sub(template, #template - 5)))

		selectable.UserData = template

		selectable.OnClick = function()
			Helpers:KillChildren(self.configCell)
			CharacterWindow:BuildWindow(self.configCell, selectable.UserData)
		end
	end

	---@param parentTree ExtuiTree
	---@param templateMap {[string]: string[]}
	---@param templateSuperSet string[]
	local function buildTree(parentTree, templateMap, templateSuperSet)
		for resourceId, templates in TableUtils:OrderedPairs(templateMap, function(key)
			return CharacterIndex.displayNameMappings[key]
		end) do
			local resourceSelection = parentTree:AddTree(string.format("%s (%s)", (CharacterIndex.displayNameMappings[resourceId] or resourceId),
				string.sub(resourceId, #resourceId - 5)))
			resourceSelection:SetOpen(false, "Always")
			resourceSelection.UserData = resourceId
			resourceSelection.IDContext = resourceId .. parentTree.IDContext

			for _, resourceTemplate in TableUtils:OrderedPairs(templates, function(key)
				return CharacterIndex.displayNameMappings[templates[key]]
			end) do
				if TableUtils:ListContains(templateSuperSet, resourceTemplate) then
					buildSelectable(resourceSelection, resourceTemplate)
				end
			end
			if #resourceSelection.Children == 0 then
				resourceSelection:Destroy()
			end
		end
		if #parentTree.Children == 0 then
			parentTree:Destroy()
		end
	end

	return coroutine.wrap(function()
		self.progressBar.Value = 0
		local maxCount = TableUtils:CountElements(CharacterIndex.templates.acts)

		local count = 0
		local lastPercentage = 0

		for act, actTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.acts) do
			local actSelection = universalSelection:AddTree(act)
			actSelection:SetOpen(false, "Always")

			local parentRaceSelection = actSelection:AddTree("Races")
			parentRaceSelection.IDContext = act .. "Race"
			parentRaceSelection:SetOpen(false, "Always")
			buildTree(parentRaceSelection, CharacterIndex.templates.races, actTemplates)

			local parentProgressionTableSelection = actSelection:AddTree("Progression Tables")
			parentProgressionTableSelection:SetOpen(false, "Always")
			parentProgressionTableSelection.IDContext = "progression" .. act
			buildTree(parentProgressionTableSelection, CharacterIndex.templates.progressions, actTemplates)

			local parentFactionsSelection = actSelection:AddTree("Parent Factions")
			parentFactionsSelection:SetOpen(false, "Always")
			parentFactionsSelection.IDContext = "progression" .. act
			buildTree(parentFactionsSelection, CharacterIndex.templates.factions, actTemplates)

			count = count + 1

			if math.floor(((count / maxCount) * 100)) > lastPercentage then
				lastPercentage = math.floor(((count / maxCount) * 100))
				coroutine.yield(count / maxCount)
			end
		end

		self.progressBar.Visible = false
	end)
end
