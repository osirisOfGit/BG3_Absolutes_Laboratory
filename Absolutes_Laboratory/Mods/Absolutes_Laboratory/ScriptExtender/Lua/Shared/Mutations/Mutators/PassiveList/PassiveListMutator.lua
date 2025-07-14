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
---@field randomizedPassivePoolSize number[]

---@class PassiveListMutator : Mutator
---@field values PassivePool

---@param mutator PassiveListMutator
function PassiveListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

	local passiveListDesignerButton = parent:AddButton("Open Passive List Designer")
	passiveListDesignerButton.UserData = "EnableForMods"
	passiveListDesignerButton.OnClick = function()
		PassiveListDesigner:launch()
	end

	local sectionTable = parent:AddTable("Sections", 2)
	sectionTable.BordersOuter = true
	local sectionsRow = sectionTable:AddRow()
	local mutatorSection = sectionsRow:AddCell()
	local modifierSection = sectionsRow:AddCell()

	local listSep = mutatorSection:AddSeparatorText("Passive Lists ( ? )")
	listSep:SetStyle("SeparatorTextAlign", 0.1, 0.5)
	listSep:Tooltip():AddText(
		"\t If multiple lists are specified and are eligible to be assigned to the entity (according to their Spell List dependencies, or lack thereof), one will be randomly chosen")

	if mutator.values.passiveLists then
		for l, passiveListId in TableUtils:OrderedPairs(mutator.values.passiveLists, function(key, value)
			local list = MutationConfigurationProxy.passiveLists[value]
			return (list.modId or "_") .. list.name
		end) do
			local list = MutationConfigurationProxy.passiveLists[passiveListId]

			local delete = Styler:ImageButton(mutatorSection:AddImageButton("delete" .. list.name, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				for x = l, TableUtils:CountElements(mutator.values.passiveLists) do
					mutator.values.passiveLists[x] = nil
					mutator.values.passiveLists[x] = TableUtils:DeeplyCopyTable(mutator.values.passiveLists._real[x + 1])
				end
				self:renderMutator(mutatorSection, mutator)
			end

			local link = mutatorSection:AddTextLink(list.name .. (list.modId and string.format(" (from %s)", Ext.Mod.GetMod(list.modId).Info.Name) or ""))
			link.SameLine = true
			link.OnClick = function()
				PassiveListDesigner:launch(passiveListId)
			end

			if list.spellListDependencies and list.spellListDependencies() then
				local sep = mutatorSection:AddCollapsingHeader("Spell List Dependencies ( ? )")
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
	mutatorSection:AddButton("Add Passive List").OnClick = function()
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

	local looseSep = mutatorSection:AddSeparatorText("Loose Passives ( ? )")
	looseSep:SetStyle("SeparatorTextAlign", 0.1, 0.5)
	looseSep:Tooltip():AddText("\t Passives added here are guaranteed to be added to the entity no matter what")

	local passiveGroup = mutatorSection:AddGroup("passives")
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

	mutatorSection:AddButton("Add Passive").OnClick = function()
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

	self:renderRandomizedAmountSettings(modifierSection, mutator.values)
end

---@param parent ExtuiTreeParent
---@param passivePool PassivePool
function PassiveListMutator:renderRandomizedAmountSettings(parent, passivePool)
	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("Randomized")

	--#region Randomized Spell Pool Size
	parent:AddSeparatorText("Amount of Random Passives to Give Per Level")

	passivePool.randomizedPassivePoolSize = passivePool.randomizedPassivePoolSize or {}
	local randomizedPassivePoolSize = passivePool.randomizedPassivePoolSize
	if getmetatable(randomizedPassivePoolSize) and getmetatable(randomizedPassivePoolSize).__call and not randomizedPassivePoolSize() then
		randomizedPassivePoolSize[1] = 1
	end

	local randoSpellsTable = parent:AddTable("RandomSpellNumbers", 3)
	randoSpellsTable:AddColumn("", "WidthFixed")

	local headers = randoSpellsTable:AddRow()
	headers.Headers = true
	headers:AddCell()
	headers:AddCell():AddText("Level ( ? )"):Tooltip():AddText([[
	Levels do not need to be consecutive - for example, you can set level 1 to give 3 random passives, and level 5 to give 1 random passive.
This will cause Lab to give the entity 3 random passives from the selected Passive List every level for levels 1-4, and 1 random passive every level from level 5 onwards]])

	headers:AddCell():AddText("# Of Passives ( ? )"):Tooltip():AddText([[
	This represents the amount of Random passives to give the entity from the appropriate level in the Passive List, if the passive list has passives for the appropriate level]])

	local enableDelete = false
	for level, numSpells in TableUtils:OrderedPairs(randomizedPassivePoolSize) do
		local row = randoSpellsTable:AddRow()
		if not enableDelete then
			row:AddCell()
			enableDelete = true
		else
			local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. level, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				randomizedPassivePoolSize[level] = nil
				row:Destroy()
			end
		end

		---@param input ExtuiInputInt
		row:AddCell():AddInputInt("", level).OnDeactivate = function(input)
			if not randomizedPassivePoolSize[input.Value[1]] then
				randomizedPassivePoolSize[input.Value[1]] = numSpells
				randomizedPassivePoolSize[level] = nil
				self:renderRandomizedAmountSettings(parent, passivePool)
			else
				input.Value = { level, level, level, level }
			end
		end

		---@param input ExtuiInputInt
		row:AddCell():AddInputInt("", numSpells).OnDeactivate = function(input)
			randomizedPassivePoolSize[level] = input.Value[1]
		end
	end

	parent:AddButton("+").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		local add = popup:AddButton("Add Level")
		local input = popup:AddInputInt("", randomizedPassivePoolSize() + 1)
		input.SameLine = true

		local errorText = popup:AddText("Choose a level that isn't already specified")
		errorText:SetColor("Text", Styler:ConvertRGBAToIMGUI({ 255, 100, 100, 0.7 }))
		errorText.Visible = false

		add.OnClick = function()
			if randomizedPassivePoolSize[input.Value[1]] then
				errorText.Visible = true
			else
				randomizedPassivePoolSize[input.Value[1]] = 2
				self:renderRandomizedAmountSettings(parent, passivePool)
			end
		end
	end
end

---@param mutator PassiveListMutator
function PassiveListMutator:handleDependencies(export, mutator, removeMissingDependencies)
	SpellListDesigner:buildProgressionIndex()

	---@param passiveName string
	---@param container table?
	---@return boolean?
	local function buildPassiveDependency(passiveName, container)
		---@type PassiveData?
		local passive = Ext.Stats.Get(passiveName)
		if passive then
			if not removeMissingDependencies then
				container = container or mutator
				container.modDependencies = container.modDependencies or {}
				if not container.modDependencies[passive.OriginalModId] then
					local name, author, version = Helpers:BuildModFields(passive.OriginalModId)
					if author == "Larian" then
						return
					end

					container.modDependencies[passive.OriginalModId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = passive.OriginalModId,
						packagedItems = {}
					}
				end
				container.modDependencies[passive.OriginalModId].packagedItems[passiveName] = Ext.Loca.GetTranslatedString(passive.DisplayName, passiveName)
			end
			return true
		else
			return false
		end
	end

	if mutator.values.passives then
		for i, passive in pairs(mutator.values.passives) do
			if not buildPassiveDependency(passive) then
				mutator.values.passives[i] = nil
			end
		end
		TableUtils:ReindexNumericTable(mutator.values.passives)
	end

	if mutator.values.passiveLists then
		PassiveListDesigner:HandleDependences(export, mutator, mutator.values.passiveLists, removeMissingDependencies)
	end
end

function PassiveListMutator:undoMutator(entity, mutator, primedEntityVar, reprocessTransient)
	for _, passiveId in pairs(mutator.originalValues[self.name]) do
		if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 1 then
			Logger:BasicDebug("Removing passive %s as it was given by Lab", passiveId)
			Osi.RemovePassive(entity.Uuid.EntityUuid, passiveId)
		end
	end
end

function PassiveListMutator:applyMutator(entity, mutatorVar)
	
end
