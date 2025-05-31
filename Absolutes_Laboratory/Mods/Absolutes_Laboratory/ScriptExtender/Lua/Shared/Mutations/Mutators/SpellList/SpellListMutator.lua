Ext.Require("Shared/Mutations/Mutators/SpellList/SpellListDesigner.lua")

---@class SpellListMutatorClass : MutatorInterface
SpellListMutator = MutatorInterface:new("SpellList")

---@class SpellListAbilityScoreCondition
---@field comparator "gte"|"lte"
---@field value number

---@class SpellListCriteriaEntry
---@field isOneOfClasses Guid[]?
---@field abilityCondition {[AbilityId] : SpellListAbilityScoreCondition}?

---@class LeveledSpellPool
---@field anchorLevel number
---@field spellLists Guid[]
---@field spells SpellSubLists?

---@class SpellMutatorGroup
---@field leveledSpellPool LeveledSpellPool[]?
---@field criteria SpellListCriteriaEntry?
---@field removeSpells {[number]: SpellSourceType|SpellName}
---@field randomizedSpellPoolSize number[]

---@class SpellListMutator : Mutator
---@field values SpellMutatorGroup[]

---@param mutator SpellListMutator
function SpellListMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}
	Helpers:KillChildren(parent)
	local configuredSpellLists = ConfigurationStructure.config.mutations.spellLists

	parent:AddButton("Open SpellList Designer").OnClick = function()
		SpellListDesigner:buildSpellDesignerWindow()
	end

	local displayTable = parent:AddTable("SpellList", 2)
	displayTable.Resizable = true
	displayTable.NoSavedSettings = true
	displayTable.Borders = true

	local popup = parent:AddPopup("spellListMutatorPopup")

	for sMG, spellMutatorGroup in TableUtils:OrderedPairs(mutator.values) do
		local parentRow = displayTable:AddRow()

		local groupCell = parentRow:AddCell()

		local header = groupCell:AddCollapsingHeader("Group " .. sMG)
		header.DefaultOpen = true

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
			local leveledTable = poolGroup:AddTable("leveledTable", 1)
			leveledTable.NoSavedSettings = true
			leveledTable.Borders = true
			if spellMutatorGroup.leveledSpellPool then
				for i, leveledSpellPool in TableUtils:OrderedPairs(spellMutatorGroup.leveledSpellPool, function(_, value)
					return value.anchorLevel
				end) do
					local cell = leveledTable:AddRow():AddCell()

					local delete = Styler:ImageButton(cell:AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", { 16, 16 }))
					delete.OnClick = function()
						for x = i, TableUtils:CountElements(spellMutatorGroup.leveledSpellPool) do
							spellMutatorGroup.leveledSpellPool[x].delete = true
							spellMutatorGroup.leveledSpellPool[x] = TableUtils:DeeplyCopyTable(spellMutatorGroup.leveledSpellPool._real[x + 1])
						end

						self:renderMutator(parent, mutator)
					end

					cell:AddText("Level is equal to or greater than: ").SameLine = true

					local levelInput = cell:AddSliderInt("", leveledSpellPool.anchorLevel, 1, 30)
					levelInput.OnChange = function()
						---@param anchor number
						---@return number[]
						local function nextAnchor(anchor)
							local index = TableUtils:IndexOf(spellMutatorGroup.leveledSpellPool, function(value)
								return value.anchorLevel == anchor
							end)
							if index and index ~= i and anchor < 30 then
								return nextAnchor(anchor + 1)
							else
								return { anchor, anchor, anchor, anchor }
							end
						end
						levelInput.Value = nextAnchor(levelInput.Value[1])
						leveledSpellPool.anchorLevel = levelInput.Value[1]
					end

					local spellListSep = cell:AddSeparatorText("Spell Lists ( ? )")
					spellListSep:SetStyle("SeparatorTextAlign", 0.1)
					spellListSep:Tooltip():AddText("\t Specifying multiple spell lists means one will be randomly chosen to be assigned to an entity - it will not add all of them")

					for sL, spellList in TableUtils:OrderedPairs(leveledSpellPool.spellLists, function(_, value)
						return configuredSpellLists[value] and configuredSpellLists[value].name
					end) do
						spellList = configuredSpellLists[spellList]
						if spellList then
							local text = cell:AddText(spellList.name)
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

						for id, spellList in TableUtils:OrderedPairs(configuredSpellLists, function(key)
							return configuredSpellLists[key].name
						end) do
							---@type ExtuiSelectable
							local select = popup:AddSelectable(spellList.name, "DontClosePopups")
							select.Selected = TableUtils:IndexOf(leveledSpellPool.spellLists, id) ~= nil
							select.OnClick = function()
								local index = TableUtils:IndexOf(leveledSpellPool.spellLists, id)
								if index then
									leveledSpellPool.spellLists[index] = nil
									select.Selected = false
								else
									select.Selected = true
									table.insert(leveledSpellPool.spellLists, id)
								end
								Helpers:KillChildren(poolGroup)
								renderPools()
							end
						end
					end

					self:buildSpellSelectorSection(cell, spellMutatorGroup, i)
				end
			end
		end
		renderPools()

		local addLeveledPoolButton = header:AddButton("Add Level Pool")
		addLeveledPoolButton.Font = "Small"
		addLeveledPoolButton.OnClick = function()
			Helpers:KillChildren(poolGroup)
			spellMutatorGroup.leveledSpellPool = spellMutatorGroup.leveledSpellPool or {}
			table.insert(spellMutatorGroup.leveledSpellPool, {
				anchorLevel = 1,
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
		for subListName, colour in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.settings.spellLists.subListColours, function(key)
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
			---@type SpellSubLists
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

		SpellBrowser:Render(popup,
			nil,
			function(pos)
				return pos % 8 ~= 0
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
					} --[[@as SpellSubLists]]

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

	local popup = parent:AddPopup("Randomized")

	--#region Randomized Spell Pool Size
	local randoAmountHeader = parent:AddCollapsingHeader("Amount of Random Spells to Give Per Level")

	spellMutatorGroup.randomizedSpellPoolSize = spellMutatorGroup.randomizedSpellPoolSize or {}
	local randomizedSpellPoolSize = spellMutatorGroup.randomizedSpellPoolSize
	if not randomizedSpellPoolSize() then
		randomizedSpellPoolSize[1] = 2
		randomizedSpellPoolSize[3] = 0
		randomizedSpellPoolSize[5] = 1
		randomizedSpellPoolSize[7] = 0
		randomizedSpellPoolSize[10] = 1
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
				self:renderCriteriaAndExtras(parent, spellMutatorGroup)
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

		local combo           = row:AddCell():AddCombo("")
		combo.WidthFitPreview = true
		combo.Options         = { ">=", "<=" }
		combo.SelectedIndex   = existingCriteria and existingCriteria.comparator == "lte" and 1 or 0

		local input           = row:AddCell():AddInputInt("", existingCriteria and existingCriteria.value)

		combo.OnChange        = function()
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

		input.OnChange        = function()
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

	removeSpellsHeader:AddButton("+").OnClick = function()
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

		SpellBrowser:Render(popup,
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

function SpellListMutator:applyMutator(entity, mutator)
	---@type SpellListMutator|SpellListMutator[]
	local spellListMutators = mutator.appliedMutators[self.name]
	if not spellListMutators[1] then
		spellListMutators = { spellListMutators }
	end

	for _, mutator in ipairs(spellListMutators) do
		for _, spellMutatorGroup in ipairs(mutator.values) do
			for _, leveledSpellPool in ipairs(spellMutatorGroup.leveledSpellPool) do
				if entity.AvailableLevel and entity.AvailableLevel.Level >= leveledSpellPool.anchorLevel then
					---@type EsvSpellSpellSystem
					local spellSystem = Ext.System.ServerSpell

					local addSpells = spellSystem.AddSpells[entity]
					if not addSpells then
						spellSystem.AddSpells[entity] = {}
						addSpells = spellSystem.AddSpells[entity]
					end

					---@type Character
					local charStat = Ext.Stats.Get(entity.Data.StatsId)

					local skillList = entity.ServerCharacter.TemplateUsedForSpells.SkillList
					-- Osi.CreateAt("01fa8d64-f63e-4bb8-9ee4-cba84dad3781", 202, 25, 418, 0, 0, "")
					-- Osi.SetRelationTemporaryHostile("5ebcd998-e4ae-1a42-202c-3619bced3eea", _C().Uuid.EntityUuid)
					for _, spellName in pairs(leveledSpellPool.spells.guaranteed) do
						if not TableUtils:IndexOf(entity.SpellBook.Spells, function(value)
								return value.Id.OriginatorPrototype == spellName
							end)
						then
							addSpells[#addSpells + 1] = {
								PrepareType = "AlwaysPrepared",
								SpellId = {
									OriginatorPrototype = spellName,
									SourceType = "SpellSet2"
								},
								PreferredCastingResource = "d136c5d9-0ff0-43da-acce-a74a07f8d6bf",
								SpellCastingAbility = charStat.SpellCastingAbility
							}
						end
					end
				end
			end
		end
	end
end

function SpellListMutator:undoMutator(entity, mutator)

end
