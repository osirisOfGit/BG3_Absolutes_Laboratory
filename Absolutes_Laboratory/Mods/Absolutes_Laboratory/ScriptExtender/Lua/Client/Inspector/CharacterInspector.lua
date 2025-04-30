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

		---@type ExtuiProgressBar
		Main.progressBar = tabHeader:AddProgressBar()
		Main.progressBar.Visible = false

		-- Main.displayTable = tabHeader:AddTable("allConfigs", 2)
		-- Main.displayTable:AddColumn("", "WidthFixed")
		-- Main.displayTable:AddColumn("", "WidthStretch")

		-- local row = Main.displayTable:AddRow()

		local tabs = tabHeader:AddTabBar("Main Tabs")

		local templateTab = tabs:AddTabItem("Templates")
		templateTab:Activate()

		local entityTab = tabs:AddTabItem("Entities")

		Main.selectionTreeCell = tabHeader:AddChildWindow("selectionTree")
		Main.selectionTreeCell.ChildAlwaysAutoResize = true
		Main.selectionTreeCell.Size = { 400 * Styler:ScaleFactor(), 0 }

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

		Main.configCell = tabHeader:AddChildWindow("configCell")
		Main.configCell.AlwaysHorizontalScrollbar = true
		Main.configCell.SameLine = true
		Main.configCell.NoSavedSettings = true
		Main.configCell.AlwaysAutoResize = true
		Main.configCell.ChildAlwaysAutoResize = true

		local function recomputeSelections()
			Main.progressBar.Visible = true
			Main.progressBar.Value = 0

			Helpers:KillChildren(Main.selectionTreeCell)
			Helpers:KillChildren(Main.configCell)

			Helpers:ForceGarbageCollection("swapping to viewing " .. Main.typeToPopulate)

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

		Main.templateGroupingCombo.OnChange = recomputeSelections

		templateTab.OnActivate = function()
			Main.typeToPopulate = "template"
			recomputeSelections()
		end

		entityTab.OnActivate = function()
			Main.typeToPopulate = "entities"
			recomputeSelections()
		end
	end
)

local hasBeenActivated = false

local function initiateScan()
	hasBeenActivated = true
	Main.progressBar.Visible = true

	local function doIt(...)
		local funcs = { ... }
		local currentFunc = table.remove(funcs, 1)

		if currentFunc then
			local percentageComplete = currentFunc()
			if percentageComplete then
				Main.progressBar.Value = percentageComplete
				Ext.Timer.WaitFor(1, function()
					doIt(currentFunc, table.unpack(funcs))
				end)
			else
				doIt(table.unpack(funcs))
			end
		else
			for i, entity in pairs(CharacterIndex.entities.entities) do
				Channels.IsEntityAlive:RequestToServer({ target = entity }, function(data)
					if not data.Result then
						CharacterIndex.entities.entities[i] = nil
					end
				end)
			end
		end
	end

	doIt(CharacterIndex:hydrateTemplateIndex(), CharacterIndex:hydrateEntityIndex(), Main.buildOutTree())
end

local sessionLoaded
local menuActivated

Ext.Events.SessionLoaded:Subscribe(function (e)
	sessionLoaded = true
	if menuActivated then
		Logger:BasicDebug("Session loaded after tab activated")
		initiateScan()
	end
end, {Once = true})

Ext.Events.ResetCompleted:Subscribe(function (e)
	sessionLoaded = true
	if menuActivated then
		Logger:BasicDebug("Session loaded after tab activated")
		initiateScan()
	end
end)

Ext.ModEvents.BG3MCM["MCM_Mod_Tab_Activated"]:Subscribe(function(payload)
	if not hasBeenActivated then
		if ModuleUUID == payload.modUUID then
			if not sessionLoaded then
				menuActivated = true
			else
				Logger:BasicDebug("Tab activated after session loaded")
				initiateScan()
			end
		end
	end
end)

---@type ExtuiSelectable
local selectedSelectable

---@return fun():number
function Main.buildOutTree()
	local self = Main

	selectedSelectable = nil

	local universalSelection = self.selectionTreeCell:AddTree(self.typeToPopulate == "template" and "Acts" or "Entities")
	universalSelection.NoAutoOpenOnLog = true

	---@param parent ExtuiTree
	---@param id GUIDSTRING
	local function buildSelectable(parent, id)
		---@type ExtuiSelectable
		local selectable = parent:AddSelectable(string.format("%s (%s)",
			CharacterIndex.displayNameMappings[id],
			string.sub(id, #id - 5)))

		selectable.UserData = id

		selectable.OnClick = function()
			if selectedSelectable then
				selectedSelectable.Selected = false
			end
			selectedSelectable = selectable

			Helpers:KillChildren(self.configCell)

			Helpers:ForceGarbageCollection("viewing new entity/template")

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
	local index = self.typeToPopulate == "template" and CharacterIndex.templates or CharacterIndex.entities

	return coroutine.wrap(function()
		self.progressBar.Value = 0
		local maxCount = TableUtils:CountElements(index.acts or index.entities)

		local count = 0
		local lastPercentage = 0

		local func = function()
			count = count + 1

			if math.floor(((count / maxCount) * 100)) > lastPercentage then
				lastPercentage = math.floor(((count / maxCount) * 100))
				coroutine.yield(count / maxCount)
			end
		end

		if self.typeToPopulate == "entities" then
			for _, entityId in TableUtils:OrderedPairs(index.entities, function(key)
				return CharacterIndex.displayNameMappings[index.entities[key]] or key
			end) do
				buildSelectable(universalSelection, entityId)
			end
		else
			if parentOption == "None" then
				buildTree(universalSelection, index.acts, nil, func)
			else
				for act, actTemplates in TableUtils:OrderedPairs(index.acts) do
					local actSelection = universalSelection:AddTree(act)
					actSelection:SetOpen(false, "Always")

					if parentOption == "Race" then
						local parentRaceSelection = actSelection:AddTree("Races")
						parentRaceSelection.IDContext = act .. "Race"
						parentRaceSelection:SetOpen(false, "Always")
						buildTree(parentRaceSelection, index.races, actTemplates)
					elseif parentOption == "Parent Progression Table" then
						local parentProgressionTableSelection = actSelection:AddTree("Progression Tables")
						parentProgressionTableSelection:SetOpen(false, "Always")
						parentProgressionTableSelection.IDContext = "progression" .. act
						buildTree(parentProgressionTableSelection, index.progressions, actTemplates)
					else
						local parentFactionsSelection = actSelection:AddTree("Parent Factions")
						parentFactionsSelection:SetOpen(false, "Always")
						parentFactionsSelection.IDContext = "progression" .. act
						buildTree(parentFactionsSelection, index.factions, actTemplates)
					end

					func()
				end
			end
		end

		self.progressBar.Visible = false
	end)
end
