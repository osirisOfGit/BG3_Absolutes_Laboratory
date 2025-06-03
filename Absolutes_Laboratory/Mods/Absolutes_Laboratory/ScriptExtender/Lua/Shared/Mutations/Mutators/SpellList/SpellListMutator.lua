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

function SpellListMutator:canBeAdditive(mutator) 
	return true
end

local SPELL_MUTATOR_ON_COMBAT_START = ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME .. "SpellsOnCombatStart"
Ext.Vars.RegisterUserVariable(ABSOLUTES_LABORATORY_MUTATIONS_VAR_NAME .. "SpellsOnCombatStart", {
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


	---@class SpellListOriginalValues
	---@field removedSpells SpellSpellMeta[]
	---@field addedSpells SpellName[]
	---@field castedSpells SpellName[]

	function SpellListMutator:undoMutator(entity, mutator)
		entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] = nil

		---@type EsvSpellSpellSystem
		local spellSystem = Ext.System.ServerSpell

		---@type SpellListOriginalValues?
		local origValues = mutator.originalValues[self.name]
		if origValues then
			if origValues.addedSpells then
				spellSystem.RemoveSpell = spellSystem.RemoveSpell or {}
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
				spellSystem.AddSpells = spellSystem.AddSpells or {}
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

			if origValues.castedSpells then
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

	---@param subLists SpellSubLists
	---@param entity EntityHandle
	---@param addSpells {[EntityHandle]: SpellSpellMeta[]}
	function SpellListMutator:processSubLists(subLists, entity, addSpells, castedSpells)
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
						Logger:BasicDebug("Added spell %s", spellName)
					end
				elseif subListName == "startOfCombatOnly" then
					if Osi.IsInCombat(entity.Uuid.EntityUuid) == 1 then
						Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid)
						table.insert(castedSpells, spellName)
						Logger:BasicDebug("Used on combat spell %s", spellName)
					else
						entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] = entity.Vars[SPELL_MUTATOR_ON_COMBAT_START] or {}

						table.insert(entity.Vars[SPELL_MUTATOR_ON_COMBAT_START], spellName)
					end
				elseif subListName == "onLoadOnly" then
					if Osi.IsDead(entity.Uuid.EntityUuid) == 0 then
						Osi.UseSpell(entity.Uuid.EntityUuid, spellName, entity.Uuid.EntityUuid)
						table.insert(castedSpells, spellName)
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

	function SpellListMutator:applyMutator(entity, mutator)
		---@type EsvSpellSpellSystem
		local spellSystem = Ext.System.ServerSpell

		SpellListDesigner:buildProgressionIndex()

		local spellListMutators = mutator.appliedMutators[self.name]
		if not spellListMutators[1] then
			spellListMutators = { spellListMutators }
		end

		---@cast spellListMutators SpellListMutator[]

		spellSystem.AddSpells[entity] = spellSystem.AddSpells[entity] or {}
		local addSpells = spellSystem.AddSpells[entity]

		---@type SpellMutatorGroup[]
		local groupsToApply = {}

		for m, mutator in ipairs(spellListMutators) do
			--#region Criteria
			local keep = false
			for g, spellMutatorGroup in ipairs(mutator.values) do
				if spellMutatorGroup.criteria then
					---@type SpellListCriteriaEntry
					local criteria = spellMutatorGroup.criteria

					if criteria.abilityCondition then
						for ability, condition in pairs(criteria.abilityCondition) do
							local score = entity.BaseStats.BaseAbilities[Ext.Enums.AbilityId[ability].Value + 1]
							if (condition.comparator == "gte" and score < condition.value)
								or (condition.comparator == "lte" and score > condition.value)
							then
								Logger:BasicDebug("Skipped Group %s on %s due to %s being %s than %s (was %s)",
									g,
									entity.Uuid.EntityUuid,
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
						Logger:BasicDebug("Skipped Group %s on %s due to not being one of the right classes", g, entity.Uuid.EntityUuid)
						spellListMutators[g] = nil
						goto next_group

						::success::
					end
				end
				keep = true
				table.insert(groupsToApply, spellMutatorGroup)

				::next_group::
			end
			if not keep then
				spellListMutators[m] = nil
			end
		end
		--#endregion

		local spellMutatorGroup
		if #groupsToApply == 1 then
			spellMutatorGroup = groupsToApply[1]
		elseif #groupsToApply > 1 then
			spellMutatorGroup = groupsToApply[math.random(#groupsToApply)]
		end

		if spellMutatorGroup then
			mutator.originalValues[self.name] = mutator.originalValues[self.name] or {
				addedSpells = {},
				castedSpells = {},
				removedSpells = {}
			} --[[@as SpellListOriginalValues]]

			---@type SpellListOriginalValues
			local origValues = mutator.originalValues[self.name]

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

			---@type Guid[]
			local appliedLists = {}

			for lSP, leveledSpellPool in ipairs(spellMutatorGroup.leveledSpellPool) do
				if entity.AvailableLevel and entity.AvailableLevel.Level >= leveledSpellPool.anchorLevel then
					-- Osi.CreateAt("01fa8d64-f63e-4bb8-9ee4-cba84dad3781", 202, 25, 418, 0, 0, "")
					-- Osi.SetRelationTemporaryHostile("5ebcd998-e4ae-1a42-202c-3619bced3eea", _C().Uuid.EntityUuid)
					if leveledSpellPool.spells then
						self:processSubLists(leveledSpellPool.spells, entity, addSpells, origValues.castedSpells)
					end

					if leveledSpellPool.spellLists then
						TableUtils:ReindexNumericTable(leveledSpellPool.spellLists)

						local spellListId
						if #leveledSpellPool.spellLists > 1 then
							spellListId = leveledSpellPool.spellLists[math.random(#leveledSpellPool.spellLists)]
						else
							spellListId = leveledSpellPool.spellLists[1]
						end

						if spellListId and ConfigurationStructure.config.mutations.spellLists[spellListId] then
							local nextAnchor = math.min((spellMutatorGroup.leveledSpellPool[lSP + 1] and spellMutatorGroup.leveledSpellPool[lSP + 1].anchorLevel - 1) or 30,
								entity.AvailableLevel.Level)

							local maxAppliedLevel = 0
							for level in pairs(appliedLists) do
								if level > maxAppliedLevel then
									maxAppliedLevel = level
								end
							end
							local startingSpellListLevel = (TableUtils:IndexOf(appliedLists, spellListId) or 1)

							if TableUtils:IndexOf(appliedLists, spellListId) then
								startingSpellListLevel = startingSpellListLevel + 1
								appliedLists[startingSpellListLevel] = nil
								maxAppliedLevel = 0
							end
							appliedLists[nextAnchor] = spellListId

							local cLevel = nextAnchor == maxAppliedLevel + 1 and nextAnchor or nextAnchor - maxAppliedLevel

							local spellList = ConfigurationStructure.config.mutations.spellLists[spellListId]
							Logger:BasicDebug("Selected spellList %s (%s) for anchor level %s, using levels %s-%s",
								spellList.name,
								spellListId,
								leveledSpellPool.anchorLevel,
								startingSpellListLevel,
								cLevel)

							for i = startingSpellListLevel, cLevel do
								local leveledLists = spellList.levels[i]
								---@type SpellName[]
								local randomPool = {}
								if leveledLists then
									if leveledLists.linkedProgressions then
										for progressionId, subLists in pairs(leveledLists.linkedProgressions) do
											self:processSubLists(subLists, entity, addSpells, origValues.castedSpells)

											if SpellListDesigner.progressionTranslation[progressionId] then
												local progressionTable = SpellListDesigner.progressions[SpellListDesigner.progressionTranslation[progressionId]]
												if progressionTable and progressionTable[i] then
													for _, spellName in pairs(progressionTable[i]) do
														if not TableUtils:IndexOf(subLists.blackListed, spellName) then
															table.insert(randomPool, spellName)
														end
													end
												end
											end
										end
									end

									if leveledLists.selectedSpells then
										self:processSubLists(leveledLists.selectedSpells, entity, addSpells, origValues.castedSpells)

										if leveledLists.selectedSpells.randomized then
											for _, spellName in pairs(leveledLists.selectedSpells.randomized) do
												if not TableUtils:IndexOf(entity.SpellBook.Spells, function(value)
														return value.Id.OriginatorPrototype == spellName
													end)
												then
													table.insert(randomPool, spellName)
												else
													Logger:BasicDebug("%s is already known, not adding to the random pool", spellName)
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
									Logger:BasicDebug("Giving %s random spells out of %s from level %s", numRandomSpellsToPick, #randomPool, i)
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
										addSpells[#addSpells + 1] = {
											PrepareType = "AlwaysPrepared",
											SpellId = {
												OriginatorPrototype = spellName,
												SourceType = "SpellSet2"
											},
											PreferredCastingResource = "d136c5d9-0ff0-43da-acce-a74a07f8d6bf",
											SpellCastingAbility = entity.Stats.SpellCastingAbility
										}

										table.insert(origValues.addedSpells, spellName)
										Logger:BasicDebug("Added spell %s", spellName)
									end
								else
									Logger:BasicDebug("Skipping level %s for random spell assignment due to configured size being 0", maxAppliedLevel + i)
								end
							end
						end
					end
				end
			end
		else
			mutator.appliedMutators[self.name] = nil
			mutator.originalValues[self.name] = nil
			mutator.appliedMutatorsPath[self.name] = nil
		end
	end
end
