Ext.Require("Shared/Mutations/Mutators/SpellList/SpellListDesigner.lua")

---@class SpellListMutatorClass : MutatorInterface
SpellListMutator = MutatorInterface:new("SpellList")

---@type ExtComponentType[]
SpellListMutator.affectedComponents = {
	"SpellBook",
	"SpellBookPrepares",
	"SpellContainer",
	"BoostsContainer",
	"StatusContainer"
}

function SpellListMutator:priority()
	return self:recordPriority(LevelMutator:priority() + 1)
end

---@class SpellListAbilityScoreCondition
---@field comparator "gte"|"lte"
---@field value number

---@class SpellListCriteriaEntry
---@field isOneOfClasses Guid[]?
---@field abilityCondition {[AbilityId] : SpellListAbilityScoreCondition}?

---@class LeveledSpellPool
---@field anchorLevel number
---@field spellLists Guid[]
---@field spells CustomSubList?

---@class SpellMutatorGroup
---@field leveledSpellPool LeveledSpellPool[]?
---@field criteria SpellListCriteriaEntry?
---@field removeSpells {[number]: SpellSourceType|EntryName}
---@field randomizedSpellPoolSize number[]

---@class SpellListMutator : Mutator
---@field values SpellMutatorGroup[]
---@field useGameLevel boolean

---@param mutator SpellListMutator
function SpellListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	mutator.useGameLevel = mutator.useGameLevel or false

	Helpers:KillChildren(parent)
	local configuredSpellLists = MutationConfigurationProxy.lists.spellLists

	local spellListDesignerButton = parent:AddButton("Open SpellList Designer")
	spellListDesignerButton.UserData = "EnableForMods"
	spellListDesignerButton.OnClick = function()
		SpellListDesigner:launch()
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

	local displayTable = parent:AddTable("SpellList", 2)
	displayTable.Resizable = true
	displayTable.Borders = true

	local popup = Styler:Popup(parent)

	for sMG, spellMutatorGroup in TableUtils:OrderedPairs(mutator.values) do
		local parentRow = displayTable:AddRow()

		local groupCell = parentRow:AddCell()

		local header = groupCell:AddCollapsingHeader("Group " .. sMG)
		header.IDContext = "Group" .. sMG

		local delete = Styler:ImageButton(header:AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", { 16, 16 }))
		delete:Tooltip():AddText("\t Delete Group")
		delete.OnClick = function()
			for x = sMG, TableUtils:CountElements(mutator.values) do
				mutator.values[x].delete = true
				mutator.values[x] = TableUtils:DeeplyCopyTable(mutator.values._real[x + 1])
			end
			self:renderMutator(parent, mutator)
		end
		local poolGroup = header:AddGroup("Group")
		local function renderPools()
			Helpers:KillChildren(poolGroup)
			local leveledTable = poolGroup:AddTable("leveledTable", 1)
			leveledTable.NoSavedSettings = true
			leveledTable.Borders = true
			if spellMutatorGroup.leveledSpellPool then
				for i, leveledSpellPool in TableUtils:OrderedPairs(spellMutatorGroup.leveledSpellPool, function(_, value)
					return value.anchorLevel
				end) do
					if next(leveledSpellPool._real or leveledSpellPool) then
						local cell = leveledTable:AddRow():AddCell()

						local delete = Styler:ImageButton(cell:AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", Styler:ScaleFactor({ 16, 16 })))
						delete.OnClick = function()
							for x = i, TableUtils:CountElements(spellMutatorGroup.leveledSpellPool) do
								spellMutatorGroup.leveledSpellPool[x].delete = true
								spellMutatorGroup.leveledSpellPool[x] = TableUtils:DeeplyCopyTable(spellMutatorGroup.leveledSpellPool._real[x + 1])
							end

							renderPools()
						end

						cell:AddText("Level is equal to or greater than: ").SameLine = true

						local levelInput = cell:AddSliderInt("###levelInput", leveledSpellPool.anchorLevel, 1, mutator.useGameLevel and #EntityRecorder.Levels or 30)
						if mutator.useGameLevel then
							levelInput.Label = EntityRecorder.Levels[leveledSpellPool.anchorLevel] .. "###levelInput"
						end
						levelInput.OnChange = function()
							---@param anchor number
							---@return number[]
							local function nextAnchor(anchor)
								local index = TableUtils:IndexOf(spellMutatorGroup.leveledSpellPool, function(value)
									return value.anchorLevel == anchor
								end)
								if index and index ~= i and anchor < (mutator.useGameLevel and #EntityRecorder.Levels or 30) then
									return nextAnchor(anchor + 1)
								else
									return { anchor, anchor, anchor, anchor }
								end
							end
							levelInput.Value = nextAnchor(levelInput.Value[1])
							leveledSpellPool.anchorLevel = levelInput.Value[1]
							if mutator.useGameLevel then
								levelInput.Label = EntityRecorder.Levels[leveledSpellPool.anchorLevel] .. "###levelInput"
							end
						end

						local spellListSep = cell:AddSeparatorText("Spell Lists ( ? )")
						spellListSep:SetStyle("SeparatorTextAlign", 0.1)
						spellListSep:Tooltip():AddText(
							"\t Specifying multiple spell lists means one will be randomly chosen to be assigned to an entity - it will not add all of them")

						for sL, spellListId in TableUtils:OrderedPairs(leveledSpellPool.spellLists, function(_, value)
							return configuredSpellLists[value] and configuredSpellLists[value].name
						end) do
							local spellList = configuredSpellLists[spellListId]
							if spellList then
								local text = cell:AddTextLink(spellList.name .. (spellList.modId and string.format(" (%s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
								text.UserData = "EnableForMods"
								text.OnClick = function()
									SpellListDesigner:launch(spellListId)
								end

								if spellList.description ~= "" then
									text:Tooltip():AddText(spellList.description)
								end
							else
								leveledSpellPool.spellLists[sL] = nil
							end
						end

						local addButton = cell:AddButton("Add Spell List")
						addButton.Font = "Small"
						addButton.OnClick = function()
							Helpers:KillChildren(popup)
							popup:Open()

							Styler:BuildCompleteUserAndModLists(popup,
								function(config)
									return config.lists and config.lists.spellLists and next(config.lists.spellLists) and config.lists.spellLists
								end,
								function(key, value)
									return value.name
								end,
								function(_, listItem)
									return mutator.useGameLevel == listItem.useGameLevel
								end,
								function(select, id, item)
									select.Label = item.name
									select.Selected = TableUtils:IndexOf(leveledSpellPool.spellLists, id) ~= nil
									select.OnClick = function()
										local index = TableUtils:IndexOf(leveledSpellPool.spellLists, id)
										if index then
											leveledSpellPool.spellLists[index] = nil
											select.Selected = false
										else
											select.Selected = true
											leveledSpellPool.spellLists = leveledSpellPool.spellLists or {}
											table.insert(leveledSpellPool.spellLists, id)
										end
										renderPools()
									end
								end
							)
						end

						self:buildSpellSelectorSection(cell, spellMutatorGroup, i)
					end
				end
			end
		end
		renderPools()

		local addLeveledPoolButton = header:AddButton("Add Level Pool")
		addLeveledPoolButton.Font = "Small"
		addLeveledPoolButton.OnClick = function()
			Helpers:KillChildren(poolGroup)
			spellMutatorGroup.leveledSpellPool = spellMutatorGroup.leveledSpellPool or {}
			local lastAnchor = 0
			for _, pool in pairs(spellMutatorGroup.leveledSpellPool) do
				lastAnchor = pool.anchorLevel > lastAnchor and pool.anchorLevel or lastAnchor
			end

			table.insert(spellMutatorGroup.leveledSpellPool, {
				anchorLevel = lastAnchor + 1,
				spellLists = {}
			} --[[@as LeveledSpellPool]])

			renderPools()
		end

		local settingsCell = parentRow:AddCell()
		self:renderRandomizedAmountSettings(settingsCell:AddGroup("RandomizedSettings"), spellMutatorGroup)
		self:renderCriteriaSettings(settingsCell:AddGroup("Criteria"), spellMutatorGroup)
		self:renderRemoveSpellsSetting(settingsCell:AddGroup("RemoveSpells"), spellMutatorGroup)

		parentRow:AddNewLine()
	end

	local addGroupButton = parent:AddButton("Add New Group")
	addGroupButton.OnClick = function()
		table.insert(mutator.values, {
		} --[[@as SpellMutatorGroup]])
		self:renderMutator(parent, mutator)
	end
end

---@param parent ExtuiTreeParent
---@param mutatorGroup SpellMutatorGroup
---@param poolIndex number
function SpellListMutator:buildSpellSelectorSection(parent, mutatorGroup, poolIndex)
	if not next(SpellListDesigner.subListIndex.guaranteed.colour) then
		for subListName, colour in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.settings.customLists.subListColours, function(key)
			return SpellListDesigner.subListIndex[key].name
		end) do
			SpellListDesigner.subListIndex[subListName].colour = Styler:ConvertRGBAToIMGUI(colour._real)
		end
	end

	local sep = parent:AddSeparatorText("Spells ( ? )")
	sep:SetStyle("SeparatorTextAlign", 0.1)
	sep:Tooltip():AddText("\t Spells added here are guaranteed to be added to the entity as long as the entity meets the level requirement.")

	local spellGroup = parent:AddGroup("SpellGroup")

	local popup = parent:AddPopup("AddSpells")

	local function renderSpellGroup()
		Helpers:KillChildren(spellGroup)

		if mutatorGroup.leveledSpellPool[poolIndex].spells then
			local counter = 0
			---@type CustomSubList
			local spellSubLists = mutatorGroup.leveledSpellPool[poolIndex].spells
			for spellList, spellPool in TableUtils:OrderedPairs(spellSubLists) do
				for index, spellName in TableUtils:OrderedPairs(spellPool, function(_, value)
					return value
				end) do
					---@type SpellData
					local spell = Ext.Stats.Get(spellName)
					local spellImage = spellGroup:AddImageButton(spellName, spell.Icon, { 48, 48 })
					if spellImage.Image.Icon == "" then
						spellImage:Destroy()
						spellImage = spellGroup:AddImageButton(spellName, "Item_Unknown", { 48, 48 })
					end

					spellImage.SameLine = counter % 6 ~= 0

					spellImage:SetColor("Button", SpellListDesigner.subListIndex[spellList].colour)

					local tooltipFunc = Styler:HyperlinkRenderable(spellImage,
						spellName,
						"Shift",
						true,
						string.format("%s\n%s\n%s",
							spellName,
							Ext.Loca.GetTranslatedString(spell.DisplayName, spellName),
							SpellListDesigner.subListIndex[spellList].name),
						function(parent)
							ResourceManager:RenderDisplayWindow(spell, parent)
						end
					)

					spellImage.OnClick = function()
						if not tooltipFunc() then
							Helpers:KillChildren(popup)
							popup:Open()

							for _, spellCategory in TableUtils:OrderedPairs({ "guaranteed", "startOfCombatOnly", "onLoadOnly" }, function(_, value)
								return value
							end) do
								if spellCategory ~= spellList then
									popup:AddSelectable(SpellListDesigner.subListIndex[spellCategory].name).OnClick = function()
										spellSubLists[spellCategory] = spellSubLists[spellCategory] or {}
										table.insert(spellSubLists[spellCategory], spellName)
										spellPool[index] = nil
										if not spellPool() then
											spellPool.delete = true
											if not spellSubLists() then
												spellSubLists.delete = true
											end
										end
										renderSpellGroup()
									end
								end
							end

							popup:AddSelectable("Delete").OnClick = function()
								spellPool[index] = nil
								if not spellPool() then
									spellPool.delete = true
									if not spellSubLists() then
										spellSubLists.delete = true
									end
								end
								renderSpellGroup()
							end
						end
					end
					counter = counter + 1
				end
			end
		end
	end
	renderSpellGroup()

	local addSpells = parent:AddButton("Add Spells")
	addSpells.Font = "Small"
	addSpells.OnClick = function()
		popup:Open()

		Helpers:KillChildren(popup)

		StatBrowser:Render("SpellData",
			popup,
			nil,
			function(pos)
				return pos % 7 ~= 0
			end,
			function(spellName)
				return TableUtils:IndexOf(mutatorGroup.leveledSpellPool, function(value)
					if value.spells then
						for _, spellList in pairs(value.spells) do
							if TableUtils:IndexOf(spellList, spellName) then
								return true
							end
						end
					end
				end) ~= nil
			end,
			nil,
			function(_, spellName)
				local pool = mutatorGroup.leveledSpellPool[poolIndex]
				local subList = TableUtils:IndexOf(pool and pool.spells, function(value)
					if TableUtils:IndexOf(value, spellName) then
						return true
					end
				end)

				if not subList then
					pool.spells = pool.spells or {
						guaranteed = {}
					} --[[@as CustomSubList]]

					pool.spells.guaranteed = pool.spells.guaranteed or {}

					table.insert(pool.spells.guaranteed, spellName)
				else
					subList = pool.spells[subList]
					local index = TableUtils:IndexOf(subList, spellName)
					for x = index, TableUtils:CountElements(subList) do
						subList[x] = nil
						subList[x] = subList[x + 1]
					end
					if not subList() then
						subList.delete = true
					end
				end
				renderSpellGroup()
			end)
	end
end

---@param parent ExtuiTreeParent
---@param spellMutatorGroup SpellMutatorGroup
function SpellListMutator:renderRandomizedAmountSettings(parent, spellMutatorGroup)
	Helpers:KillChildren(parent)

	local savedPresetSpreads = ConfigurationStructure.config.mutations.settings.customLists.savedSpellListSpreads.spellLists

	local popup = parent:AddPopup("Randomized")

	--#region Randomized Spell Pool Size
	local randoAmountHeader = parent:AddCollapsingHeader("Amount of Random Spells to Give Per Level")

	spellMutatorGroup.randomizedSpellPoolSize = spellMutatorGroup.randomizedSpellPoolSize or {}
	local randomizedSpellPoolSize = spellMutatorGroup.randomizedSpellPoolSize
	if getmetatable(randomizedSpellPoolSize) and getmetatable(randomizedSpellPoolSize).__call and not randomizedSpellPoolSize() then
		spellMutatorGroup.randomizedSpellPoolSize.delete = true
		spellMutatorGroup.randomizedSpellPoolSize = TableUtils:DeeplyCopyTable(savedPresetSpreads["Default"]._real)
		randomizedSpellPoolSize = spellMutatorGroup.randomizedSpellPoolSize
	end

	local randoSpellsTable = randoAmountHeader:AddTable("RandomSpellNumbers", 3)
	randoSpellsTable:AddColumn("", "WidthFixed")

	local headers = randoSpellsTable:AddRow()
	headers.Headers = true
	headers:AddCell()
	headers:AddCell():AddText("Level ( ? )"):Tooltip():AddText([[
	Levels do not need to be consecutive - for example, you can set level 1 to give 3 random spells, and level 5 to give 1 random spell.
This will cause Lab to give the entity 3 random spells from the selected Spell List every level for levels 1-4, and 1 random spell every level from level 5 onwards]])

	headers:AddCell():AddText("# Of Spells ( ? )"):Tooltip():AddText([[
	This represents the amount of Random spells to give the entity from the appropriate level in the Spell List, if the spell list has spells for the appropriate level]])

	local enableDelete = false
	for level, numSpells in TableUtils:OrderedPairs(randomizedSpellPoolSize) do
		local row = randoSpellsTable:AddRow()
		if not enableDelete then
			row:AddCell()
			enableDelete = true
		else
			local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. level, "ico_red_x", { 16, 16 }))
			delete.OnClick = function()
				randomizedSpellPoolSize[level] = nil
				row:Destroy()
			end
		end

		---@param input ExtuiInputInt
		row:AddCell():AddInputInt("", level).OnDeactivate = function(input)
			if not randomizedSpellPoolSize[input.Value[1]] then
				randomizedSpellPoolSize[input.Value[1]] = numSpells
				randomizedSpellPoolSize[level] = nil
				self:renderRandomizedAmountSettings(parent, spellMutatorGroup)
			else
				input.Value = { level, level, level, level }
			end
		end

		---@param input ExtuiInputInt
		row:AddCell():AddInputInt("", numSpells).OnDeactivate = function(input)
			randomizedSpellPoolSize[level] = input.Value[1]
		end
	end

	randoAmountHeader:AddButton("+").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		local add = popup:AddButton("Add Level")
		local input = popup:AddInputInt("", randomizedSpellPoolSize() + 1)
		input.SameLine = true

		local errorText = popup:AddText("Choose a level that isn't already specified")
		errorText:SetColor("Text", Styler:ConvertRGBAToIMGUI({ 255, 100, 100, 0.7 }))
		errorText.Visible = false

		add.OnClick = function()
			if randomizedSpellPoolSize[input.Value[1]] then
				errorText.Visible = true
			else
				randomizedSpellPoolSize[input.Value[1]] = 2
				self:renderRandomizedAmountSettings(parent, spellMutatorGroup)
			end
		end
	end

	local loadButton = randoAmountHeader:AddButton("L")
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
				spellMutatorGroup.randomizedSpellPoolSize.delete = true
				spellMutatorGroup.randomizedSpellPoolSize = TableUtils:DeeplyCopyTable(spread._real)
				self:renderRandomizedAmountSettings(parent, spellMutatorGroup)
			end
		end
	end

	local saveButton = randoAmountHeader:AddButton("S")
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
				savedPresetSpreads[nameInput.Text] = TableUtils:DeeplyCopyTable(randomizedSpellPoolSize._real)
				self:renderRandomizedAmountSettings(parent, spellMutatorGroup)
			else
				overrideConfirmation.Label = string.format("Are you sure you want to override %s?", nameInput.Text)
				overrideConfirmation.Visible = true
			end
		end
	end
end

local classIdToNameCache = {}

---@param parent ExtuiTreeParent
---@param spellMutatorGroup SpellMutatorGroup
function SpellListMutator:renderCriteriaSettings(parent, spellMutatorGroup)
	Helpers:KillChildren(parent)
	local popup = parent:AddPopup("Criteria")

	local criteriaHeader = parent:AddCollapsingHeader("Criteria")
	-- criteriaHeader:SetStyle("SeparatorTextAlign", 0.1)
	-- criteriaHeader:Tooltip():AddText(
	-- 	"\t These criteria can be used to fine tune which entities this Pool should apply to, allowing you to specify multiple Pools in one mutator. If multiple pools apply to the same entity, one will be randomly chosen")

	criteriaHeader:AddSeparatorText("Ability Scores ( ? )"):Tooltip():AddText([[
	If an entity doesn't meet the ability score requirements specified below, they won't be eligible to be assigned this spell pool. Values of <= 1 will be ignored]])

	local displayTable = criteriaHeader:AddTable("abilityScores", 6)

	local row = displayTable:AddRow()
	for i = 1, 6 do
		if (i - 1) % 2 == 0 then
			row = displayTable:AddRow()
		end
		local ability = tostring(Ext.Enums.AbilityId[i])

		local existingCriteria = spellMutatorGroup.criteria and spellMutatorGroup.criteria.abilityCondition and spellMutatorGroup.criteria.abilityCondition[ability]

		row:AddCell():AddText(ability)

		local combo = row:AddCell():AddCombo("")
		combo.WidthFitPreview = true
		combo.Options = { ">=", "<=" }
		combo.SelectedIndex = existingCriteria and existingCriteria.comparator == "lte" and 1 or 0

		local input = row:AddCell():AddInputInt("", existingCriteria and existingCriteria.value)

		combo.OnChange = function()
			if input.Value[1] > 1 then
				if not existingCriteria then
					spellMutatorGroup.criteria = spellMutatorGroup.criteria or {}
					spellMutatorGroup.criteria.abilityCondition = spellMutatorGroup.criteria.abilityCondition or {}
					spellMutatorGroup.criteria.abilityCondition[ability] = spellMutatorGroup.criteria.abilityCondition[ability] or {}
					spellMutatorGroup.criteria.abilityCondition[ability].value = input.Value[1]
				end
				spellMutatorGroup.criteria.abilityCondition[ability].comparator = combo.SelectedIndex == 0 and "gte" or "lte"
			end
		end

		input.OnChange = function()
			if not existingCriteria then
				spellMutatorGroup.criteria = spellMutatorGroup.criteria or {}
				spellMutatorGroup.criteria.abilityCondition = spellMutatorGroup.criteria.abilityCondition or {}
				spellMutatorGroup.criteria.abilityCondition[ability] = spellMutatorGroup.criteria.abilityCondition[ability] or {}
				spellMutatorGroup.criteria.abilityCondition[ability].comparator = combo.SelectedIndex == 0 and "gte" or "lte"
			end
			if input.Value[1] <= 1 then
				spellMutatorGroup.criteria.abilityCondition[ability].delete = true
				if not spellMutatorGroup.criteria.abilityCondition() then
					spellMutatorGroup.criteria.abilityCondition.delete = true
				end
			else
				spellMutatorGroup.criteria.abilityCondition[ability].value = input.Value[1]
			end
		end
	end

	criteriaHeader:AddSeparatorText("Is One Of (Sub)Classes ( ? )"):Tooltip():AddText([[
	If an entity is not one of the specified (sub)classes (accounts for multi-classing), they won't be eligible to be assigned this spell pool. Best paired with with a Class Mutator]])

	local classGroup = criteriaHeader:AddGroup("classes")
	local existingCriteria = spellMutatorGroup.criteria and spellMutatorGroup.criteria.isOneOfClasses

	if not next(classIdToNameCache) then
		for _, classId in pairs(Ext.StaticData.GetAll("ClassDescription")) do
			---@type ResourceClassDescription
			local class = Ext.StaticData.Get(classId, "ClassDescription")

			classIdToNameCache[classId] = class.DisplayName:Get() or class.Name
		end
	end

	local classTable = classGroup:AddTable("classes", 4)
	local function buildClassTable()
		Helpers:KillChildren(classTable)

		if existingCriteria then
			local row = classTable:AddRow()
			local counter = 0
			for i, classId in TableUtils:OrderedPairs(existingCriteria, function(_, classId)
				return classIdToNameCache[classId]
			end) do
				if counter % 4 == 0 then
					row = classTable:AddRow()
				end
				---@type ResourceClassDescription
				local class = Ext.StaticData.Get(classId, "ClassDescription")

				Styler:MiddleAlignedColumnLayout(row:AddCell(), function(ele)
					local delete = Styler:ImageButton(ele:AddImageButton("delete" .. classId, "ico_red_x", { 16, 16 }))
					delete.OnClick = function()
						for x = i, TableUtils:CountElements(existingCriteria) do
							existingCriteria[x] = nil
							existingCriteria[x] = existingCriteria[x + 1]
						end
						buildClassTable()
					end

					Styler:HyperlinkText(ele, class.DisplayName:Get() or class.Name, function(parent)
						ResourceManager:RenderDisplayWindow(class, parent)
					end).SameLine = true
				end)

				counter = counter + 1
			end
		end
	end
	buildClassTable()

	classGroup:AddButton("+##class").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		local input = popup:AddInputText("")
		input.Hint = "Shift-click on items to pop out their tooltips"

		local resultsGroup = popup:AddChildWindow("results")
		resultsGroup.NoSavedSettings = true
		resultsGroup.Size = { 0, 300 * Styler:ScaleFactor() }
		local timer
		input.OnChange = function()
			if timer then
				Ext.Timer.Cancel(timer)
			end

			Helpers:KillChildren(resultsGroup)
			timer = Ext.Timer.WaitFor(300, function()
				local value = input.Text:upper()
				local results = {}

				for _, classId in pairs(Ext.StaticData.GetAll("ClassDescription")) do
					if classIdToNameCache[classId]:find(value) then
						table.insert(results, classId)
					end
				end

				table.sort(results, function(a, b)
					return classIdToNameCache[a] < classIdToNameCache[b]
				end)

				for _, classId in ipairs(results) do
					---@type ResourceClassDescription
					local class = Ext.StaticData.Get(classId, "ClassDescription")

					---@type ExtuiSelectable
					local select = resultsGroup:AddSelectable(classIdToNameCache[classId] .. "##" .. classId)
					select.Selected = existingCriteria and TableUtils:IndexOf(existingCriteria, classId) ~= nil or false

					local toolTipFunc = Styler:HyperlinkRenderable(select,
						classIdToNameCache[classId],
						"Shift",
						nil,
						nil,
						function(parent)
							ResourceManager:RenderDisplayWindow(class, parent)
						end
					)

					select.OnClick = function()
						if not toolTipFunc() then
							if not select.Selected then
								for x = TableUtils:IndexOf(existingCriteria, classId), TableUtils:CountElements(existingCriteria) do
									existingCriteria[x] = nil
									existingCriteria[x] = existingCriteria[x + 1]
								end
							else
								if not existingCriteria then
									spellMutatorGroup.criteria = spellMutatorGroup.criteria or {}
									spellMutatorGroup.criteria.isOneOfClasses = spellMutatorGroup.criteria.isOneOfClasses or {}
									existingCriteria = spellMutatorGroup.criteria.isOneOfClasses
								end
								table.insert(existingCriteria, classId)
							end
							buildClassTable()
						end
					end
				end
			end)
		end
		input:OnChange()
	end
end

---@param parent ExtuiTreeParent
---@param spellMutatorGroup SpellMutatorGroup
function SpellListMutator:renderRemoveSpellsSetting(parent, spellMutatorGroup)
	Helpers:KillChildren(parent)
	local removeSpellsHeader = parent:AddCollapsingHeader("Spell Sources/Spells To Remove")

	local popup = removeSpellsHeader:AddPopup("removeSpells")
	popup:SetColor("Border", Styler:ConvertRGBAToIMGUI({ 255, 0, 0, 0.6 }))

	local existingCriteria = spellMutatorGroup.removeSpells

	local displayTable = removeSpellsHeader:AddTable("removeSpells", 3)
	local function renderSpellTable()
		Helpers:KillChildren(displayTable)
		if existingCriteria then
			local row = displayTable:AddRow()
			local counter = 0
			for i, toRemove in TableUtils:OrderedPairs(existingCriteria, function(_, value)
				return value
			end) do
				if counter % 3 == 0 then
					row = displayTable:AddRow()
				end
				Styler:MiddleAlignedColumnLayout(row:AddCell(), function(ele)
					local delete = Styler:ImageButton(ele:AddImageButton("delete" .. toRemove, "ico_red_x", { 16, 16 }))
					delete.OnClick = function()
						for x = i, TableUtils:CountElements(existingCriteria) do
							existingCriteria[x] = nil
							existingCriteria[x] = existingCriteria[x + 1]
						end
						renderSpellTable()
					end

					if not Ext.Enums.SpellSourceType[toRemove] then
						---@type SpellData
						local spell = Ext.Stats.Get(toRemove)

						Styler:HyperlinkText(ele, spell.Name, function(parent)
							ResourceManager:RenderDisplayWindow(spell, parent)
						end).SameLine = true
					else
						ele:AddText(toRemove).SameLine = true
					end
				end)

				counter = counter + 1
			end
		end
	end

	renderSpellTable()

	removeSpellsHeader:AddButton("+##remove").OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		---@type ExtuiMenu
		local menu = popup:AddMenu("Spell Sources ( ? )")
		menu:Tooltip():AddText([[
	These represent the registered source of the spell in the entity's spellbook - when specified, all spells with this type will attempt to be removed
This may not always succeed depending on the nature of the sourceType. Use the Entity Inspector to investigate existing patterns.
SpellSet are specified in the template under the same name, SpellSet2 are added via the SkillList in the template, Osiris are added via Osi.AddSpell and other methods, Boosts are usually equipment actions]])

		for i in ipairs(Ext.Enums.SpellSourceType) do
			i = i - 1
			local sourceType = tostring(Ext.Enums.SpellSourceType[i])

			---@type ExtuiSelectable
			local select = menu:AddSelectable(sourceType, "DontClosePopups")

			select.Selected = TableUtils:IndexOf(existingCriteria, sourceType) ~= nil

			select.OnClick = function()
				if select.Selected then
					if not existingCriteria then
						spellMutatorGroup.removeSpells = {}
						existingCriteria = spellMutatorGroup.removeSpells
					end
					table.insert(existingCriteria, sourceType)
				else
					for x = TableUtils:IndexOf(existingCriteria, sourceType), TableUtils:CountElements(existingCriteria) do
						existingCriteria[x] = nil
						existingCriteria[x] = existingCriteria[x + 1]
					end
				end
				renderSpellTable()
			end
		end

		popup:AddSeparatorText("Search Spells")

		StatBrowser:Render("SpellData",
			popup,
			nil,
			function(pos)
				return pos % 8 ~= 0
			end,
			function(spellName)
				return TableUtils:IndexOf(existingCriteria, spellName) ~= nil
			end,
			nil,
			function(_, spellName)
				if not TableUtils:IndexOf(existingCriteria, spellName) then
					if not existingCriteria then
						spellMutatorGroup.removeSpells = {}
						existingCriteria = spellMutatorGroup.removeSpells
					end
					table.insert(existingCriteria, spellName)
				else
					for x = TableUtils:IndexOf(existingCriteria, spellName), TableUtils:CountElements(existingCriteria) do
						existingCriteria[x] = nil
						existingCriteria[x] = existingCriteria[x + 1]
					end
				end
				renderSpellTable()
			end)
	end
end

---@param mutator SpellListMutator
function SpellListMutator:handleDependencies(export, mutator, removeMissingDependencies)
	---@param spellName string
	---@param container table?
	---@return boolean?
	local function buildSpellDep(spellName, container)
		---@type SpellData?
		local spell = Ext.Stats.Get(spellName)
		if spell then
			if not removeMissingDependencies then
				container = container or mutator
				container.modDependencies = container.modDependencies or {}
				if not container.modDependencies[spell.OriginalModId] then
					local name, author, version = Helpers:BuildModFields(spell.OriginalModId)
					if author == "Larian" then
						return true
					end

					container.modDependencies[spell.OriginalModId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = spell.OriginalModId,
						packagedItems = {}
					}
				end
				container.modDependencies[spell.OriginalModId].packagedItems[spellName] = Ext.Loca.GetTranslatedString(spell.DisplayName, spellName)
			end
			return true
		else
			return false
		end
	end

	for _, spellGroup in pairs(mutator.values) do
		if spellGroup.removeSpells then
			for i, spellToRemove in pairs(spellGroup.removeSpells) do
				if not buildSpellDep(spellToRemove) then
					spellGroup.removeSpells[i] = nil
				end
			end
			TableUtils:ReindexNumericTable(spellGroup.removeSpells)
		end

		if spellGroup.leveledSpellPool then
			for _, leveledSpellPool in pairs(spellGroup.leveledSpellPool) do
				if leveledSpellPool.spells then
					for _, spells in pairs(leveledSpellPool.spells) do
						for i, spell in pairs(spells) do
							if not buildSpellDep(spell) then
								spells[i] = nil
							end
						end
						TableUtils:ReindexNumericTable(spells)
					end
				end

				if leveledSpellPool.spellLists then
					ListConfigurationManager:HandleDependences(export, mutator, leveledSpellPool.spellLists, removeMissingDependencies, SpellListDesigner.configKey)
				end
			end
		end

		if spellGroup.criteria then
			if spellGroup.criteria.isOneOfClasses then
				local classSources = Ext.StaticData.GetSources("ClassDescription")
				for i, classId in pairs(spellGroup.criteria.isOneOfClasses) do
					---@type ResourceClassDescription
					local class = Ext.StaticData.Get(classId, "ClassDescription")
					if not class then
						spellGroup.criteria.isOneOfClasses[i] = nil
					elseif not removeMissingDependencies then
						local source = TableUtils:IndexOf(classSources, function(value)
							return TableUtils:IndexOf(value, classId) ~= nil
						end)
						if source then
							mutator.modDependencies = mutator.modDependencies or {}
							if not mutator.modDependencies[source] then
								local name, author, version = Helpers:BuildModFields(source)
								if author == "Larian" then
									goto continue
								end
								mutator.modDependencies[source] = {
									modName = name,
									modAuthor = author,
									modVersion = version,
									modId = source,
									packagedItems = {}
								}
							end
							---@type ResourceClassDescription
							local class = Ext.StaticData.Get(classId, "ClassDescription")

							mutator.modDependencies[source][classId] = class.DisplayName:Get() or class.Name
						end
						::continue::
					end
				end
				TableUtils:ReindexNumericTable(spellGroup.criteria.isOneOfClasses)
			end
		end
	end
end

function SpellListMutator:canBeAdditive()
	return true
end

local SPELL_MUTATOR_ON_COMBAT_START = ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME .. "SpellsOnCombatStart"
Ext.Vars.RegisterUserVariable(SPELL_MUTATOR_ON_COMBAT_START, {
	Server = true,
	Client = true,
	SyncToClient = true
})

local SPELL_MUTATOR_ON_DEATH = ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME .. "SpellsOnDeath"
Ext.Vars.RegisterUserVariable(SPELL_MUTATOR_ON_DEATH, {
	Server = true,
	Client = true,
	SyncToClient = true
})

if Ext.IsServer() then
	Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatGuid)
		for _, entityId in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
			entityId = entityId[1]
			---@type EntityHandle
			local entity = Ext.Entity.Get(entityId)

			if entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] then
				---@type MutatorEntityVar
				local entityVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME]

				entityVar.originalValues[SpellListMutator.name].castedSpells = entityVar.originalValues[SpellListMutator.name].castedSpells or {}

				local castedSpells = entityVar.originalValues[SpellListMutator.name].castedSpells

				for _, spellName in pairs(entity.Vars[SPELL_MUTATOR_ON_COMBAT_START]) do
					Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid)
					table.insert(castedSpells, spellName)

					Logger:BasicDebug("%s cast on Combat Start Spell %s",
						entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
						spellName)
				end

				entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = entityVar
				entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] = nil
			end
		end
	end)

	Ext.Osiris.RegisterListener("Died", 1, "after", function(character)
		---@type EntityHandle
		local entity = Ext.Entity.Get(character)
		if entity.Vars[SPELL_MUTATOR_ON_DEATH] then
			---@type MutatorEntityVar
			local entityVar = entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] or {}
			entityVar.originalValues = entityVar.originalValues or {}
			entityVar.originalValues[SpellListMutator.name] = entityVar.originalValues[SpellListMutator.name] or {}
			entityVar.originalValues[SpellListMutator.name].castedSpells = entityVar.originalValues[SpellListMutator.name].castedSpells or {}

			local castedSpells = entityVar.originalValues[SpellListMutator.name].castedSpells

			for _, spellName in pairs(entity.Vars[SPELL_MUTATOR_ON_DEATH]) do
				Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid)
				table.insert(castedSpells, spellName)

				Logger:BasicDebug("%s cast On Death Spell %s",
					entity.DisplayName and entity.DisplayName.Name:Get() or entity.ServerCharacter.Template.Name,
					spellName)
			end

			entity.Vars[ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME] = entityVar
			entity.Vars[SPELL_MUTATOR_ON_DEATH] = nil
		end
	end)


	---@class SpellListOriginalValues
	---@field removedSpells SpellSpellMeta[]
	---@field addedSpells EntryName[]
	---@field castedSpells EntryName[]

	function SpellListMutator:undoMutator(entity, mutator)
		entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] = nil

		---@type EsvSpellSpellSystem
		local spellSystem = Ext.System.ServerSpell

		---@type SpellListOriginalValues?
		local origValues = mutator.originalValues[self.name]
		if origValues then
			if origValues.addedSpells then
				spellSystem.RemoveSpell[entity] = spellSystem.RemoveSpell[entity] or {}
				local removeSpells = spellSystem.RemoveSpell[entity]
				for _, spell in pairs(entity.SpellBook.Spells) do
					if TableUtils:IndexOf(origValues.addedSpells, spell.Id.OriginatorPrototype) then
						Logger:BasicDebug("Removed %s as it was given by Lab", spell.Id.OriginatorPrototype)
						removeSpells[#removeSpells + 1] = spell.Id
					end
				end
			end

			if origValues.removedSpells then
				spellSystem.AddSpells[entity] = spellSystem.AddSpells[entity] or {}

				local addSpells = spellSystem.AddSpells[entity]

				for _, spell in pairs(origValues.removedSpells) do
					if not TableUtils:IndexOf(entity.SpellBook.Spells, function(value)
							return value.Id.OriginatorPrototype == (spell.SpellId or spell.Id).OriginatorPrototype
						end) then
						Logger:BasicDebug("Adding %s back as it was removed by Lab", spell.SpellId and spell.SpellId.OriginatorPrototype or spell.Id.OriginatorPrototype)
						addSpells[#addSpells + 1] = spell
					else
						Logger:BasicDebug("Not adding %s back as the entity has it even though it was removed by Lab",
							spell.SpellId and spell.SpellId.OriginatorPrototype or spell.Id.OriginatorPrototype)
					end
				end
			end

			if origValues.castedSpells or origValues.addedSpells then
				local toRemove = {}
				for _, status in pairs(entity.ServerCharacter.StatusManager.Statuses) do
					if status.SourceSpell
						and status.SourceSpell.SourceType == "Osiris"
						and (TableUtils:IndexOf(origValues.castedSpells, status.SourceSpell.OriginatorPrototype)
							or TableUtils:IndexOf(origValues.addedSpells, status.SourceSpell.OriginatorPrototype))
					then
						Logger:BasicDebug("Removed status %s as it was applied by Lab via spell %s", status.StatusId, status.SourceSpell.OriginatorPrototype)
						-- Osi.RemoveStatus insta updates the StatusManager, shifting indexes, which can cause this loop to skip over a status
						table.insert(toRemove, status.StatusId)
					end
				end
				for _, statusId in pairs(toRemove) do
					Osi.RemoveStatus(entity.Uuid.EntityUuid, statusId)
				end

				local weapon = Osi.GetEquippedWeapon(entity.Uuid.EntityUuid)
				if weapon then
					weapon = Ext.Entity.Get(weapon)
					---@cast weapon EntityHandle

					local toRemove = {}
					for _, status in pairs(weapon.ServerItem.StatusManager.Statuses) do
						if status.SourceSpell
							and status.SourceSpell.SourceType == "Osiris"
							and (TableUtils:IndexOf(origValues.castedSpells, status.SourceSpell.OriginatorPrototype)
								or TableUtils:IndexOf(origValues.addedSpells, status.SourceSpell.OriginatorPrototype))
						then
							Logger:BasicDebug("Removed status %s from weapon %s_%s as it was applied by Lab via spell %s",
								status.StatusId,
								weapon.ServerItem.Template.Name,
								weapon.Uuid.EntityUuid,
								status.SourceSpell.OriginatorPrototype)
							-- Osi.RemoveStatus insta updates the StatusManager, shifting indexes, which can cause this loop to skip over a status
							table.insert(toRemove, status.StatusId)
						end
					end
					for _, statusId in pairs(toRemove) do
						Osi.RemoveStatus(weapon.Uuid.EntityUuid, statusId)
					end
				end
			end
		end
	end

	---@param subLists CustomSubList
	---@param entity EntityHandle
	---@param addSpells {[EntityHandle]: SpellSpellMeta[]}
	---@param origValues SpellListOriginalValues
	function SpellListMutator:processSubLists(subLists, entity, addSpells, origValues)
		for subListName, spells in pairs(subLists) do
			for _, spellName in pairs(spells) do
				if subListName == "guaranteed" then
					if not TableUtils:IndexOf(entity.SpellBook.Spells, function(value)
							return value.Id.OriginatorPrototype == spellName
						end)
					then
						addSpells[#addSpells + 1] = {
							PrepareType = "AlwaysPrepared",
							SpellId = {
								OriginatorPrototype = spellName,
								SourceType = "SpellSet2",
								Source = ModuleUUID
							},
							PreferredCastingResource = "d136c5d9-0ff0-43da-acce-a74a07f8d6bf",
							SpellCastingAbility = entity.Stats.SpellCastingAbility
						}

						origValues.addedSpells = origValues.addedSpells or {}
						table.insert(origValues.addedSpells, spellName)
						Logger:BasicDebug("Added guaranteed spell %s", spellName)
					end
				elseif subListName == "onDeathOnly" then
					entity.Vars[SPELL_MUTATOR_ON_DEATH] = entity.Vars[SPELL_MUTATOR_ON_DEATH] or {}

					table.insert(entity.Vars[SPELL_MUTATOR_ON_DEATH], spellName)
				elseif subListName == "startOfCombatOnly" then
					if Osi.IsInCombat(entity.Uuid.EntityUuid) == 1 then
						Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid)

						origValues.castedSpells = origValues.castedSpells or {}

						table.insert(origValues.castedSpells, spellName)

						Logger:BasicDebug("Used on combat spell %s", spellName)
					else
						entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] = entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] or {}

						table.insert(entity.Vars[SPELL_MUTATOR_ON_COMBAT_START], spellName)
					end
				elseif subListName == "onLoadOnly" then
					if Osi.IsDead(entity.Uuid.EntityUuid) == 0 then
						Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid)

						origValues.castedSpells = origValues.castedSpells or {}
						table.insert(origValues.castedSpells, spellName)
						Logger:BasicDebug("Used on level load spell %s", spellName)
					elseif not entity.DeadByDefault then
						entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] = entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] or {}
						table.insert(entity.Vars[SPELL_MUTATOR_ON_COMBAT_START], spellName)

						Logger:BasicDebug("Moved level load spell %s into on combat start as this entity doesn't start as dead, so it's probably just playing dead right now",
							spellName)
					else
						Logger:BasicDebug("Skipping level load spell %s as this entity is dead, for real", spellName)
					end
				end
			end
		end
	end

	function SpellListMutator:applyMutator(entity, entityVar)
		ListConfigurationManager:buildProgressionIndex()
		---@type EsvSpellSpellSystem
		local spellSystem = Ext.System.ServerSpell

		local spellListMutators = entityVar.appliedMutators[self.name]
		if not spellListMutators[1] then
			spellListMutators = { spellListMutators }
		end

		local replaceMap = TableUtils:DeeplyCopyTable(ConfigurationStructure.config.mutations.lists.entryReplacerDictionary)
		replaceMap.spellLists = replaceMap.spellLists or {}

		---@cast spellListMutators SpellListMutator[]

		spellSystem.AddSpells[entity] = spellSystem.AddSpells[entity] or {}
		local addSpells = spellSystem.AddSpells[entity]

		---@type SpellMutatorGroup[]
		local groupsToApply = {}
		---@type number[]
		local groupToListMap = {}

		for m, mutator in ipairs(spellListMutators) do
			--#region Criteria
			local keep = false
			for g, spellMutatorGroup in ipairs(mutator.values) do
				if not spellMutatorGroup.leveledSpellPool then
					Logger:BasicDebug("Skipped group %s due to not having a leveledSpellPool available", g)
					goto next_group
				end
				if spellMutatorGroup.criteria then
					---@type SpellListCriteriaEntry
					local criteria = spellMutatorGroup.criteria

					if criteria.abilityCondition then
						for ability, condition in pairs(criteria.abilityCondition) do
							local score = entity.BaseStats.BaseAbilities[Ext.Enums.AbilityId[ability].Value + 1]
							if (condition.comparator == "gte" and score < condition.value)
								or (condition.comparator == "lte" and score > condition.value)
							then
								Logger:BasicDebug("Skipped Group %s due to %s being %s than %s (was %s)",
									g,
									ability,
									condition.comparator == "gte" and "less than" or "greater than",
									condition.value,
									score)

								spellListMutators[g] = nil
								goto next_group
							end
						end
					end

					if criteria.isOneOfClasses and next(criteria.isOneOfClasses) then
						for _, classId in pairs(criteria.isOneOfClasses) do
							for _, class in pairs(entity.Classes.Classes) do
								if class.ClassUUID == classId or class.SubClassUUID == classId then
									goto success
								end
							end
						end
						Logger:BasicDebug("Skipped Group %s due to entity not being one of the right classes", g)
						spellListMutators[g] = nil
						goto next_group

						::success::
					end
				end
				keep = true
				table.insert(groupsToApply, spellMutatorGroup)
				groupToListMap[#groupsToApply] = m

				::next_group::
			end
			if not keep then
				spellListMutators[m] = nil
			end
		end
		--#endregion

		local useGameLevel = false
		local spellMutatorGroup
		if #groupsToApply == 1 then
			spellMutatorGroup = groupsToApply[1]
			useGameLevel = spellListMutators[groupToListMap[1]].useGameLevel
		elseif #groupsToApply > 1 then
			local chosenGroup = math.random(#groupsToApply)
			spellMutatorGroup = groupsToApply[chosenGroup]
			useGameLevel = spellListMutators[groupToListMap[chosenGroup]].useGameLevel
		end

		if spellMutatorGroup then
			entityVar.originalValues[self.name] = entityVar.originalValues[self.name] or {
				addedSpells = {},
				castedSpells = {},
				removedSpells = {}
			} --[[@as SpellListOriginalValues]]

			---@type SpellListOriginalValues
			local origValues = entityVar.originalValues[self.name]

			if spellMutatorGroup.removeSpells then
				spellSystem.RemoveSpell = spellSystem.RemoveSpell or {}
				spellSystem.RemoveSpell[entity] = spellSystem.RemoveSpell[entity] or {}
				local removeSpells = spellSystem.RemoveSpell[entity]

				for _, spellSourceOrName in pairs(spellMutatorGroup.removeSpells) do
					-- Changes directly made to the TemplateUsedForSpells aren't persisted across saves, so don't need to record those for the undo
					if spellSourceOrName == "SpellSet2" then
						if Logger:IsLogLevelEnabled(Logger.PrintTypes.DEBUG) then
							for _, skill in pairs(entity.ServerCharacter.TemplateUsedForSpells.SkillList) do
								Logger:BasicDebug("Removing spell %s for being part of SpellSet2", skill.Spell)
							end
						end
						entity.ServerCharacter.TemplateUsedForSpells.SkillList = {}
					elseif spellSourceOrName == "SpellSet" then
						Logger:BasicDebug("Removing SpellSet from template %s",
							entity.ServerCharacter.TemplateUsedForSpells.Name .. "_" .. entity.ServerCharacter.TemplateUsedForSpells.Id)

						entity.ServerCharacter.TemplateUsedForSpells.SpellSet = ""
					else
						for _, spell in pairs(entity.SpellBook.Spells) do
							if spell.Id.SourceType == spellSourceOrName or spell.Id.OriginatorPrototype == spellSourceOrName then
								Logger:BasicDebug("Removing spell %s because %s was specified", spell.Id.OriginatorPrototype, spellSourceOrName)
								table.insert(origValues.addedSpells, Ext.Types.Serialize(spell))
								removeSpells[#removeSpells + 1] = spell.Id
							end
						end
						if not next(origValues.addedSpells) then
							origValues.addedSpells = nil
						end
					end
				end
			end

			--- {maxLevelOfAssignedSpellList : spellListId}
			---@alias AppliedSpellLists Guid[]
			---@type AppliedSpellLists
			local appliedLists = {}

			local appliedSpellListsForEntityVar = {}

			TableUtils:ReindexNumericTable(spellMutatorGroup.leveledSpellPool, function(key, value)
				return value.anchorLevel
			end)

			for lSP, leveledSpellPool in ipairs(spellMutatorGroup.leveledSpellPool) do
				if (useGameLevel and EntityRecorder.Levels[entity.Level.LevelName] >= leveledSpellPool.anchorLevel)
					or (not useGameLevel and entity.AvailableLevel and entity.AvailableLevel.Level >= leveledSpellPool.anchorLevel)
				then
					-- Osi.CreateAt("01fa8d64-f63e-4bb8-9ee4-cba84dad3781", 202, 25, 418, 0, 0, "")
					-- Osi.SetRelationTemporaryHostile("5ebcd998-e4ae-1a42-202c-3619bced3eea", _C().Uuid.EntityUuid)
					if leveledSpellPool.spells then
						self:processSubLists(leveledSpellPool.spells, entity, addSpells, origValues)
					end

					if leveledSpellPool.spellLists then
						TableUtils:ReindexNumericTable(leveledSpellPool.spellLists)

						local spellListId
						if #leveledSpellPool.spellLists > 1 then
							spellListId = leveledSpellPool.spellLists[math.random(#leveledSpellPool.spellLists)]
						else
							spellListId = leveledSpellPool.spellLists[1]
						end

						if spellListId and MutationConfigurationProxy.lists.spellLists[spellListId] then
							local nextAnchor = math.min(
								spellMutatorGroup.leveledSpellPool[lSP + 1]
								and spellMutatorGroup.leveledSpellPool[lSP + 1].anchorLevel - 1
								or (useGameLevel and #EntityRecorder.Levels or 30),
								useGameLevel and EntityRecorder.Levels[entity.Level.LevelName] or entity.EocLevel.Level)

							local maxAppliedLevel = 0
							for level in pairs(appliedLists) do
								if level > maxAppliedLevel then
									maxAppliedLevel = level
								end
							end
							local startingSpellListLevel = TableUtils:IndexOf(appliedLists, spellListId) or 0

							if TableUtils:IndexOf(appliedLists, spellListId) then
								appliedLists[startingSpellListLevel] = nil
								startingSpellListLevel = startingSpellListLevel + 1
								maxAppliedLevel = 0
							end
							local cLevel = nextAnchor - maxAppliedLevel

							local mainSpellList = MutationConfigurationProxy.lists.spellLists[spellListId]

							local function applySpellList(spellListId)
								if not appliedLists[nextAnchor] then
									appliedLists[nextAnchor] = spellListId
								end

								appliedSpellListsForEntityVar[spellListId] = (appliedSpellListsForEntityVar[spellListId] or 0) + math.max(1, (cLevel - startingSpellListLevel))

								local spellList = TableUtils:DeeplyCopyTable(MutationConfigurationProxy.lists.spellLists[spellListId]._real or
									MutationConfigurationProxy.lists.spellLists[spellListId])

								Logger:BasicDebug("Selected spellList %s (%s) for anchor level %s, using levels %s-%s",
									spellList.name .. (spellList.modId and (" from mod " .. Ext.Mod.GetMod(spellList.modId).Info.Name) or ""),
									spellListId,
									useGameLevel and EntityRecorder.Levels[leveledSpellPool.anchorLevel] or leveledSpellPool.anchorLevel,
									useGameLevel and EntityRecorder.Levels[startingSpellListLevel == 0 and 1 or startingSpellListLevel] or startingSpellListLevel,
									useGameLevel and EntityRecorder.Levels[cLevel] or cLevel)

								if spellList.modId then
									local modMap = MutationConfigurationProxy.lists.entryReplacerDictionary.spellLists[spellList.modId]
									if modMap then
										for replacer, toReplaceList in pairs(modMap) do
											if not replaceMap.spellLists[replaceMap.spellLists] then
												replaceMap.spellLists[replacer] = TableUtils:DeeplyCopyTable(toReplaceList)
											else
												for _, toReplace in ipairs(toReplaceList) do
													if not TableUtils:IndexOf(replaceMap.spellLists[replacer]) then
														table.insert(replaceMap.spellLists[replacer], toReplace)
													end
												end
											end
										end
										Logger:BasicDebug("Added replacer map entries from Mod %s's replaceMap as it was chosen to be applied",
											Ext.Mod.GetMod(spellList.modId).Info.Name)
									end
								end

								for i = startingSpellListLevel, cLevel do
									---@type EntryName[]
									local randomPool = {}
									if spellList.linkedProgressionTableIds and next(spellList.linkedProgressionTableIds._real or spellList.linkedProgressionTableIds) then
										for _, progressionTableId in pairs(spellList.linkedProgressionTableIds) do
											local progressionTable = ListConfigurationManager.progressionIndex[progressionTableId]
											if progressionTable then
												for _, progressionLevel in pairs(progressionTable.progressionLevels) do
													if progressionLevel.level == i and progressionLevel.spellLists then
														for _, spells in pairs(progressionLevel.spellLists) do
															for _, spellName in pairs(spells) do
																local leveledLists = spellList.levels and spellList.levels[i]
																if (not leveledLists
																		or not leveledLists.linkedProgressions
																		or not TableUtils:IndexOf(leveledLists.linkedProgressions[progressionTableId],
																			function(value)
																				return TableUtils:IndexOf(value, spellName) ~= nil
																			end))
																	and (not spellList.blacklistSameEntriesInHigherProgressionLevels or not ListConfigurationManager:hasSameEntryInLowerLevel(progressionTableId, i, spellName, "spellLists"))
																then
																	spellList.levels = spellList.levels or {}
																	spellList.levels[i] = spellList.levels[i] or {}
																	spellList.levels[i].linkedProgressions = spellList.levels[i].linkedProgressions or {}
																	spellList.levels[i].linkedProgressions[progressionTableId] = spellList.levels[i].linkedProgressions
																		[progressionTableId] or {}

																	local defaultPool = spellList.defaultPool or
																		ConfigurationStructure.config.mutations.settings.customLists.defaultPool.spellLists

																	spellList.levels[i].linkedProgressions[progressionTableId][defaultPool] = spellList.levels[i].linkedProgressions
																		[progressionTableId][defaultPool] or {}

																	Logger:BasicDebug("Added %s to the default pool %s for later processing", spellName, defaultPool)
																	table.insert(spellList.levels[i].linkedProgressions[progressionTableId][defaultPool], spellName)
																end
															end
														end
													end
												end
											end
										end
									end
									if spellList.levels then
										local leveledLists = spellList.levels[i]
										if leveledLists then
											if leveledLists.linkedProgressions then
												for progressionTableId, subLists in pairs(leveledLists.linkedProgressions) do
													local progressionTable = ListConfigurationManager.progressionIndex[progressionTableId]
													if progressionTable then
														self:processSubLists(subLists, entity, addSpells, origValues)
														if subLists.randomized then
															for _, spellName in pairs(subLists.randomized) do
																if not TableUtils:IndexOf(entity.SpellBook.Spells, function(value)
																		return value.Id.OriginatorPrototype == spellName
																	end)
																then
																	if not TableUtils:IndexOf(randomPool, spellName) then
																		table.insert(randomPool, spellName)
																	end
																else
																	Logger:BasicDebug(
																		"Randomized spell %s from progression %s (%s - level %s) is already known, not adding to the random pool",
																		spellName,
																		progressionTableId, progressionTable.name, i)
																end
															end
														end
													end
												end
											end
											if leveledLists.manuallySelectedEntries then
												self:processSubLists(leveledLists.manuallySelectedEntries, entity, addSpells, origValues)

												if leveledLists.manuallySelectedEntries.randomized then
													for _, spellName in pairs(leveledLists.manuallySelectedEntries.randomized) do
														if not TableUtils:IndexOf(entity.SpellBook.Spells, function(value)
																return value.Id.OriginatorPrototype == spellName
															end)
														then
															if not TableUtils:IndexOf(randomPool, spellName) then
																table.insert(randomPool, spellName)
															end
														else
															Logger:BasicDebug("%s is already known, not adding to the random pool", spellName)
														end
													end
												end
											end
										end
									end

									local numRandomSpellsToPick = 0
									if spellMutatorGroup.randomizedSpellPoolSize[maxAppliedLevel + i] then
										numRandomSpellsToPick = spellMutatorGroup.randomizedSpellPoolSize[maxAppliedLevel + i]
									else
										local maxLevel = nil
										for level, _ in pairs(spellMutatorGroup.randomizedSpellPoolSize) do
											if level < (maxAppliedLevel + i) and (not maxLevel or level > maxLevel) then
												maxLevel = level
											end
										end
										if maxLevel then
											numRandomSpellsToPick = spellMutatorGroup.randomizedSpellPoolSize[maxLevel]
										end
									end

									if numRandomSpellsToPick > 0 then
										Logger:BasicDebug("Giving %s random spells out of %s from level %s", numRandomSpellsToPick, #randomPool,
											useGameLevel and EntityRecorder.Levels[i] or i)
										local spellsToGive = {}
										if #randomPool <= numRandomSpellsToPick then
											spellsToGive = randomPool
										else
											for _ = 1, numRandomSpellsToPick do
												local num = math.random(#randomPool)
												table.insert(spellsToGive, randomPool[num])
												table.remove(randomPool, num)
											end
										end

										for _, spellName in pairs(spellsToGive) do
											---@type SpellData
											local spell = Ext.Stats.Get(spellName)

											addSpells[#addSpells + 1] = {
												PrepareType = "AlwaysPrepared",
												SpellId = {
													OriginatorPrototype = spellName,
													SourceType = "SpellSet2"
												},
												PreferredCastingResource = "d136c5d9-0ff0-43da-acce-a74a07f8d6bf",
												SpellCastingAbility = entity.Stats.SpellCastingAbility,
												CooldownType = Ext.Enums.SpellCooldownType[CooldownType[spell.Cooldown]]
											}

											origValues.addedSpells = origValues.addedSpells or {}
											table.insert(origValues.addedSpells, spellName)
											Logger:BasicDebug("Added spell %s", spellName)
										end
									else
										Logger:BasicDebug("Skipping level %s for random spell assignment due to configured size being 0",
											useGameLevel and EntityRecorder.Levels[maxAppliedLevel + i] or maxAppliedLevel + i)
									end
								end
							end
							applySpellList(spellListId)

							local appliedLinkedLists = { spellListId }
							---@param list SpellList
							local function recursivelyApplyLinkedLists(list)
								if list.linkedLists and next(list.linkedLists._real or list.linkedLists) then
									for _, linkedSpellListId in pairs(list.linkedLists) do
										if not TableUtils:IndexOf(appliedLinkedLists, linkedSpellListId) then
											table.insert(appliedLinkedLists, linkedSpellListId)

											local linkedList = MutationConfigurationProxy.lists.spellLists[linkedSpellListId]
											if linkedList then
												Logger:BasicDebug("### STARTING List %s, linked from %s ###", linkedList.name, list.name)
												applySpellList(linkedSpellListId, list.name)
												Logger:BasicDebug("### FINISHED List %s, linked from %s ###", linkedList.name, list.name)

												recursivelyApplyLinkedLists(linkedList)
											else
												Logger:BasicWarning("Can't find a SpellList with a UUID of %s, linked to %s - skipping", linkedSpellListId, list.name)
											end
										end
									end
								end
							end
							recursivelyApplyLinkedLists(mainSpellList)
						end
					end
				end
			end

			for i = #origValues.addedSpells, 1, -1 do
				local appliedSpell = origValues.addedSpells[i]

				if replaceMap.spellLists[appliedSpell] then
					for _, toReplace in ipairs(entity.SpellBook.Spells) do
						if TableUtils:IndexOf(replaceMap.spellLists[appliedSpell], function(value)
								return value == toReplace.Id.OriginatorPrototype
							end)
						then
							if TableUtils:IndexOf(origValues.addedSpells, toReplace.Id.OriginatorPrototype) then
								origValues.addedSpells[TableUtils:IndexOf(origValues.addedSpells, toReplace.Id.OriginatorPrototype)] = nil
								TableUtils:ReindexNumericTable(origValues.addedSpells)
							end
							spellSystem.RemoveSpell[entity] = spellSystem.RemoveSpell[entity] or {}
							spellSystem.RemoveSpell[entity][#spellSystem.RemoveSpell[entity] + 1] = toReplace.Id
							Logger:BasicDebug("Removed %s from the spell book as it was set to be replaced by %s", toReplace.Id.OriginatorPrototype, appliedSpell)
						end
					end

					if spellSystem.AddSpells[entity] then
						for s, spellMeta in pairs(spellSystem.AddSpells[entity]) do
							if TableUtils:IndexOf(replaceMap.spellLists[appliedSpell], spellMeta.SpellId.OriginatorPrototype) then
								if TableUtils:IndexOf(origValues.addedSpells, spellMeta.SpellId.OriginatorPrototype) then
									origValues.addedSpells[TableUtils:IndexOf(origValues.addedSpells, spellMeta.SpellId.OriginatorPrototype)] = nil
									TableUtils:ReindexNumericTable(origValues.addedSpells)
								end

								spellSystem.AddSpells[entity][s] = nil
								Logger:BasicDebug("Cancelled adding %s to the spell book as it was set to be replaced by %s", spellMeta.SpellId.OriginatorPrototype, appliedSpell)
							end
						end
					end
				end
			end

			entityVar.appliedMutators[self.name].appliedLists = appliedSpellListsForEntityVar
		else
			entityVar.appliedMutators[self.name] = nil
			entityVar.originalValues[self.name] = nil
			entityVar.appliedMutatorsPath[self.name] = nil
		end
	end
end

---@return MazzleDocsDocumentation
function SpellListMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Spell Lists",
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "",
					prefix_color = "Yellow",
					text = [[
Dependency On: Level
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
					text =
					[[This mutator allows you to use your Spell Lists to distribute spells to entities based on their Character or Game Level to accomplish both single- and multi-class setups, or just add loose spells to them in general]]
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
The mutator is laid out as follows:

You can create multiple Spell List Groups, which are groups of Leveled Pools - If you specify multiple Spell List Groups that an entity is eligible for (see criteria below), one will be randomly chosen. When one Spell List mutator is composed with others, every Group from all involved mutators will be placed into one list, as if they had come from a single mutator.

In each pool you'll define an Anchor level, which is the minimum level an entity must be to be eligible for that pool - that pool will apply to that entity up to level 30 or until the next anchor level in the group, whichever comes first.
For example, you can configure two level pools so any entity that is level 1-4 will be eligible for the first pool, and any that are level 5 or above are eligible for the second pool.

This approach allows you to simulate (optional) multiclassing - in the same example as above, you could define both Death and Life Cleric spell lists to the first level pool - this does NOT mean the entity will receive both - rather, they will randomly recieve one of them.

The same assignment will happen at level 5 if the same lists are added to the second pool, but with a bit of a twist - if the entity receives the same list they received at Level 1, they will continue with that spell list as normal; however, if they receive a different list, they'll start from that list at level 1.

For example, if the entity was assigned Death Cleric at level 1, they'd receive the spells from that list for levels 1-4.

If they're assigned Death Cleric again, they'll receive level 5 spells, and continue in that order.

If they're assigned Life Cleric for levels 5+, they'll only receive Life Clerics's level 1 spells at level 5, level 2 spells at level 6, and so on.

This means you could also set up a pool that dips into a multiclass and comes back out to continue the main progression by setting a third spell pool at level 7 for Death/Life cleric again - at that point, they'll continue with the last level they were at for that list, which in this case was level 5.

You can also assign loose Spells defined outside of a spell list; these spells do not have randomized pools, and instead can only be one of Guaranteed, Cast On Combat Start, and Cast on Level Load. They're intended for two main use-cases:
- You don't want to assign entire lists to an NPC, maybe a boss, but want to supplement them with specific ones
- You want to assign an NPC a list, but want to ensure they have specific spells for their kit regardless of their list, i.e. giving an Underdark smuggler the Light spell

Any number of spells can be added here, but keep in mind that the game's AI can't handle large amounts of spells well - they tend to crash when reaching the 7-8+ range, depending on the AI archetype. Spells that are set as Cast on Combat Start/Level Load aren't added to the spellbook though, so you can safely add as many as you'd like

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
					text =
					[[For Spells that are cast on level load and combat start, Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid) is used; for combat start when the entity isn't already in combat when the profile executes, this call is wrapped in a CombatStarted Osi Event Listener, otherwise it's done immediately (expected use-case is for entities that spawn mid-combat, like summons/familiars).

For Spells that are cast on death, the Died Osi Event listener is used to execute Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid) - this _may_ cause some animation issues, will look into a better alternative soon.

When determining what spells end up in the Random pool to be added to the SpellBook, checks are done to ensure:
1. The spell isn't already known by the entity
2. The spell isn't already slated to be added by another progression

Once the final list of spells is determined, the Replace logic is run, removing any spells from the final list and the entity's spellbook if they're marked to be replaced by another spell.

When adding spells to an entity, the AddSpells operation under the SpellSystem is used to add them to the spellbook - this system allows more granular control over the spell's properties, which are assigned as below:
{
	PrepareType = "AlwaysPrepared",
	SpellId = {
		OriginatorPrototype = spellName,
		SourceType = "SpellSet2"
	},
	PreferredCastingResource = "d136c5d9-0ff0-43da-acce-a74a07f8d6bf",
	SpellCastingAbility = entity.Stats.SpellCastingAbility
}
The Preferred Casting Resource is set to just SpellSlots - this will currently prove problematic if you assign Warlock SpellSlots to entities, but I'll solve for this in the near future.]]
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
						"Should be a multiclass of Death Cleric and Shadow Sorceror, prioritizing Death Cleric for levels 1-5 before allocating equal levels in both",
						"Should receive a guaranteed set of spells depending on which Game Level they're in",
					}
				} --[[@as MazzleDoctsBullet]],
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function SpellListMutator:generateChangelog()
	return {
		["1.7.2"] = {
			type = "Bullet",
			text = {
				"Actually force the Spell's cooldown type to be specified when adding to the spellbook q_q"
			}
		},
		["1.7.1"] = {
			type = "Bullet",
			text = {
				"Added safety check + log in case a linked list isn't found",
				"Reindex Leveled Pools when applying the mutator, ensuring they're processed in order according to their anchor level",
				"Force the Spell's cooldown type to be specified when adding to the spellbook"
			}
		},
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Fix lists not applying entries from linked progressions"
			}
		},
		["1.6.0"] = {
			type = "Bullet",
			text = {
				"Excludes SpellList groups from the apply logic that don't have a leveledSpellPool"
			}
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
