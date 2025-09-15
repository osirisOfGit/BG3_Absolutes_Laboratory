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
---@field useGameLevel boolean

---@param mutator PassiveListMutator
function PassiveListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	mutator.useGameLevel = mutator.useGameLevel or false
	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

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
				self:renderMutator(parent, mutator)
			end

			local link = mutatorSection:AddTextLink(list.name .. (list.modId and string.format(" (from %s)", Ext.Mod.GetMod(list.modId).Info.Name) or ""))
			link.SameLine = true
			link.OnClick = function()
				PassiveListDesigner:launch(passiveListId)
			end

			if list.spellListDependencies and list.spellListDependencies() then
				local sep = mutatorSection:AddCollapsingHeader("Spell List Dependencies ( ? )")
				sep.IDContext = passiveListId
				sep.Font = "Small"
				sep:Tooltip():AddText([[
	These lists are automatically added from the defined dependencies in the Passive List Designer - an entity must have been assigned at least one of these to be assigned this list,
and this list will use the sum of the assigned spell list levels to determine what levels from this passive list should be used.]])

				for s, spellListId in ipairs(list.spellListDependencies) do
					local spellList = MutationConfigurationProxy.spellLists[spellListId]
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

		for passiveListId, passiveList in pairs(MutationConfigurationProxy.passiveLists) do
			if passiveList.useGameLevel == mutator.useGameLevel then
				---@type ExtuiSelectable
				local select = popup:AddSelectable(passiveList.name .. (passiveList.modId and string.format(" (from %s)", Ext.Mod.GetMod(passiveList.modId).Info.Name) or ""),
					"DontClosePopups")
				select.Selected = TableUtils:IndexOf(mutator.values.passiveLists, passiveListId) ~= nil
				select.OnClick = function()
					if not select.Selected then
						mutator.values.passiveLists[TableUtils:IndexOf(mutator.values.passiveLists, passiveListId)] = nil
						TableUtils:ReindexNumericTable(mutator.values.passiveLists)
					else
						mutator.values.passiveLists = mutator.values.passiveLists or {}
						mutator.values.passiveLists[#mutator.values.passiveLists + 1] = passiveListId
					end
					self:renderMutator(parent, mutator)
				end
			end
		end

		if MutationModProxy.ModProxy.passiveLists() then
			---@type {[Guid]: Guid[]}
			local modPassiveLists = {}

			for modId, modCache in pairs(MutationModProxy.ModProxy.passiveLists) do
				---@cast modCache +LocalModCache

				if modCache.passiveLists and next(modCache.passiveLists) then
					modPassiveLists[modId] = {}
					for passiveListId in pairs(modCache.passiveLists) do
						table.insert(modPassiveLists[modId], passiveListId)
					end
				end
			end

			if next(modPassiveLists) then
				for modId, passiveLists in TableUtils:OrderedPairs(modPassiveLists, function(key, value)
					return Ext.Mod.GetMod(key).Info.Name
				end) do
					local modGroup = popup:AddGroup("Mods" .. modId)

					modGroup:AddSeparatorText(Ext.Mod.GetMod(modId).Info.Name).Font = "Small"

					for _, passiveListId in TableUtils:OrderedPairs(passiveLists, function(key, value)
						return MutationModProxy.ModProxy.passiveLists[value].name
					end) do
						local passiveList = MutationModProxy.ModProxy.passiveLists[passiveListId]
						if mutator.useGameLevel == passiveList.useGameLevel then
							---@type ExtuiSelectable
							local select = modGroup:AddSelectable(passiveList.name, "DontClosePopups")
							select.Selected = TableUtils:IndexOf(mutator.values.passiveLists, passiveListId) ~= nil
							select.OnClick = function()
								local index = TableUtils:IndexOf(mutator.values.passiveLists, passiveListId)
								if index then
									mutator.values.passiveLists[index] = nil
									select.Selected = false
								else
									select.Selected = true
									table.insert(mutator.values.passiveLists, passiveListId)
								end
								self:renderMutator(parent, mutator)
							end
						end
					end
					if #modGroup.Children == 1 then
						modGroup:Destroy()
					end
				end
			end
		end
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
	for _, passiveId in pairs(mutator.originalValues[self.name] or {}) do
		if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 1 then
			Logger:BasicDebug("Removing passive %s as it was given by Lab", passiveId)
			Osi.RemovePassive(entity.Uuid.EntityUuid, passiveId)
		end
	end
end

---@param entity EntityHandle
---@param levelToUse integer
---@param passiveList CustomList
---@param numRandomPassivesPerLevel number[]
---@param appliedPassives string[]
local function applyPassiveLists(entity, levelToUse, passiveList, numRandomPassivesPerLevel, appliedPassives)
	Logger:BasicDebug("Applying levels %s to %s of list %s",
		passiveList.useGameLevel and EntityRecorder.Levels[1] or 1,
		passiveList.useGameLevel and EntityRecorder.Levels[levelToUse] or levelToUse,
		passiveList.name .. (passiveList.modId and (" from mod " .. Ext.Mod.GetMod(passiveList.modId).Info.Name) or ""))

	if passiveList.levels then
		for level = 1, levelToUse do
			local leveledLists = passiveList.levels[level]
			---@type EntryName[]
			local randomPool = {}
			if leveledLists then
				if leveledLists.linkedProgressions then
					for progressionId, subLists in pairs(leveledLists.linkedProgressions) do
						if subLists.guaranteed and next(subLists.guaranteed) then
							for _, passiveId in pairs(subLists.guaranteed) do
								if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 then
									Logger:BasicDebug("Adding guaranteed passive %s from progression %s", passiveId, progressionId)
									Osi.AddPassive(entity.Uuid.EntityUuid, passiveId)
									table.insert(appliedPassives, passiveId)
								else
									---@type ResourceProgression
									local progressionResource = Ext.StaticData.Get(progressionId, "Progression")

									Logger:BasicDebug("Guaranteed passive %s from progression %s (%s - level %s) is already known", passiveId, progressionId,
										progressionResource.Name, progressionResource.Level)
								end
							end
						end

						if PassiveListDesigner.progressionTranslations[progressionId] then
							local progressionTable = PassiveListDesigner.progressions[PassiveListDesigner.progressionTranslations[progressionId]]
							if progressionTable and progressionTable[level] and progressionTable[level][PassiveListDesigner.name] then
								for _, passiveId in pairs(progressionTable[level][PassiveListDesigner.name]) do
									if not TableUtils:IndexOf(subLists.blackListed, passiveId) then
										if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 then
											table.insert(randomPool, passiveId)
										else
											---@type ResourceProgression
											local progressionResource = Ext.StaticData.Get(progressionId, "Progression")
											Logger:BasicDebug("%s from progression %s (%s - level %s) is already known, not adding to the random pool", passiveId, progressionId,
												progressionResource.Name, progressionResource.Level)
										end
									end
								end
							end
						end
					end
				end

				if leveledLists.manuallySelectedEntries then
					if leveledLists.manuallySelectedEntries.randomized then
						for _, passiveId in pairs(leveledLists.manuallySelectedEntries.randomized) do
							if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 then
								table.insert(randomPool, passiveId)
							else
								Logger:BasicDebug("%s is already present, not adding to the random pool", passiveId)
							end
						end
					end
					if leveledLists.manuallySelectedEntries.guaranteed and next(leveledLists.manuallySelectedEntries.guaranteed) then
						for _, passiveId in pairs(leveledLists.manuallySelectedEntries.guaranteed) do
							if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 then
								Logger:BasicDebug("Adding guaranteed passive %s", passiveId)
								Osi.AddPassive(entity.Uuid.EntityUuid, passiveId)
								table.insert(appliedPassives, passiveId)
							else
								Logger:BasicDebug("Guaranteed passive %s is already present", passiveId)
							end
						end
					end
				end
			end

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
					Osi.AddPassive(entity.Uuid.EntityUuid, passiveId)
					table.insert(appliedPassives, passiveId)
					Logger:BasicDebug("Added passive %s", passiveId)
				end
			else
				Logger:BasicDebug("Skipping level %s for random passive assignment due to configured size being 0",
					passiveList.useGameLevel and EntityRecorder.Levels[level] or level)
			end
		end
	end
end

function PassiveListMutator:applyMutator(entity, entityVar)
	PassiveListDesigner:buildProgressionIndex()

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
				table.insert(loosePassivesToApply, passive)
			end
		end

		if passiveListMutator.values.passiveLists then
			for _, passiveListId in pairs(passiveListMutator.values.passiveLists) do
				local passiveList = MutationConfigurationProxy.passiveLists[passiveListId]
				passiveList = passiveList.__real or passiveList
				if passiveList then
					if passiveList.spellListDependencies and next(passiveList.spellListDependencies) then
						for _, spellListDependency in ipairs(passiveList.spellListDependencies) do
							if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency] then
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
			if Osi.HasPassive(entity.Uuid.EntityUuid, passiveId) == 0 then
				Logger:BasicDebug("Adding loose passive %s", passiveId)
				Osi.AddPassive(entity.Uuid.EntityUuid, passiveId)
				table.insert(appliedPassives, passiveId)
			else
				Logger:BasicDebug("Loose passive %s is already present", passiveId)
			end
		end
	end

	if next(passiveListsPool) then
		if not usingListsWithSpellListDeps then
			local chosenIndex = math.random(TableUtils:CountElements(passiveListsPool))
			local count = 0
			for passiveListId, numRandomPassivesPerLevel in pairs(passiveListsPool) do
				count = count + 1
				if count == chosenIndex then
					local passiveList = MutationConfigurationProxy.passiveLists[passiveListId]
					passiveList = passiveList.__real or passiveList

					Logger:BasicDebug("%s passive lists without dependencies are in the pool - randomly chose %s",
						TableUtils:CountElements(passiveListsPool),
						passiveList.name .. (passiveList.modId and (" from mod " .. Ext.Mod.GetMod(passiveList.modId).Info.Name) or ""))

					local levelToUse = passiveList.useGameLevel and entity.Level.LevelName or entity.EocLevel.Level
					applyPassiveLists(entity, levelToUse, passiveList, numRandomPassivesPerLevel, appliedPassives)
					break
				end
			end
		else
			for passiveListId, numRandomPassivesPerLevel in pairs(passiveListsPool) do
				local passiveList = MutationConfigurationProxy.passiveLists[passiveListId]
				passiveList = passiveList.__real or passiveList

				local levelToUse = 0
				for _, spellListDependency in pairs(passiveList.spellListDependencies) do
					local appliedSpellListLevel = entityVar.appliedMutators[SpellListMutator.name].appliedLists[spellListDependency]
					if appliedSpellListLevel then
						levelToUse = levelToUse + appliedSpellListLevel
					end
				end

				applyPassiveLists(entity, levelToUse, passiveList, numRandomPassivesPerLevel, appliedPassives)
			end
		end
	end

	if next(appliedPassives) then
		entityVar.originalValues[self.name] = appliedPassives
	end
end
