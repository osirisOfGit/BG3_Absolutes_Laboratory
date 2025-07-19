AbilitiesMutator = MutatorInterface:new("Abilities")

function AbilitiesMutator:priority()
	return self:recordPriority(SpellListMutator:priority() + 1)
end

function AbilitiesMutator:canBeAdditive()
	return false
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
end
