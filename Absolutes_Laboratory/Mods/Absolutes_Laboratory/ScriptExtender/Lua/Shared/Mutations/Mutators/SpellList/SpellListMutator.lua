Ext.Require("Shared/Mutations/Mutators/SpellList/SpellListDesigner.lua")

---@class SpellListMutatorClass : MutatorInterface
SpellListMutator = MutatorInterface:new("SpellList")

---@class SpellListAbilityScoreCondition
---@field comparator "gte"|"lte"
---@field abilityId AbilityId
---@field value number

---@class SpellListCriteriaEntry
---@field isOneOfClasses Guid[]?
---@field abilityCondition SpellListAbilityScoreCondition[]?

---@class LeveledSpellPool
---@field anchorLevel number
---@field spellLists Guid[]
---@field spells SpellSubLists?

---@class SpellMutatorGroup
---@field leveledSpellPool LeveledSpellPool[]?
---@field criteria SpellListCriteriaEntry?

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

		local poolCell = parentRow:AddCell()

		local header = poolCell:AddCollapsingHeader("Pool " .. sMG)

		local delete = Styler:ImageButton(header:AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", { 16, 16 }))
		delete:Tooltip():AddText("\t Delete Pool")
		delete.OnClick = function()
			for x = sMG, TableUtils:CountElements(mutator.values) do
				mutator.values[x].delete = true
				mutator.values[x] = TableUtils:DeeplyCopyTable(mutator.values._real[x + 1])
			end
			self:renderMutator(parent, mutator)
		end
		local poolGroup = header:AddGroup("Pool")
		local function renderPool()
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

					cell:AddSeparatorText("Spell Lists"):SetStyle("SeparatorTextAlign", 0.1)

					for _, spellList in TableUtils:OrderedPairs(leveledSpellPool.spellLists, function(_, value)
						return configuredSpellLists[value].name
					end) do
						spellList = configuredSpellLists[spellList]
						local text = cell:AddText(spellList.name)
						if spellList.description ~= "" then
							text:Tooltip():AddText(spellList.description)
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
								renderPool()
							end
						end
					end

					self:buildSpellSelectorSection(cell, spellMutatorGroup, i)
				end
			end
		end
		renderPool()

		local addLeveledGroupButton = header:AddButton("Add Level Group")
		addLeveledGroupButton.Font = "Small"
		addLeveledGroupButton.OnClick = function()
			Helpers:KillChildren(poolGroup)
			spellMutatorGroup.leveledSpellPool = spellMutatorGroup.leveledSpellPool or {}
			table.insert(spellMutatorGroup.leveledSpellPool, {
				anchorLevel = 1,
				spellLists = {}
			} --[[@as LeveledSpellPool]])

			renderPool()
		end

		local criteriaCell = parentRow:AddCell()

		parentRow:AddNewLine()
	end

	local addGroupButton = parent:AddButton("Add New Pool")
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

		local input = popup:AddInputText("")
		input.Hint = "Minimum Three Characters"

		local helpText = popup:AddText("( ? )")
		helpText.SameLine = true
		helpText:Tooltip():AddText([[
	See detailed tooltips on spell images by holding shift -
click outside of the text input first, as the modifier won't be registered while the input is accepting keystrokes.
You can shift-click on images to pop out their tooltip into a new window, but that will close the search popup]])

		local resultsGroup = popup:AddChildWindow("results")
		resultsGroup.NoSavedSettings = true
		resultsGroup.Size = { 0, 300 * Styler:ScaleFactor() }
		local timer
		input.OnChange = function()
			if timer then
				Ext.Timer.Cancel(timer)
			end

			Helpers:KillChildren(resultsGroup)
			if #input.Text >= 3 then
				timer = Ext.Timer.WaitFor(300, function()
					local value = input.Text:upper()
					local results = {}
					for _, spellName in pairs(Ext.Stats.GetStats("SpellData")) do
						---@type SpellData
						local spell = Ext.Stats.Get(spellName)
						if spell.RootSpellID == "" then
							if spellName:upper():find(value) then
								table.insert(results, spellName)
							else
								if spell.DisplayName and Ext.Loca.GetTranslatedString(spell.DisplayName, spell.Name):find(value) then
									table.insert(results, spellName)
								end
							end
						end
					end
					if #results > 0 then
						table.sort(results, function(a, b)
							return Ext.Loca.GetTranslatedString(Ext.Stats.Get(a).DisplayName, a) < Ext.Loca.GetTranslatedString(Ext.Stats.Get(b).DisplayName, b)
						end)

						for i, spellName in ipairs(results) do
							---@type SpellData
							local spell = Ext.Stats.Get(spellName)

							local spellImage = resultsGroup:AddImageButton(spellName .. i, spell.Icon, { 48, 48 })

							spellImage.AutoClosePopups = false
							if spellImage.Image.Icon == "" then
								spellImage:Destroy()
								spellImage = resultsGroup:AddImageButton(spellName .. i, "Item_Unknown", { 48, 48 })
							end
							spellImage.SameLine = i > 1 and (i - 1) % 7 ~= 0

							if TableUtils:IndexOf(mutatorGroup.leveledSpellPool, function(value)
									if value.spells then
										for _, spellList in pairs(value.spells) do
											if TableUtils:IndexOf(spellList, spellName) then
												return true
											end
										end
									end
								end)
							then
								spellImage.Tint = { 1, 1, 1, 0.2 }
							end

							local hyperlinkFunc = Styler:HyperlinkRenderable(spellImage,
								spellName,
								"Shift",
								string.format("%s\n%s", spellName, Ext.Loca.GetTranslatedString(spell.DisplayName, spellName)),
								function(parent)
									ResourceManager:RenderDisplayWindow(spell, parent)
								end)

							spellImage.OnClick = function()
								if not hyperlinkFunc() then
									if not TableUtils:IndexOf(mutatorGroup.leveledSpellPool[poolIndex].spells, function(value)
											if TableUtils:IndexOf(value, spellName) then
												return true
											end
										end)
									then
										local pool = mutatorGroup.leveledSpellPool[poolIndex]
										pool.spells = pool.spells or {
											guaranteed = {}
										} --[[@as SpellSubLists]]

										pool.spells.guaranteed = pool.spells.guaranteed or {}

										table.insert(pool.spells.guaranteed, spellName)
										renderSpellGroup()
									end
								end
							end
						end
					end
				end)
			end
		end
	end
end

function SpellListMutator:applyMutator(entity, mutator)

end

function SpellListMutator:undoMutator(entity, mutator)

end
