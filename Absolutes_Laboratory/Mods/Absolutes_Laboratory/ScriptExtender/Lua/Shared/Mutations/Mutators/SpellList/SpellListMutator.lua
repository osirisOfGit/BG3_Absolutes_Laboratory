Ext.Require("Shared/Mutations/Mutators/SpellList/SpellListDesigner.lua")

SpellListMutator = MutatorInterface:new("SpellList")

---@class SpellListCriteriaEntry
---@field isOneOfClasses Guid[]?
---@field abilityCondition SpellListAbilityScoreCondition[]?
---@field isOneOfProgressions Guid[]?

---@class LeveledSpellPool
---@field anchorLevel number
---@field comparator "gte"|"lte"
---@field abilityId AbilityId
---@field spellLists Guid[]

---@class SpellMutatorGroup
---@field leveledSpellPool LeveledSpellPool[]?
---@field randomSpellPool Guid[]?
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

	for _, spellMutatorGroup in TableUtils:OrderedPairs(mutator.values) do
		local row = displayTable:AddRow()

		local poolCell = row:AddCell()
		local poolCombo = poolCell:AddCombo("")
		poolCombo.Options = { "Single Pool", "Grouped By Character Level" }
		poolCombo.SelectedIndex = spellMutatorGroup.randomSpellPool and 0 or 1
		poolCombo.OnChange = function()
			if spellMutatorGroup.leveledSpellPool then
				spellMutatorGroup.leveledSpellPool.delete = true
			else
				spellMutatorGroup.randomSpellPool.delete = true
			end

			spellMutatorGroup[poolCombo.SelectedIndex == 0 and "randomSpellPool" or "leveledSpellPool"] = {}

			self:renderMutator(parent, mutator)
		end

		local poolGroup = poolCell:AddGroup("Pool")
		if spellMutatorGroup.randomSpellPool then
			local function renderPool()
				for _, spellList in TableUtils:OrderedPairs(spellMutatorGroup.randomSpellPool, function(key)
					return configuredSpellLists[key].name
				end) do
					spellList = configuredSpellLists[spellList]
					local text = poolGroup:AddText(spellList.name)
					if spellList.description ~= "" then
						text:Tooltip():AddText(spellList.description)
					end
				end
			end
			renderPool()

			local addButton = poolCell:AddButton("+")
			addButton.OnClick = function()
				Helpers:KillChildren(popup)
				popup:Open()

				for id, spellList in TableUtils:OrderedPairs(configuredSpellLists, function(key)
					return configuredSpellLists[key].name
				end) do
					---@type ExtuiSelectable
					local select = popup:AddSelectable(spellList.name, "DontClosePopups")
					select.Selected = TableUtils:IndexOf(spellMutatorGroup.randomSpellPool, id) ~= nil
					select.OnClick = function()
						local index = TableUtils:IndexOf(spellMutatorGroup.randomSpellPool, id)
						if index then
							spellMutatorGroup.randomSpellPool[index] = nil
							select.Selected = false
						else
							select.Selected = true
							table.insert(spellMutatorGroup.randomSpellPool, id)
						end
						Helpers:KillChildren(poolGroup)
						renderPool()
					end
				end
			end
		else
		end

		local criteriaCell = row:AddCell()
	end
	local addGroupButton = parent:AddButton("+")
	addGroupButton.OnClick = function()
		table.insert(mutator.values, {
			randomSpellPool = {}
		} --[[@as SpellMutatorGroup]])
		self:renderMutator(parent, mutator)
	end
end

function SpellListMutator:applyMutator(entity, mutator)

end

function SpellListMutator:undoMutator(entity, mutator)

end
