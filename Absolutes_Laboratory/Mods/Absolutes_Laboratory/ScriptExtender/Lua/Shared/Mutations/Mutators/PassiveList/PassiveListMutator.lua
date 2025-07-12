Ext.Require("Shared/Mutations/Mutators/PassiveList/PassiveListDesigner.lua")

---@class PassiveListMutatorClass : MutatorInterface
PassiveListMutator = MutatorInterface:new("PassiveList")

function PassiveListMutator:priority()
	return self:recordPriority(SpellListMutator:priority() + 1)
end

function PassiveListMutator:canBeAdditive()
	return true
end

---@class PassivePool
---@field passiveLists Guid[]
---@field passives string[]?
---@field removePassives string[]

---@class PassiveMutator : Mutator
---@field values PassivePool

---@param mutator PassiveMutator
function PassiveListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

	local passiveListDesignerButton = parent:AddButton("Open Passive List Designer")
	passiveListDesignerButton.UserData = "EnableForMods"
	passiveListDesignerButton.OnClick = function()
		PassiveListDesigner:launch()
	end

	local listSep = parent:AddSeparatorText("Passive Lists ( ? )")
	listSep:SetStyle("SeparatorTextAlign", 0.1, 0.5)
	listSep:Tooltip():AddText(
		"\t If multiple lists are specified and are eligible to be assigned to the entity (according to their Spell List dependencies, or lack thereof), one will be randomly chosen")

	if mutator.values.passiveLists then
		for l, passiveListId in TableUtils:OrderedPairs(mutator.values.passiveLists, function(key, value)
			local list = MutationConfigurationProxy.passiveLists[value]
			return (list.modId or "_") .. list.name
		end) do
			local list = MutationConfigurationProxy.passiveLists[passiveListId]

			local delete = Styler:ImageButton(parent:AddImageButton("delete" .. list.name, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				for x = l, TableUtils:CountElements(mutator.values.passiveLists) do
					mutator.values.passiveLists[x] = nil
					mutator.values.passiveLists[x] = TableUtils:DeeplyCopyTable(mutator.values.passiveLists._real[x + 1])
				end
				self:renderMutator(parent, mutator)
			end

			local link = parent:AddTextLink(list.name .. (list.modId and string.format(" (from %s)", Ext.Mod.GetMod(list.modId).Info.Name) or ""))
			link.SameLine = true
			link.OnClick = function()
				PassiveListDesigner:launch(passiveListId)
			end

			if list.spellListDependencies and list.spellListDependencies() then
				local sep = parent:AddCollapsingHeader("Spell List Dependencies ( ? )")
				sep.Font = "Small"
				sep:Tooltip():AddText([[
	These lists are automatically added from the defined dependencies in the Passive List Designer - an entity must have been assigned at least one of these to be assigned this list,
and this list will use the sum of the assigned spell list levels to determine what levels from this passive list should be used.]])

				for _, spellListId in ipairs(list.spellListDependencies) do
					local spellList = MutationConfigurationProxy.spellLists[spellListId]
					sep:AddTextLink(spellList.name .. (spellList.modId and string.format(" (from %s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or "")).OnClick = function()
						SpellListDesigner:launch(spellListId)
					end
				end
			end
		end
	end
	parent:AddButton("Add Passive List").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		for passiveListId, passiveList in pairs(MutationConfigurationProxy.passiveLists) do
			popup:AddSelectable(passiveList.name .. (passiveList.modId and string.format(" (from %s)", Ext.Mod.GetMod(passiveList.modId).Info.Name) or ""), "DontClosePopups").OnClick = function()
				mutator.values.passiveLists = mutator.values.passiveLists or {}
				mutator.values.passiveLists[#mutator.values.passiveLists + 1] = passiveListId

				self:renderMutator(parent, mutator)
			end
		end
	end

	local looseSep = parent:AddSeparatorText("Loose Passives ( ? )")
	looseSep:SetStyle("SeparatorTextAlign", 0.1, 0.5)
	looseSep:Tooltip():AddText("\t Passives added here are guaranteed to be added to the entity no matter what")

	local passiveGroup = parent:AddGroup("passives")
	local function buildPassives()
		Helpers:KillChildren(passiveGroup)
		if mutator.values.passives and mutator.values.passives() then
			for i, passiveId in ipairs(mutator.values.passives) do
				local delete = Styler:ImageButton(passiveGroup:AddImageButton("delete" .. passiveId, "ico_red_x", { 16, 16 }))
				delete.SameLine = (i - 1) % 3 ~= 0
				delete.OnClick = function()
					for x = i, TableUtils:CountElements(mutator.values.passives) do
						mutator.values.passives[x] = nil
						mutator.values.passives[x] = TableUtils:DeeplyCopyTable(mutator.values.passives._real[x + 1])
					end
					buildPassives()
				end

				Styler:HyperlinkText(passiveGroup, passiveId, function(parent)
					ResourceManager:RenderDisplayWindow(Ext.Stats.Get(passiveId), parent)
				end).SameLine = true
			end
		end
	end
	buildPassives()

	parent:AddButton("Add Passive").OnClick = function()
		popup:Open()

		Helpers:KillChildren(popup)

		StatBrowser:Render("PassiveData",
			popup,
			nil,
			function(pos)
				return pos % 7 ~= 0
			end,
			function(passiveId)
				return TableUtils:IndexOf(mutator.values.passives, passiveId) ~= nil
			end,
			nil,
			function(_, passiveId)
				if not TableUtils:IndexOf(mutator.values.passives, passiveId) then
					mutator.values.passives = mutator.values.passives or {}

					table.insert(mutator.values.passives, passiveId)
				else
					local index = TableUtils:IndexOf(mutator.values.passives, passiveId)
					for x = index, TableUtils:CountElements(mutator.values.passives) do
						mutator.values.passives[x] = nil
						mutator.values.passives[x] = mutator.values.passives[x + 1]
					end
					if not mutator.values.passives() then
						mutator.values.passives.delete = true
					end
				end
				buildPassives()
			end)
	end
end
