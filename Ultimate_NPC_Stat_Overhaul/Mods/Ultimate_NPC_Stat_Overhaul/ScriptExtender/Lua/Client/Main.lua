Ext.Require("Client/CharacterWindow.lua")

Main = {
	---@type ExtuiTreeParent
	parent = nil,
	---@type ExtuiTableCell
	selectionTreeCell = nil,
	---@type ExtuiTableCell
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

		local displayTable = tabHeader:AddTable("allConfigs", 2)
		displayTable:AddColumn("", "WidthFixed")
		displayTable:AddColumn("", "WidthStretch")

		local row = displayTable:AddRow()

		Main.selectionTreeCell = row:AddCell()

		Main.configCell = row:AddCell()
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

		selectable.OnClick = function ()
			Helpers:KillChildren(self.configCell)
			CharacterWindow:BuildWindow(self.configCell, selectable.UserData)
		end
	end

	return coroutine.wrap(function()
		self.progressBar.Value = 0
		local maxCount = TableUtils:CountElements(CharacterIndex.templates.acts)

		local count = 0
		local lastPercentage = 0

		for act, actTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.acts) do

			for _, temp in pairs(actTemplates) do
				self.configCell:AddImage(Ext.Template.GetRootTemplate(temp).Icon)
			end

			local actSelection = universalSelection:AddTree(act)
			actSelection:SetOpen(false, "Always")

			local parentRaceSelection = actSelection:AddTree("Races")
			parentRaceSelection.IDContext = act .. "Race"
			parentRaceSelection:SetOpen(false, "Always")

			for race, raceTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.races, function(key)
				return CharacterIndex.displayNameMappings[key]
			end) do
				local raceSelection = parentRaceSelection:AddTree(string.format("%s (%s)", (CharacterIndex.displayNameMappings[race] or race), string.sub(race, #race - 5)))
				raceSelection:SetOpen(false, "Always")
				raceSelection.UserData = race
				raceSelection.IDContext = race .. act

				for _, raceTemplate in TableUtils:OrderedPairs(raceTemplates, function(key)
					return CharacterIndex.displayNameMappings[raceTemplates[key]]
				end) do
					if TableUtils:ListContains(actTemplates, raceTemplate) then
						buildSelectable(raceSelection, raceTemplate)
					end
				end
				if #raceSelection.Children == 0 then
					raceSelection:Destroy()
				end
			end
			if #parentRaceSelection.Children == 0 then
				parentRaceSelection:Destroy()
			end

			local parentProgressionTableSelection = actSelection:AddTree("Progression Tables")
			parentProgressionTableSelection:SetOpen(false, "Always")
			parentProgressionTableSelection.IDContext = "progression" .. act
			for progressionTable, progressionTemplates in TableUtils:OrderedPairs(CharacterIndex.templates.progressions) do
				local progressionTableSelection = parentProgressionTableSelection:AddTree(progressionTable)
				progressionTableSelection.IDContext = progressionTable .. act
				progressionTableSelection.UserData = progressionTable
				progressionTableSelection:SetOpen(false, "Always")

				for _, progressionTemplate in TableUtils:OrderedPairs(progressionTemplates, function(key)
					return CharacterIndex.displayNameMappings[progressionTemplates[key]]
				end) do
					if TableUtils:ListContains(actTemplates, progressionTemplate) then
						buildSelectable(progressionTableSelection, progressionTemplate)
					end
				end

				if #progressionTableSelection.Children == 0 then
					progressionTableSelection:Destroy()
				end
			end
			if #parentProgressionTableSelection.Children == 0 then
				parentProgressionTableSelection:Destroy()
			end
			count = count + 1

			if math.floor(((count / maxCount) * 100)) > lastPercentage then
				lastPercentage = math.floor(((count / maxCount) * 100))
				coroutine.yield(count / maxCount)
			end
		end

		self.progressBar.Visible = false
	end)
end
