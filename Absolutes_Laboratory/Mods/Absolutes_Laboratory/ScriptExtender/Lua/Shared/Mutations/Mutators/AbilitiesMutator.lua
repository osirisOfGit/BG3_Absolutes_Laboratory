AbilitiesMutator = MutatorInterface:new("Abilities")

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

---@class AbilitiesMutator : Mutator
---@field values AbilityMutatorValue
---@field modifiers AbilitiesMutatorModifiers?

---@param mutator AbilitiesMutator
function AbilitiesMutator:renderMutator(parent, mutator)
	Helpers:KillChildren(parent)
	mutator.values = mutator.values or {}
	mutator.values.dieSettings = mutator.values.dieSettings or {
		diceSides = 6,
		numberOfDice = 4,
		numberOfLowestToRemove = 1
	} --[[@as DieSettings]]

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
	local numDiceInput = numDiceRow:AddCell():AddInputInt("", mutator.values.dieSettings.numberOfDice)
	numDiceInput.ItemWidth = 80
	numDiceInput.OnChange = function()
		if numDiceInput.Value[1] <= 0 then
			local currValue = mutator.values.dieSettings.numberOfDice
			numDiceInput.Value = { currValue, currValue, currValue, currValue }
		else
			mutator.values.dieSettings.numberOfDice = numDiceInput.Value[1]
		end
	end

	local diceSidesRow = dieTable:AddRow()
	diceSidesRow:AddCell():AddText("Die Type To Roll (i.e. d6)")
	local diceSideCell = diceSidesRow:AddCell()
	local diceSideInput = diceSideCell:AddInputInt("", mutator.values.dieSettings.diceSides)
	diceSideInput.ItemWidth = 80
	diceSideInput.OnChange = function()
		if diceSideInput.Value[1] <= 0 then
			local currValue = mutator.values.dieSettings.diceSides
			diceSideInput.Value = { currValue, currValue, currValue, currValue }
		else
			mutator.values.dieSettings.diceSides = diceSideInput.Value[1]
		end
	end

	local numToDropRow = dieTable:AddRow()
	numToDropRow:AddCell():AddText("# of Lowest Rolls To Drop")
	local numToDropInput = numToDropRow:AddCell():AddInputInt("", mutator.values.dieSettings.numberOfLowestToRemove)
	numToDropInput.ItemWidth = 80
	numToDropInput.OnChange = function()
		if numToDropInput.Value[1] <= 0 then
			local currValue = mutator.values.dieSettings.numberOfLowestToRemove
			numToDropInput.Value = { currValue, currValue, currValue, currValue }
		else
			mutator.values.dieSettings.numberOfLowestToRemove = numToDropInput.Value[1]
		end
	end

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

	if not primary or not secondary or not tertiary then
		if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists then
			---@type {[Guid]: number}
			local appliedSpellLists = entityVar.appliedMutators[SpellListMutator.name].appliedLists

			local lastSpellListId = nil

			for spellListId, levelsAssigned in TableUtils:OrderedPairs(appliedSpellLists, function(_, levelsAssigned)
				-- Sorting descending?
				return levelsAssigned * -1
			end) do
				local spellList = MutationConfigurationProxy.spellLists[spellListId]
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
								MutationConfigurationProxy.spellLists[lastAssignedListId].name)

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

	for abilityIndex in TableUtils:OrderedPairs(entity.BaseStats.BaseAbilities, function(key, value)
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

	local boostString = ""
	local template = "Ability(%s,%d);"

	local categories = { "primaryStat", "secondaryStat", "tertiaryStat", "fourth", "fifth", "sixth" }
	local bonuses = { 2, 1, 0, 0, 0, 0 }

	for i, category in ipairs(categories) do
		local abilityId = abilities[category]
		if abilityId then
			boostString = boostString ..
				string.format(template, abilityId, (rolledScores[i] - entity.BaseStats.BaseAbilities[Ext.Enums.AbilityId[abilityId].Value + 1]) + bonuses[i])
		end
	end

	entityVar.originalValues[self.name] = boostString
	Osi.AddBoosts(entity.Uuid.EntityUuid, boostString, "Lab", "")

	Logger:BasicDebug("Entity Abilities updated using Boosts: %s\nFrom Base: %s",
		boostString,
		entity.BaseStats.BaseAbilities)
end
