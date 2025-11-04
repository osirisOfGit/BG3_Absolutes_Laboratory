Ext.Require("Shared/Mutations/Mutators/PassiveList/PassiveListDesigner.lua")

---@class PassiveListMutatorClass : MutatorInterface
PassiveListMutator = MutatorInterface:new("PassiveList")

---@type ExtComponentType[]
PassiveListMutator.affectedComponents = {
	"PassiveContainer",
}

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
---@field useGameLevel boolean

---@param mutator PassiveListMutator
function PassiveListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	mutator.useGameLevel = mutator.useGameLevel or false
	Helpers:KillChildren(parent)

	local popup = Styler:Popup(parent)

	local passiveListDesignerButton = parent:AddButton("Open Passive List Designer")
	passiveListDesignerButton.UserData = "EnableForMods"
	passiveListDesignerButton.OnClick = function()
		PassiveListDesigner:launch()
	end

	parent:AddText("(?) Distribute By: "):Tooltip():AddText([[
	Changing this option will clear all level groups and only allow selecting lists that have the same option set, as the two options are not compatible with each other.
Using game level will distribute all entries in the same level that the entity is in and all the ones that come before (i.e. TUT, WLD, CRE, SCL if they're in SCL).
Using entity level will use the entity's character level, post Character Level Mutators if applicable.]])
	Styler:DualToggleButton(parent, "Entity Level", "Game Level", true, function(swap)
		if swap then
			mutator.useGameLevel = not mutator.useGameLevel
			mutator.values.delete = true
			mutator.values = {}
			self:renderMutator(parent, mutator)
		end
		return not mutator.useGameLevel
	end)

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
			local list = MutationConfigurationProxy.lists.passiveLists[value]
			return (list.modId or "_") .. list.name
		end) do
			local list = MutationConfigurationProxy.lists.passiveLists[passiveListId]

			local delete = Styler:ImageButton(mutatorSection:AddImageButton("delete" .. list.name, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				for x = l, TableUtils:CountElements(mutator.values.passiveLists) do
					mutator.values.passiveLists[x] = nil
					mutator.values.passiveLists[x] = TableUtils:DeeplyCopyTable(mutator.values.passiveLists._real[x + 1])
				end
				self:renderMutator(parent, mutator)
			end

			local link = mutatorSection:AddTextLink(list.name .. (list.modId and string.format(" (from %s)", Ext.Mod.GetMod(list.modId).Info.Name) or ""))
			link.SameLine = true
			link.OnClick = function()
				PassiveListDesigner:launch(passiveListId)
			end

			if list.spellListDependencies and next(list.spellListDependencies._real or list.spellListDependencies) then
				local sep = mutatorSection:AddCollapsingHeader("Spell List Dependencies ( ? )")
				sep.IDContext = passiveListId
				sep.Font = "Small"
				sep:Tooltip():AddText([[
	These lists are automatically added from the defined dependencies in the Passive List Designer - an entity must have been assigned at least one of these to be assigned this list,
and this list will use the sum of the assigned spell list levels to determine what levels from this passive list should be used.]])

				for s, spellListId in ipairs(list.spellListDependencies) do
					local spellList = MutationConfigurationProxy.lists.spellLists[spellListId]
					if spellList then
						sep:AddTextLink(spellList.name .. (spellList.modId and string.format(" (from %s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or "")).OnClick = function()
							SpellListDesigner:launch(spellListId)
						end
					else
						list.spellListDependencies[s] = nil
						TableUtils:ReindexNumericTable(list.spellListDependencies)
						self:renderMutator(parent, mutator)
						return
					end
				end
			end
		end
	end
	mutatorSection:AddButton("Add Passive List").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		Styler:BuildCompleteUserAndModLists(popup,
			function(config)
				return config.lists and config.lists.passiveLists and next(config.lists.passiveLists) and config.lists.passiveLists
			end,
			function(key, value)
				return value.name
			end,
			function(key, listItem)
				return mutator.useGameLevel == listItem.useGameLevel
			end,
			function(select, id, item)
				select.Label = item.name
				select.Selected = TableUtils:IndexOf(mutator.values.passiveLists, id) ~= nil
				select.OnClick = function()
					local index = TableUtils:IndexOf(mutator.values.passiveLists, id)
					if index then
						mutator.values.passiveLists[index] = nil
						select.Selected = false
					else
						select.Selected = true
						mutator.values.passiveLists = mutator.values.passiveLists or {}
						table.insert(mutator.values.passiveLists, id)
					end
					self:renderMutator(parent, mutator)
				end
			end)
	end

	local looseSep = mutatorSection:AddSeparatorText("Loose Passives ( ? )")
	looseSep:SetStyle("SeparatorTextAlign", 0.1, 0.5)
	looseSep:Tooltip():AddText("\t Passives added here are guaranteed to be added to the entity no matter what")

	local passiveGroup = mutatorSection:AddGroup("passives")
	local function buildPassives()
		Helpers:KillChildren(passiveGroup)
		if mutator.values.passives and next(mutator.values.passives._real or mutator.values.passives) then
			for i, passiveId in ipairs(mutator.values.passives) do
				local delete = Styler:ImageButton(passiveGroup:AddImageButton("delete" .. passiveId, "ico_red_x", { 16, 16 }))
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

	local savedPresetSpreads = ConfigurationStructure.config.mutations.settings.customLists.savedSpellListSpreads.passiveLists

	local popup = parent:AddPopup("Randomized")

	--#region Randomized Spell Pool Size
	parent:AddSeparatorText("Amount of Random Passives to Give Per Level")

	passivePool.randomizedPassivePoolSize = passivePool.randomizedPassivePoolSize or {}
	local randomizedPassivePoolSize = passivePool.randomizedPassivePoolSize
	if getmetatable(randomizedPassivePoolSize) and getmetatable(randomizedPassivePoolSize).__call and not randomizedPassivePoolSize() then
		passivePool.randomizedPassivePoolSize.delete = true
		passivePool.randomizedPassivePoolSize = TableUtils:DeeplyCopyTable(savedPresetSpreads["Default"]._real)
		randomizedPassivePoolSize = passivePool.randomizedPassivePoolSize
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

	local loadButton = parent:AddButton("L")
	loadButton:Tooltip():AddText("\t Load a saved preset")
	loadButton.SameLine = true
	loadButton.OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		for presetName, spread in TableUtils:OrderedPairs(savedPresetSpreads) do
			if presetName ~= "Default" then
				local delete = Styler:ImageButton(popup:AddImageButton("delete" .. presetName, "ico_red_x", { 16, 16 }))
				delete.OnClick = function()
					savedPresetSpreads[presetName].delete = true
					loadButton:OnClick()
				end
			end
			local loadPreset = popup:AddSelectable(presetName)
			loadPreset.SameLine = presetName ~= "Default"
			loadPreset.OnClick = function()
				passivePool.randomizedPassivePoolSize.delete = true
				passivePool.randomizedPassivePoolSize = TableUtils:DeeplyCopyTable(spread._real)
				self:renderRandomizedAmountSettings(parent, passivePool)
			end
		end
	end

	local saveButton = parent:AddButton("S")
	saveButton:Tooltip():AddText("\t Save the current table to a new or existing preset")
	saveButton.SameLine = true
	saveButton.OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		local nameInput = popup:AddInputText("")
		nameInput.Hint = "New or Existing Preset Name"

		local overrideConfirmation = popup:AddText("Are you sure you want to override %s?")
		overrideConfirmation.Visible = false
		overrideConfirmation:SetColor("Text", { 1, 0.2, 0, 1 })

		local submitButton = popup:AddButton("Save")
		submitButton.OnClick = function()
			if overrideConfirmation.Visible or not savedPresetSpreads[nameInput.Text] then
				if savedPresetSpreads[nameInput.Text] then
					savedPresetSpreads[nameInput.Text].delete = true
				end
				savedPresetSpreads[nameInput.Text] = TableUtils:DeeplyCopyTable(randomizedPassivePoolSize._real)
				self:renderRandomizedAmountSettings(parent, passivePool)
			else
				overrideConfirmation.Label = string.format("Are you sure you want to override %s?", nameInput.Text)
				overrideConfirmation.Visible = true
			end
		end
	end
end

---@param mutator PassiveListMutator
function PassiveListMutator:handleDependencies(export, mutator, removeMissingDependencies)
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
						return true
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
		ListConfigurationManager:HandleDependences(export, mutator, mutator.values.passiveLists, removeMissingDependencies, PassiveListDesigner.configKey)
	end
end

function PassiveListMutator:undoMutator(entity, mutator, primedEntityVar, reprocessTransient)
	if next(mutator.originalValues[self.name]) and entity.PassiveContainer then
		for _, passiveEntity in pairs(entity.PassiveContainer.Passives) do
			if TableUtils:IndexOf(mutator.originalValues[self.name], passiveEntity.Passive.PassiveId) then
				Logger:BasicDebug("Removing passive %s as it was given by Lab", passiveEntity.Passive.PassiveId)
				Osi.RemovePassive(entity.Uuid.EntityUuid, passiveEntity.Passive.PassiveId)
			end
		end
	end
end

---@param entity EntityHandle
---@param levelToUse integer
---@param passiveList CustomList
---@param numRandomPassivesPerLevel number[]
---@param appliedPassives string[]
---@param appliedLists Guid[]
local function applyPassiveLists(entity, levelToUse, passiveList, numRandomPassivesPerLevel, appliedPassives, appliedLists)
	passiveList = TableUtils:DeeplyCopyTable(passiveList)

	Logger:BasicDebug("Applying levels %s to %s of list %s",
		passiveList.useGameLevel and EntityRecorder.Levels[1] or 1,
		passiveList.useGameLevel and EntityRecorder.Levels[levelToUse] or levelToUse,
		passiveList.name .. (passiveList.modId and (" from mod " .. Ext.Mod.GetMod(passiveList.modId).Info.Name) or ""))

	if passiveList.levels then
		for level = 1, levelToUse do
			local leveledLists = passiveList.levels[level]
			---@type EntryName[]
			local randomPool = {}

			if passiveList.linkedProgressionTableIds and next(passiveList.linkedProgressionTableIds._real or passiveList.linkedProgressionTableIds) then
				for _, progressionTableId in pairs(passiveList.linkedProgressionTableIds) do
					local progressionTable = ListConfigurationManager.progressionIndex[progressionTableId]
					if progressionTable then
						for _, progressionLevel in pairs(progressionTable.progressionLevels) do
							if progressionLevel.level == level and progressionLevel.passiveLists then
								for _, passives in pairs(progressionLevel.passiveLists) do
									for _, passiveName in pairs(passives) do
										if not TableUtils:IndexOf(appliedPassives, passiveName) then
											local leveledLists = passiveList.levels and passiveList.levels[level]
											if not leveledLists
												or not leveledLists.linkedProgressions
												or not TableUtils:IndexOf(leveledLists.linkedProgressions[progressionTableId],
													function(value)
														return TableUtils:IndexOf(value, passiveName) ~= nil
													end)
											then
												passiveList.levels = passiveList.levels or {}
												passiveList.levels[level] = passiveList.levels[level] or {}
												passiveList.levels[level].linkedProgressions = passiveList.levels[level].linkedProgressions or {}
												passiveList.levels[level].linkedProgressions[progressionTableId] = passiveList.levels[level].linkedProgressions[progressionTableId] or
													{}

												local defaultPool = passiveList.defaultPool or
													ConfigurationStructure.config.mutations.settings.customLists.defaultPool.passiveLists

												passiveList.levels[level].linkedProgressions[progressionTableId][defaultPool] = passiveList.levels[level].linkedProgressions
													[progressionTableId][defaultPool] or {}

												Logger:BasicTrace("Added %s to the default pool %s for later processing", passiveName, defaultPool)
												table.insert(passiveList.levels[level].linkedProgressions[progressionTableId][defaultPool], passiveName)
											end
										end
									end
								end
							end
						end
					end
				end
			end
			if leveledLists then
				if leveledLists.linkedProgressions then
					for progressionTableId, subLists in pairs(leveledLists.linkedProgressions) do
						local progressionTable = ListConfigurationManager.progressionIndex[progressionTableId]
						if progressionTable then
							if subLists.guaranteed and next(subLists.guaranteed) then
								for _, passiveId in pairs(subLists.guaranteed) do
									if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 and not TableUtils:IndexOf(appliedPassives, passiveId) then
										Logger:BasicDebug("Adding guaranteed passive %s from progression %s (%s - level %s)", passiveId, progressionTableId,
											progressionTable.name, level)

										table.insert(appliedPassives, passiveId)
									else
										Logger:BasicDebug("Guaranteed passive %s from progression %s (%s - level %s) is already known", passiveId, progressionTableId,
											progressionTable.name, level)
									end
								end
							end

							if subLists.randomized and next(subLists.randomized) then
								for _, passiveId in pairs(subLists.randomized) do
									if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 then
										if not TableUtils:IndexOf(appliedPassives, passiveId) and not TableUtils:IndexOf(randomPool, passiveId) then
											table.insert(randomPool, passiveId)
										end
									else
										Logger:BasicDebug("Randomized passive %s from progression %s (%s - level %s) is already known", passiveId, progressionTableId,
											progressionTable.name, level)
									end
								end
							end
						end
					end
				end

				if leveledLists.manuallySelectedEntries then
					if leveledLists.manuallySelectedEntries.randomized then
						for _, passiveId in pairs(leveledLists.manuallySelectedEntries.randomized) do
							if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0
								and not TableUtils:IndexOf(appliedPassives, passiveId)
								and not TableUtils:IndexOf(randomPool, passiveId)
							then
								table.insert(randomPool, passiveId)
							else
								Logger:BasicDebug("%s is already present, not adding to the random pool", passiveId)
							end
						end
					end
					if leveledLists.manuallySelectedEntries.guaranteed and next(leveledLists.manuallySelectedEntries.guaranteed) then
						for _, passiveId in pairs(leveledLists.manuallySelectedEntries.guaranteed) do
							if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 and not TableUtils:IndexOf(appliedPassives, passiveId) then
								Logger:BasicDebug("Adding guaranteed passive %s", passiveId)
								table.insert(appliedPassives, passiveId)
							else
								Logger:BasicDebug("Guaranteed passive %s is already present", passiveId)
							end
						end
					end
				end
			end

			if #randomPool > 0 then
				local numRandomPassivesToPick = 0
				if numRandomPassivesPerLevel[level] then
					numRandomPassivesToPick = numRandomPassivesPerLevel[level]
				else
					local maxLevel = nil
					for definedLevel, _ in pairs(numRandomPassivesPerLevel) do
						if definedLevel < level and (not maxLevel or definedLevel > maxLevel) then
							maxLevel = definedLevel
						end
					end
					if maxLevel then
						numRandomPassivesToPick = numRandomPassivesPerLevel[maxLevel]
					end
				end

				if numRandomPassivesToPick > 0 then
					Logger:BasicDebug("Giving %s random passives out of %s from level %s",
						numRandomPassivesToPick,
						#randomPool,
						passiveList.useGameLevel and EntityRecorder.Levels[level] or level)

					local passivesToGive = {}
					if #randomPool <= numRandomPassivesToPick then
						passivesToGive = randomPool
					else
						for _ = 1, numRandomPassivesToPick do
							local num = math.random(#randomPool)
							table.insert(passivesToGive, randomPool[num])
							table.remove(randomPool, num)
						end
					end

					for _, passiveId in pairs(passivesToGive) do
						table.insert(appliedPassives, passiveId)
					end
				else
					Logger:BasicDebug("Skipping level %s for random passive assignment due to configured size being 0",
						passiveList.useGameLevel and EntityRecorder.Levels[level] or level)
				end
			end
		end
	end

	---@param listToProcess CustomList
	local function recursivelyApplyLists(listToProcess)
		if listToProcess.linkedLists and next(listToProcess.linkedLists._real or listToProcess.linkedLists) then
			for _, linkedListId in pairs(listToProcess.linkedLists) do
				if not TableUtils:IndexOf(appliedLists, linkedListId) then
					table.insert(appliedLists, linkedListId)

					local linkedList = MutationConfigurationProxy.lists.passiveLists[linkedListId]
					if linkedList then
						Logger:BasicDebug("### STARTING List %s, linked from %s ###", linkedList.name, listToProcess.name)
						applyPassiveLists(entity, levelToUse, linkedList, numRandomPassivesPerLevel, appliedPassives, appliedLists)
						Logger:BasicDebug("### FINISHED List %s, linked from %s ###", linkedList.name, listToProcess.name)

						recursivelyApplyLists(linkedList)
					else
						Logger:BasicWarning("Can't find a PassiveList with a UUID of %s, linked to %s - skipping", linkedListId, listToProcess.name)
					end
				end
			end
		end
	end
	recursivelyApplyLists(passiveList)
end

function PassiveListMutator:applyMutator(entity, entityVar)
	local passiveListMutators = entityVar.appliedMutators[self.name]
	if not passiveListMutators[1] then
		passiveListMutators = { passiveListMutators }
	end
	---@cast passiveListMutators PassiveListMutator[]

	local appliedPassives = {}

	local usingListsWithSpellListDeps = false
	-- PassiveListId : randomizedPassivePoolSize
	---@type {[Guid]: number[]}
	local passiveListsPool = {}

	---@type string[]
	local loosePassivesToApply = {}
	for _, passiveListMutator in pairs(passiveListMutators) do
		if passiveListMutator.values.passives then
			for _, passive in pairs(passiveListMutator.values.passives) do
				if not TableUtils:IndexOf(loosePassivesToApply, passive) then
					table.insert(loosePassivesToApply, passive)
				end
			end
		end

		if passiveListMutator.values.passiveLists then
			for _, passiveListId in pairs(passiveListMutator.values.passiveLists) do
				local passiveList = MutationConfigurationProxy.lists.passiveLists[passiveListId]
				if passiveList then
					passiveList = passiveList.__real or passiveList
					if passiveList.spellListDependencies and next(passiveList.spellListDependencies) then
						for _, spellListDependency in ipairs(passiveList.spellListDependencies) do
							if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists and entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency] then
								if not usingListsWithSpellListDeps then
									passiveListsPool = {}
									usingListsWithSpellListDeps = true
								end

								passiveListsPool[passiveListId] = passiveListMutator.values.randomizedPassivePoolSize
								Logger:BasicDebug(
									"List %s was added to the pool due to having Spell List Dependency %s being present (removing all passive lists that don't have dependencies from the pool)",
									passiveList.name,
									spellListDependency)
								break
							end
						end
					elseif not usingListsWithSpellListDeps then
						passiveListsPool[passiveListId] = passiveListMutator.values.randomizedPassivePoolSize
						Logger:BasicDebug("List %s was added to the random pool due to having no Spell List Dependencies", passiveList.name)
					end
				end
			end
		end
	end

	if next(loosePassivesToApply) then
		for _, passiveId in pairs(loosePassivesToApply) do
			if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 and not TableUtils:IndexOf(appliedPassives, passiveId) then
				Logger:BasicDebug("Adding loose passive %s", passiveId)
				table.insert(appliedPassives, passiveId)
			else
				Logger:BasicDebug("Loose passive %s is already present", passiveId)
			end
		end
	end

	---@type EntryReplacerDictionary
	local replaceMap = TableUtils:DeeplyCopyTable(ConfigurationStructure.config.mutations.lists.entryReplacerDictionary)
	replaceMap.passiveLists = replaceMap.passiveLists or {}

	local appliedLists = {}

	if next(passiveListsPool) then
		if not usingListsWithSpellListDeps then
			local chosenIndex = math.random(TableUtils:CountElements(passiveListsPool))
			local count = 0
			for passiveListId, numRandomPassivesPerLevel in pairs(passiveListsPool) do
				count = count + 1
				if count == chosenIndex then
					local passiveList = MutationConfigurationProxy.lists.passiveLists[passiveListId]
					passiveList = passiveList.__real or passiveList

					Logger:BasicDebug("%s passive lists without dependencies are in the pool - randomly chose %s",
						TableUtils:CountElements(passiveListsPool),
						passiveList.name .. (passiveList.modId and (" from mod " .. Ext.Mod.GetMod(passiveList.modId).Info.Name) or ""))

					local levelToUse = passiveList.useGameLevel and entity.Level.LevelName or entity.EocLevel.Level
					applyPassiveLists(entity, levelToUse, passiveList, numRandomPassivesPerLevel, appliedPassives, appliedLists)
					break
				end
			end
		else
			for passiveListId, numRandomPassivesPerLevel in pairs(passiveListsPool) do
				local passiveList = MutationConfigurationProxy.lists.passiveLists[passiveListId]
				passiveList = passiveList.__real or passiveList

				local levelToUse = 0
				for _, spellListDependency in pairs(passiveList.spellListDependencies) do
					local appliedSpellListLevel = entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency]
					if appliedSpellListLevel then
						levelToUse = levelToUse + appliedSpellListLevel
					end
				end

				if levelToUse > 0 and passiveList.modId then
					local modReplaceMap = MutationConfigurationProxy.lists.entryReplacerDictionary.passiveLists[passiveList.modId]
					if modReplaceMap then
						for statReplacement, statsToReplace in pairs(modReplaceMap) do
							if not replaceMap.passiveLists[statReplacement] then
								replaceMap.passiveLists[statReplacement] = statsToReplace
							else
								for _, toReplace in ipairs(statsToReplace) do
									if not TableUtils:IndexOf(replaceMap.passiveLists[statReplacement], toReplace) then
										table.insert(replaceMap.passiveLists[statReplacement])
									end
								end
							end
						end
						Logger:BasicDebug("Added Mod %'s replacement map to the overall replacement map, as one of it's lists was used", Ext.Mod.GetMod(passiveList.modId).Info.Name)
					end
				end

				applyPassiveLists(entity, levelToUse, passiveList, numRandomPassivesPerLevel, appliedPassives, appliedLists)
			end
		end
	end

	if next(appliedPassives) then
		for i = #appliedPassives, 1, -1 do
			local passiveToApply = appliedPassives[i]
			if passiveToApply and replaceMap.passiveLists[passiveToApply] then
				for _, passiveToRemove in pairs(replaceMap.passiveLists[passiveToApply]) do
					if Osi.HasPassive(entity.Uuid.EntityUuid, passiveToRemove) == 1 then
						Osi.RemovePassive(entity.Uuid.EntityUuid, passiveToRemove)
						Logger:BasicDebug("Removed %s from the entity as it's marked to be removed by %s", passiveToRemove, passiveToApply)
					end
					local index = TableUtils:IndexOf(appliedPassives, passiveToRemove)
					if index then
						appliedPassives[index] = nil
						Logger:BasicDebug("Removed %s from list of passives to apply as it's marked to be removed by %s", passiveToRemove, passiveToApply)
					end
				end
			end
		end

		TableUtils:ReindexNumericTable(appliedPassives)

		Logger:BasicDebug("Applying the following passives: %s", appliedPassives)
		for _, passiveToApply in ipairs(appliedPassives) do
			Osi.AddPassive(entity.Uuid.EntityUuid, passiveToApply)
		end
		entityVar.originalValues[self.name] = appliedPassives
	end
end

function PassiveListMutator:FinalizeMutator(entity)
	Ext.Timer.WaitFor(500, function()
		if entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] then
			local plmVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME].originalValues[self.name]
			local passiveIndex = {}
			local removedPassives = {}
			for _, passiveEntity in pairs(entity.PassiveContainer.Passives) do
				if passiveEntity.Passive.Type == "Script" and TableUtils:IndexOf(plmVar, passiveEntity.Passive.PassiveId) then
					if not passiveIndex[passiveEntity.Passive.PassiveId] then
						passiveIndex[passiveEntity.Passive.PassiveId] = 1
					else
						removedPassives[passiveEntity.Passive.PassiveId] = (removedPassives[passiveEntity.Passive.PassiveId] or 0) + 1
						Ext.System.ServerPassive.RemovePassives[passiveEntity] = true
					end
				end
			end

			if next(removedPassives) then
				Logger:BasicDebug("Removed the following passives from %s (%s) due to being duplicated somehow:\n%s", EntityRecorder:GetEntityName(entity), entity.Uuid.EntityUuid,
					removedPassives)
			end
		end
	end)
end

---@return MazzleDocsDocumentation
function PassiveListMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Passive Lists",
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "",
					prefix_color = "Yellow",
					text = [[
Dependency On: Spell Lists
Transient: No
Composable: All groups will be combined into one large pool, which will be pulled from randomly post-filter]]
				} --[[@as MazzleDocsCallOut]],
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Summary"
				},
				{
					type = "Content",
					text = [[Basically Spell Lists, just with Passives!]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Client-Side Content"
				},
				{
					type = "Content",
					text = [[
The mutator is designed very similarily to Spell Lists, so only the differences are notated:

- There are no level pools - instead, the mutator checks the combined levels of the linked Spell Lists that were assigned and uses that to determine what level to use for the given list
- If there are no Linked Spell lists, the entity level will be used instead
- There are no criteria due to the Spell List dependency

The rest of the Mutator UI is explained via tooltips to avoid duplicated info and inevitable deprecation of information.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Server-Side Implementation"
				},
				{
					type = "Content",
					text = [[Since this mutator only has Random and Guaranteed pools, all passives are added via Osi: Osi.AddPassive(entity.Uuid.EntityUuid, passiveToApply)
Building the random pool follows the same general logic as Spell List Mutator:
When determining what passives end up in the Random pool to be added to the entity, checks are done to ensure:
1. The passive isn't already on the entity
2. The passive isn't already slated to be added by another progression

Once the final list of passives is determined, the Replace logic is run, removing any passives from the final list and the entity's PassiveContainer (via Osi.RemovePassive) if they're marked to be replaced by another passive.]]
				},
				{
					type = "Separator"
				},
				{
					type = "SubHeading",
					text = "Example Use Cases"
				},
				{
					type = "Section",
					text = "Selected entities:"
				},
				{
					type = "Bullet",
					text = {
						"Should receive a distribution of passives that complement the Spell Lists they were assigned",
						"Should receive a set list of passives based on which Game Level they're in"
					}
				} --[[@as MazzleDoctsBullet]],
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function PassiveListMutator:generateChangelog()
	return {
		["1.8.2"] = {
			type = "Bullet",
			text = {
				"Fixes error if something went wrong while applying a Spell list mutator to an entity"
			}
		},
		["1.8.0"] = {
			type = "Bullet",
			text = {
				"Changed the `Added %s to the default pool %s for later processing` DEBUG log to TRACE",
				"Fixed some duplication in what was being added, and implemented a stupid failsafe in case the engine doesn't properly delete the passives previously given by Lab before reapplying them"
			}
		},
		["1.7.1"] = {
			type = "Bullet",
			text = {
				"Added safety check + log in case a linked list isn't found"
			}
		},
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Fix lists not applying entries from linked progressions"
			}
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
