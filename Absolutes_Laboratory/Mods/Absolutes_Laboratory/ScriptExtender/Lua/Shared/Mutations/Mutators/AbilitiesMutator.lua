---@class AbilitiesMutatorClass : MutatorInterface
AbilitiesMutator = MutatorInterface:new("Abilities")
AbilitiesMutator.affectedComponents = {
	"BoostsContainer"
}

function AbilitiesMutator:priority()
	return self:recordPriority(SpellListMutator:priority() + 1)
end

function AbilitiesMutator:canBeAdditive()
	return false
end

function AbilitiesMutator:handleDependencies()
	-- NOOP
end

function AbilitiesMutator:Transient()
	return true
end

---@class DieSettings
---@field numberOfDice number
---@field diceSides number
---@field numberOfLowestToRemove number

---@class AbilityMutatorValue
---@field dieSettings DieSettings
---@field overriddenAbilityPriorities AbilityPriorities

---@class AbilitiesMutatorModifiers
---@field minimumScoreValue number?
---@field maximumScoreValue number?

---@class AbilitiesStaticMutator
---@field scores {[AbilityId] : number[]}

---@class AbilitiesMutator : Mutator
---@field values (AbilityMutatorValue|AbilitiesStaticMutator)
---@field staticMutator boolean
---@field modifiers AbilitiesMutatorModifiers?

---@type ExtuiPopup
AbilitiesMutator.popup = nil

---@param mutator AbilitiesMutator
function AbilitiesMutator:renderMutator(parent, mutator)
	Helpers:KillChildren(parent)
	self.popup = Styler:Popup(parent)

	mutator.values = mutator.values or {}
	mutator.staticMutator = mutator.staticMutator ~= nil and mutator.staticMutator or false

	Styler:DualToggleButton(parent, "Static Assignment", "Roll Dice", false, function(swap)
		if swap then
			mutator.staticMutator = not mutator.staticMutator
			mutator.values.delete = true
			mutator.values = {}

			self:renderMutator(parent, mutator)
		end

		return mutator.staticMutator
	end)

	if mutator.staticMutator then
		mutator.values.scores = mutator.values.scores or {}
		self:renderStaticLayout(parent:AddGroup(""), mutator)
	else
		mutator.values.dieSettings = mutator.values.dieSettings or {
			diceSides = 6,
			numberOfDice = 4,
			numberOfLowestToRemove = 1
		} --[[@as DieSettings]]

		self:renderDieRollLayout(parent:AddGroup(""), mutator)
	end
end

---@param parent ExtuiTreeParent
---@param mutator AbilitiesMutator
function AbilitiesMutator:renderStaticLayout(parent, mutator)
	Helpers:KillChildren(parent)
	local abilityTable = parent:AddTable("Abilities", 6)
	abilityTable.NoSavedSettings = true
	local row = abilityTable:AddRow()

	for _, abilityId in TableUtils:OrderedPairs(Ext.Enums.AbilityId, function(key, value)
		return value
	end, function(key, value)
		return type(key) == "number" and key > 0 and value ~= "Sentinel"
	end) do
		---@cast abilityId string
		abilityId = tostring(abilityId)
		local abilityCell = row:AddCell()
		Styler:CheapTextAlign(abilityId, abilityCell, "Large")

		local inputTable = abilityCell:AddTable(abilityId, 3)
		inputTable:AddColumn("", "WidthFixed")
		inputTable.NoSavedSettings = true

		local headerRow = inputTable:AddRow()
		headerRow:Tooltip():AddText(
			[[For any level other than 1, Lab will add (compounding on previous levels) the specified amount to the specified Ability score - e.g., if you set Level 3 to add 2 points to Strength, and level 5 to add 1 point, a level 5 entity will receive +3 to Strength. Setting a negative value will instead subtract that amount.
If you specify level 1, that will override the entity's current Ability Score, and will serve as the base for subsequent additions - e.g. setting Strength to 3 at level 1 will result in the entity having 3 strength, if no other levels are specified.
If level 1 is set to 0 with no other levels specified, then that ability score won't be modified]])

		headerRow.Headers = true
		headerRow:AddCell()
		headerRow:AddCell():AddText("Entity Level")
		headerRow:AddCell():AddText("# To Add (?)")

		if not mutator.values.scores[abilityId] or not next(mutator.values.scores[abilityId]) then
			mutator.values.scores[abilityId] = TableUtils:DeeplyCopyTable(ConfigurationStructure.config.mutations.settings.abilitiesDistributionPresets.Default)
		end

		local scores = mutator.values.scores[abilityId]
		for level, amount in TableUtils:OrderedPairs(scores) do
			local levelRow = inputTable:AddRow()

			local deleteButton = Styler:ImageButton(levelRow:AddCell():AddImageButton("delete" .. level, "ico_red_x", { 16, 16 }))
			deleteButton.OnClick = function()
				scores[level] = nil
				self:renderStaticLayout(parent, mutator)
			end

			local levelInput = levelRow:AddCell():AddInputInt("##level", level)
			levelInput.OnChange = function()
				local val = levelInput.Value[1]
				if val < 1 or (val ~= level and scores[val]) then
					Styler:Color(levelInput, "ErrorText")
				else
					Styler:Color(levelInput, "DefaultText")
				end
			end

			local amountInput = levelRow:AddCell():AddInputInt("##amount", amount)

			amountInput.OnDeactivate = function()
				scores[level] = amountInput.Value[1]
			end

			levelInput.OnDeactivate = function()
				local val = levelInput.Value[1]
				if val < 1 or (val ~= level and scores[val]) then
					levelInput.Value = { level, level, level, level }
					Styler:Color(levelInput, "DefaultText")
				elseif val ~= level then
					scores[val] = amountInput.Value[1]
					scores[level] = nil
					self:renderStaticLayout(parent, mutator)
				end
			end
		end

		Styler:MiddleAlignedColumnLayout(abilityCell, function(ele)
			ele:AddButton("+").OnClick = function()
				mutator.values.scores[abilityId] = mutator.values.scores[abilityId] or {}

				local biggestNumber = 1
				for level in TableUtils:OrderedPairs(mutator.values.scores[abilityId]) do
					biggestNumber = level > biggestNumber and level or biggestNumber
				end

				mutator.values.scores[abilityId][biggestNumber + 1] = 0

				self:renderStaticLayout(parent, mutator)
			end

			local managePresetsButton = ele:AddButton("MP")
			managePresetsButton.SameLine = true
			managePresetsButton:Tooltip():AddText("\t Manage your presets for this mutator")

			managePresetsButton.OnClick = function()
				Helpers:KillChildren(self.popup)
				self.popup:Open()

				local config = ConfigurationStructure.config.mutations.settings.abilitiesDistributionPresets

				for presetName, scores in TableUtils:OrderedPairs(config) do
					---@type ExtuiMenu
					local menu = self.popup:AddMenu(presetName)

					if presetName ~= "Default" then
						FormBuilder:CreateForm(menu:AddMenu("Edit"), function(formResults)
								config[formResults.Name] = TableUtils:DeeplyCopyTable(scores)
								scores.delete = true
								managePresetsButton:OnClick()
							end,
							{
								{
									label = "Name",
									type = "Text",
									defaultValue = presetName,
									errorMessageIfEmpty = "Required"
								}
							})
					end

					menu:AddSelectable("Load and overwrite current values").OnClick = function()
						mutator.values.scores[abilityId].delete = true
						mutator.values.scores[abilityId] = TableUtils:DeeplyCopyTable(scores)
						self:renderStaticLayout(parent, mutator)
					end

					menu:AddSelectable("Save and overwrite this preset with current values").OnClick = function()
						scores.delete = true
						config[presetName] = TableUtils:DeeplyCopyTable(mutator.values.scores[abilityId])
					end

					if presetName ~= "Default" then
						---@param select ExtuiSelectable
						menu:AddSelectable("Delete This Preset", "DontClosePopups").OnClick = function(select)
							if select.Label ~= "Delete This Preset" then
								config[presetName].delete = true
							else
								select.DontClosePopups = false
								select.Label = "Are You Sure?"
								Styler:Color(select, "ErrorText")
							end
						end
					end
				end

				FormBuilder:CreateForm(self.popup:AddMenu("Create New Preset"), function(formResults)
					config[formResults.Name] = {}
					managePresetsButton:OnClick()
				end, {
					{
						label = "Name",
						type = "Text",
						errorMessageIfEmpty = "Required"
					}
				})
			end
		end)
	end
end

---@param parent ExtuiTreeParent
---@param mutator AbilitiesMutator
function AbilitiesMutator:renderDieRollLayout(parent, mutator)
	local dieSettings = mutator.values.dieSettings

	local layoutTable = parent:AddTable("Layout", 2):AddRow()

	local dieSettingSide = layoutTable:AddCell()
	dieSettingSide:AddSeparatorText("Dice Settings ( ? )"):Tooltip():AddText([[
	The below settings will be used when calculating the new ability scores - for each ability, the specified number of the specified dice type will be "rolled",
dropping the # of lowest values specified, then the scores will be assigned to the entity's abilities in the determined priority order, highest to lowest - the primary and secondary abilities will also receive a +2 and +1, respectively.
Priority order of the abilities is determined in the following sequence:
1. Override values to the right are checked - if the relevant priority (i.e. secondary) is specified, that will be used
2. The entity will be checked for assigned Spell Lists - if they have been assigned lists that have their own specified priority orders, those will be used as available.
	If multiple lists are found that have orders, they will be averaged out based on how many levels of the lists they were assigned
3. The entity's existing stats will be inspected and priority will be inferred by that]])
	local dieTable = dieSettingSide:AddTable("DieTable", 2)
	dieTable.SizingFixedFit = true

	local numDiceRow = dieTable:AddRow()
	numDiceRow:AddCell():AddText("# Of Dice To Roll Per Ability")
	local numDiceInput = numDiceRow:AddCell():AddInputInt("", dieSettings.numberOfDice)
	numDiceInput.ItemWidth = 80
	numDiceInput.OnChange = function()
		if numDiceInput.Value[1] <= 0 then
			local currValue = dieSettings.numberOfDice
			numDiceInput.Value = { currValue, currValue, currValue, currValue }
		else
			dieSettings.numberOfDice = numDiceInput.Value[1]
		end
	end

	local diceSidesRow = dieTable:AddRow()
	diceSidesRow:AddCell():AddText("Die Type To Roll (i.e. d6)")
	local diceSideCell = diceSidesRow:AddCell()
	local diceSideInput = diceSideCell:AddInputInt("", dieSettings.diceSides)
	diceSideInput.ItemWidth = 80
	diceSideInput.OnChange = function()
		if diceSideInput.Value[1] <= 0 then
			local currValue = dieSettings.diceSides
			diceSideInput.Value = { currValue, currValue, currValue, currValue }
		else
			dieSettings.diceSides = diceSideInput.Value[1]
		end
	end

	local numToDropRow = dieTable:AddRow()
	numToDropRow:AddCell():AddText("# of Lowest Rolls To Drop")
	local numToDropInput = numToDropRow:AddCell():AddInputInt("", dieSettings.numberOfLowestToRemove)
	numToDropInput.ItemWidth = 80
	numToDropInput.OnChange = function()
		if numToDropInput.Value[1] <= 0 then
			local currValue = dieSettings.numberOfLowestToRemove
			numToDropInput.Value = { currValue, currValue, currValue, currValue }
		else
			dieSettings.numberOfLowestToRemove = numToDropInput.Value[1]
		end
	end

	local min = dieSettings.numberOfDice - dieSettings.numberOfLowestToRemove
	local max = dieSettings.diceSides * (dieSettings.numberOfDice - dieSettings.numberOfLowestToRemove)

	local averageWithAllDice = (((dieSettings.diceSides + 1) / 2) * dieSettings.numberOfDice)
	local avg = math.floor(averageWithAllDice)

	dieSettingSide:AddText(("Min: %d | Avg: %d | Max: %d"):format(min, avg, max))

	local abilityPrioritySide = layoutTable:AddCell()
	abilityPrioritySide:AddSeparatorText("Primary Abilities Override ( ? )"):Tooltip():AddText([[
	By default this mutator will inspect the assigned Spell Lists to determine these priorities, and if no spell lists have been assigned or none of them have had priorities set,
will inspect the current Entity stats and use that to infer priority. Specifying any of the below will override that determination to use the specified value in all scenarios]])
	local abilityGroup = abilityPrioritySide:AddGroup("AbilityGroup")

	local function build()
		Helpers:KillChildren(abilityGroup)

		local function buildAbilityOptions(abilityCategory)
			local opts = {}
			for i = 0, 6 do
				local ability = tostring(Ext.Enums.AbilityId[i])
				local index = TableUtils:IndexOf(mutator.values.overriddenAbilityPriorities, ability)

				if not index or index == abilityCategory then
					table.insert(opts, ability)
				end
			end

			return opts, (mutator.values.overriddenAbilityPriorities and TableUtils:IndexOf(opts, mutator.values.overriddenAbilityPriorities[abilityCategory]) or 0) - 1
		end

		local abilityTable = abilityGroup:AddTable("", 2)
		abilityTable.SizingFixedFit = true

		for _, prop in ipairs({ "Primary", "Secondary", "Tertiary" }) do
			local row = abilityTable:AddRow()
			local abilityCategory = prop:lower() .. "Stat"
			row:AddCell():AddText(prop .. ": ")

			local input = row:AddCell():AddCombo("##" .. prop)
			input.WidthFitPreview = true
			input.SameLine = true
			input.Options, input.SelectedIndex = buildAbilityOptions(abilityCategory)

			input.OnChange = function()
				local chosenAbility = input.Options[input.SelectedIndex + 1]
				if chosenAbility == "None" then
					if mutator.values.overriddenAbilityPriorities and mutator.values.overriddenAbilityPriorities[abilityCategory] then
						mutator.values.overriddenAbilityPriorities[abilityCategory] = nil
						build()
					end
				else
					mutator.values.overriddenAbilityPriorities = mutator.values.overriddenAbilityPriorities or {}
					mutator.values.overriddenAbilityPriorities[abilityCategory] = chosenAbility
					build()
				end
			end
		end
	end
	build()

	mutator.modifiers = mutator.modifiers or {}
	self:renderModifiers(parent:AddGroup("Modifiers"), mutator.modifiers)
end

---@param modifiers AbilitiesMutatorModifiers
function AbilitiesMutator:renderModifiers(parent, modifiers)
	Helpers:KillChildren(parent)

	local sep = parent:AddSeparatorText("Min/Max Scores ( ? )")
	sep:SetStyle("SeparatorTextAlign", 0.05, 0.5)
	sep:Tooltip():AddText([[
	Setting the below will keep any "rolled" score within the specified boundaries (before adding +2 and +1 to the primary/secondary abilities)
Empty values/0 will remove that boundary]])

	parent:AddText("Minimum Score Value")
	local minInput = parent:AddInputInt("", modifiers.minimumScoreValue)
	minInput.SameLine = true
	minInput.ItemWidth = 80
	minInput.DisplayEmptyRefVal = true
	minInput.ParseEmptyRefVal = true
	minInput.OnChange = function()
		if minInput.Value[1] <= 0 or (modifiers.maximumScoreValue and minInput.Value[1] > modifiers.maximumScoreValue) then
			minInput.Value = { 0, 0, 0, 0 }
			modifiers.minimumScoreValue = nil
		else
			modifiers.minimumScoreValue = minInput.Value[1]
		end
	end

	parent:AddText("Maximum Score Value")
	local maxInput = parent:AddInputInt("", modifiers.maximumScoreValue)
	maxInput.SameLine = true
	maxInput.DisplayEmptyRefVal = true
	maxInput.ParseEmptyRefVal = true
	maxInput.ItemWidth = 80
	maxInput.OnChange = function()
		if maxInput.Value[1] <= 0 or (modifiers.minimumScoreValue and maxInput.Value[1] < modifiers.minimumScoreValue) then
			maxInput.Value = { 0, 0, 0, 0 }
			modifiers.maximumScoreValue = nil
		else
			modifiers.maximumScoreValue = maxInput.Value[1]
		end
	end
end

function AbilitiesMutator:undoMutator(entity, entityVar, primedEntityVar, reprocessTransient)
	Logger:BasicDebug("Removed boost %s", entityVar.originalValues[self.name])
	Osi.RemoveBoosts(entity.Uuid.EntityUuid, entityVar.originalValues[self.name], 1, "Lab", "")
end

function AbilitiesMutator:applyMutator(entity, entityVar)
	---@type number[]
	local rolledScores = {}

	---@type AbilitiesMutator
	local mutator = entityVar.appliedMutators[self.name]

	local boostString = ""
	local template = "Ability(%s,%d);"

	if mutator.staticMutator == false then
		for _ = 1, 6 do
			---@type number[]
			local rolls = {}

			for _ = 1, mutator.values.dieSettings.numberOfDice do
				rolls[#rolls + 1] = Ext.Math.Random(mutator.values.dieSettings.diceSides)
			end
			table.sort(rolls, function(a, b)
				return a > b
			end)

			Logger:BasicTrace("Rolls before removing lowest + enforcing boundaries are: %s", rolls)

			local sum = 0
			for d = 1, (#rolls - mutator.values.dieSettings.numberOfLowestToRemove) do
				sum = sum + rolls[d]
			end

			if mutator.modifiers.minimumScoreValue and sum < mutator.modifiers.minimumScoreValue then
				sum = mutator.modifiers.minimumScoreValue
			elseif mutator.modifiers.maximumScoreValue and sum > mutator.modifiers.maximumScoreValue then
				sum = mutator.modifiers.maximumScoreValue
			end

			table.insert(rolledScores, sum)
		end

		table.sort(rolledScores, function(a, b)
			return a > b
		end)
		Logger:BasicDebug("Rolled values before assignment: %s", rolledScores)

		---@type AbilityPriorities
		local abilities = {}

		if mutator.values.overriddenAbilityPriorities then
			local override = mutator.values.overriddenAbilityPriorities
			abilities = TableUtils:DeeplyCopyTable(override)

			Logger:BasicDebug("Overridden Ability Priorities are: %s", override)
		end

		if not abilities.primaryStat or not abilities.secondaryStat or not abilities.tertiaryStat then
			if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists then
				---@type {[Guid]: number}
				local appliedSpellLists = entityVar.appliedMutators[SpellListMutator.name].appliedLists

				local lastSpellListId = nil

				for spellListId, levelsAssigned in TableUtils:OrderedPairs(appliedSpellLists, function(_, levelsAssigned)
					-- Sorting descending?
					return levelsAssigned * -1
				end) do
					local spellList = MutationConfigurationProxy.lists.spellLists[spellListId]
					spellList = spellList.__real or spellList

					if spellList.abilityPriorities then
						if not lastSpellListId then
							lastSpellListId = spellListId
							for category, ability in pairs(spellList.abilityPriorities) do
								if abilities[category] and not TableUtils:IndexOf(abilities, ability) then
									abilities[category] = ability
								end
							end
							Logger:BasicDebug("List %s is the highest leveled list assigned (at %s) - using it as the base", spellList.name, levelsAssigned)
						else
							local lastAssignedListId = lastSpellListId
							for category, ability in pairs(spellList.abilityPriorities) do
								if not abilities[category] and not TableUtils:IndexOf(abilities, ability) then
									Logger:BasicDebug("Assigned ability priority %s to %s due to %s having it set when the previous list did not",
										category,
										ability,
										spellList.name)
									lastSpellListId = spellListId
									abilities[category] = ability
								end
							end
							if (appliedSpellLists[spellListId] / appliedSpellLists[lastAssignedListId]) >= .6 then
								Logger:BasicDebug("Spell list %s is %s%% of list %s's level - averaging out score priority",
									spellList.name,
									(appliedSpellLists[spellListId] / appliedSpellLists[lastAssignedListId]) * 100,
									MutationConfigurationProxy.lists.spellLists[lastAssignedListId].name)

								if not TableUtils:IndexOf(abilities, spellList.abilityPriorities.primaryStat) then
									abilities.tertiaryStat = spellList.abilityPriorities.primaryStat
									Logger:BasicDebug("Assigned %s to the tertiary ability as it's %s's primary ability",
										abilities.tertiaryStat,
										spellList.name)
								elseif abilities.tertiaryStat == spellList.abilityPriorities.primaryStat then
									abilities.tertiaryStat = abilities.secondaryStat
									abilities.secondaryStat = spellList.abilityPriorities.primaryStat

									Logger:BasicDebug("Swapped %s from the tertiary to the secondary ability as it's %s's primary ability",
										abilities.secondaryStat,
										spellList.name)
								end
								-- We found the next closest to the highest spell list, good enough to not play swap-a-rama for super low list levels
								break
							end
						end
					end
				end

				Logger:BasicDebug("Ability priorities after being determined by spell lists: %s", abilities)
			end
		end

		for abilityIndex in TableUtils:OrderedPairs(entity.Stats.Abilities, function(key, value)
			return value * -1
		end) do
			local ability = tostring(Ext.Enums.AbilityId[abilityIndex - 1])
			if not TableUtils:IndexOf(abilities, ability) then
				if not abilities.primaryStat then
					abilities.primaryStat = ability
				elseif not abilities.secondaryStat then
					abilities.secondaryStat = ability
				elseif not abilities.tertiaryStat then
					abilities.tertiaryStat = ability
				elseif not abilities.fourth then
					abilities.fourth = ability
				elseif not abilities.fifth then
					abilities.fifth = ability
				elseif not abilities.sixth then
					abilities.sixth = ability
				end
			end
		end

		Logger:BasicDebug("Final ability score priorities: %s", abilities)

		local categories = { "primaryStat", "secondaryStat", "tertiaryStat", "fourth", "fifth", "sixth" }
		local bonuses = { 2, 1, 0, 0, 0, 0 }

		for i, category in ipairs(categories) do
			local abilityId = abilities[category]
			if abilityId then
				boostString = boostString ..
					string.format(template, abilityId, (rolledScores[i] - entity.Stats.Abilities[Ext.Enums.AbilityId[abilityId].Value + 1]) + bonuses[i])
			end
		end
	else
		for abilityId, scores in TableUtils:OrderedPairs(mutator.values.scores, function(key, value)
			return Ext.Enums.AbilityId[key]
		end) do
			if TableUtils:CountElements(scores) > 1 or not scores[1] or scores[1] ~= 0 then
				local baseScore = (scores[1] and scores[1] > 0 and scores[1]) or entity.Stats.Abilities[Ext.Enums.AbilityId[abilityId].Value + 1]

				local totalScore = baseScore

				for level, amountToAdd in TableUtils:OrderedPairs(scores) do
					level = tonumber(level)
					if level ~= 1 then
						if level > entity.EocLevel.Level then
							break
						else
							totalScore = totalScore + amountToAdd
						end
					end
				end
				totalScore = math.max(1, totalScore)
				boostString = boostString .. template:format(abilityId, totalScore - entity.Stats.Abilities[Ext.Enums.AbilityId[abilityId].Value + 1])
			end
		end
	end

	entityVar.originalValues[self.name] = boostString
	Osi.AddBoosts(entity.Uuid.EntityUuid, boostString, "Lab", "")

	if Logger:IsLogLevelEnabled(Logger.PrintTypes.DEBUG) then
		local scoreTable = {}
		for index, abilityId in ipairs(Ext.Enums.AbilityId) do
			if tostring(abilityId) ~= "Sentinel" then
				scoreTable[tostring(abilityId)] = entity.Stats.Abilities[index + 1]
			end
		end

		Logger:BasicDebug("Entity Abilities updated using Boosts: %s\nFrom Base: %s", boostString, scoreTable)
	end
end

---@return MazzleDocsDocumentation
function AbilitiesMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Abilities",
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
Transient: Yes
Composable: No]]
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
					[[This mutator allows you to reroll an entity's Abilities, the same way a player would, creating variety in enemy abilities while still ensuring proper difficulty curves.]]
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
					text = [[See Tooltips in the Mutator for explanations of the content]]
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
					text = [[
If the Dice Roll variant of the mutator is used, then the following applies:					
When determining which Abilities get the highest scores, the following is done in order:

1. Check the Overrides section - anything set here will override the following
2. Check the spell list that had the most levels assigned - if that has Primary Abilities set, use those
	i. If more than one list was assigned, check the next with the second-highest amount of levels assigned
	ii. Use the assigned ability priority if currently unset (i.e. the first spell list didn't set Primary)
	iii. If the second spell list's Secondary Ability is the same as the first List's Tertiary Ability, swap the secondary and the tertiary
		a. If the second list's Second Ability is not the same as the first's tertiary, make it the tertiary ability
3. Inspect the entity's current ability scores and use that to determine any missing Ability priorites, including 4/5/6

Priorities 4/5/6 currently can't be set by the user, as that seemed superfluous to me, but open to changing it if necessary.

If the Static variant is used, then the behavior is as described in the tooltips.

Both variants set their values via the `Osi.AddBoosts` function, constructing an `Ability(%s,%d)` expression for each ability.]]
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
						"should have a random spread mimicking the player's assignments, using their current ability scores as the priorities for rolls",
						"should have a tight, high-value spread that are assigned per their assigned spell list, then their current ability scores"
					}
				} --[[@as MazzleDoctsBullet]],
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function AbilitiesMutator:generateChangelog()
	return {
		["1.8.0"] = {
			type = "Bullet",
			text = {
				"Adds a new Static Values variant"
			}
		},
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Fix execution variable so it doesn't always try to calculate the prime 3 if they're already set"
			}
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
