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

		-- Main.displayTable = tabHeader:AddTable("allConfigs", 2)
		-- Main.displayTable:AddColumn("", "WidthFixed")
		-- Main.displayTable:AddColumn("", "WidthStretch")

		-- local row = Main.displayTable:AddRow()

		Main.selectionTreeCell = tabHeader:AddChildWindow("selectionTree")
		Main.selectionTreeCell.ChildAlwaysAutoResize = true
		Main.selectionTreeCell.Size = {300, 0 }

		Main.selectionTreeCell:AddText("Choose Grouping Method").UserData = "keep"
		Main.templateGroupingCombo = Main.selectionTreeCell:AddCombo("")
		Main.templateGroupingCombo.UserData = "keep"
		Main.templateGroupingCombo.SameLine = true
		Main.templateGroupingCombo.Options = {
			"None",
			"Faction",
			"Race",
			"Parent Progression Table"
		}
		Main.templateGroupingCombo.SelectedIndex = 0

		Main.templateGroupingCombo.OnChange = function()
			Main.progressBar.Visible = true
			Main.progressBar.Value = 0

			Helpers:KillChildren(Main.selectionTreeCell)
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
			doIt(Main.buildOutTree())
		end

		Main.configCell = tabHeader:AddChildWindow("configCell")
		Main.configCell.SameLine = true
		Main.configCell.NoSavedSettings = true
		Main.configCell.AlwaysAutoResize = true
		Main.configCell.ChildAlwaysAutoResize = true
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

	selectedSelectable = nil

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
			if selectedSelectable then
				selectedSelectable.Selected = false
			end
			selectedSelectable = selectable

			Helpers:KillChildren(self.configCell)
			CharacterWindow:BuildWindow(self.configCell, selectable.UserData)
			self.configCell.ResizeY = true
			self.configCell:SetScroll({ 0, 0 })
		end
	end

	---@param parentTree ExtuiTree
	---@param templateMap {[string]: string[]}
	---@param templateSuperSet string[]?
	---@param progressFunc fun()?
	local function buildTree(parentTree, templateMap, templateSuperSet, progressFunc)
		for resourceId, templates in TableUtils:OrderedPairs(templateMap, function(key)
			return CharacterIndex.displayNameMappings[key]
		end) do
			local resourceSelection
			if not templateSuperSet then
				resourceSelection = parentTree:AddTree(resourceId)
			else
				resourceSelection = parentTree:AddTree(string.format("%s (%s)", (CharacterIndex.displayNameMappings[resourceId] or resourceId),
					string.sub(resourceId, #resourceId - 5)))
			end
			resourceSelection:SetOpen(false, "Always")
			resourceSelection.UserData = resourceId
			resourceSelection.IDContext = resourceId .. parentTree.IDContext

			for _, resourceTemplate in TableUtils:OrderedPairs(templates, function(key)
				return CharacterIndex.displayNameMappings[templates[key]]
			end) do
				if not templateSuperSet or TableUtils:ListContains(templateSuperSet, resourceTemplate) then
					buildSelectable(resourceSelection, resourceTemplate)
				end
			end
			if #resourceSelection.Children == 0 then
				resourceSelection:Destroy()
			end
			if progressFunc then
				progressFunc()
			end
		end
		if #parentTree.Children == 0 then
			parentTree:Destroy()
		end
	end

	local parentOption = self.templateGroupingCombo.Options[self.templateGroupingCombo.SelectedIndex + 1]

	return coroutine.wrap(function()
		self.progressBar.Value = 0
		local maxCount = TableUtils:CountElements(CharacterIndex.templates.acts)

		local count = 0
		local lastPercentage = 0

		local func = function()
			count = count + 1

			if math.floor(((count / maxCount) * 100)) > lastPercentage then
				lastPercentage = math.floor(((count / maxCount) * 100))
				coroutine.yield(count / maxCount)
			end
		end
		if parentOption == "None" then
			buildTree(universalSelection, CharacterIndex.templates.acts, nil, func)
		else
			for act, actTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.acts) do
				local actSelection = universalSelection:AddTree(act)
				actSelection:SetOpen(false, "Always")

				if parentOption == "Race" then
					local parentRaceSelection = actSelection:AddTree("Races")
					parentRaceSelection.IDContext = act .. "Race"
					parentRaceSelection:SetOpen(false, "Always")
					buildTree(parentRaceSelection, CharacterIndex.templates.races, actTemplates)
				elseif parentOption == "Parent Progression Table" then
					local parentProgressionTableSelection = actSelection:AddTree("Progression Tables")
					parentProgressionTableSelection:SetOpen(false, "Always")
					parentProgressionTableSelection.IDContext = "progression" .. act
					buildTree(parentProgressionTableSelection, CharacterIndex.templates.progressions, actTemplates)
				else
					local parentFactionsSelection = actSelection:AddTree("Parent Factions")
					parentFactionsSelection:SetOpen(false, "Always")
					parentFactionsSelection.IDContext = "progression" .. act
					buildTree(parentFactionsSelection, CharacterIndex.templates.factions, actTemplates)
				end

				func()
			end
		end

		self.progressBar.Visible = false
	end)
end
