---@class ClassesAndSubclassesMutatorClass : MutatorInterface
ClassesAndSubclassesMutator = MutatorInterface:new("Classes And Subclasses")
ClassesAndSubclassesMutator.affectedComponents = {
	"Classes",
	"Stats"
}

function ClassesAndSubclassesMutator:priority()
	return self:recordPriority(SpellListMutator:priority() + 1)
end

function ClassesAndSubclassesMutator:canBeAdditive()
	return true
end

function ClassesAndSubclassesMutator:Transient()
	return false
end

---@class ClassAbilityOverrides
---@field rangedAttackAbility AbilityId
---@field spellCastingAbility AbilityId
---@field unarmedAttackAbility AbilityId

---@class ClassesConditionalGroup
---@field classIds {[Guid] : number}?
---@field spellListDependencies Guid[]?
---@field numberOfSpellLists number?
---@field statAbilityOverrides ClassAbilityOverrides?

---@class ClassesAndSubclassesMutator : Mutator
---@field values ClassesConditionalGroup[]


---@type {[Guid] : Guid[]}
ClassesAndSubclassesMutator.classesAndSubclasses = {}

---@type {[Guid]: string}
ClassesAndSubclassesMutator.translationMap = {}

function ClassesAndSubclassesMutator:initClassIndex()
	if not next(self.classesAndSubclasses) then
		for _, classId in pairs(Ext.StaticData.GetAll("ClassDescription")) do
			---@type ResourceClassDescription
			local class = Ext.StaticData.Get(classId, "ClassDescription")

			if class.ParentGuid and class.ParentGuid ~= "00000000-0000-0000-0000-000000000000" and class.ParentGuid ~= "" then
				if not self.classesAndSubclasses[class.ParentGuid] then
					self.classesAndSubclasses[class.ParentGuid] = {}
				end

				table.insert(self.classesAndSubclasses[class.ParentGuid], classId)
			elseif not self.classesAndSubclasses[classId] then
				self.classesAndSubclasses[classId] = {}
			end

			local name = class.DisplayName:Get() or class.Name

			self.translationMap[classId] = name
		end
	end
end

---@param mutator ClassesAndSubclassesMutator
function ClassesAndSubclassesMutator:renderMutator(parent, mutator)
	self:initClassIndex()
	mutator.values = mutator.values or {}

	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

	local classTable = Styler:TwoColumnTable(parent)
	classTable.ColumnDefs[1].Width = 20
	classTable.BordersV = false
	classTable.Resizable = false
	classTable.Borders = false
	classTable.BordersH = true

	for i, classConditionalGroup in ipairs(mutator.values) do
		local row = classTable:AddRow()

		local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", { 16, 16 }))
		delete.OnClick = function()
			for x = i, TableUtils:CountElements(mutator.values) do
				mutator.values[x].delete = true
				mutator.values[x] = TableUtils:DeeplyCopyTable(mutator.values._real[x + 1])
			end
			Helpers:KillChildren(parent)
			self:renderMutator(parent, mutator)
		end

		local groupCell = row:AddCell()
		local conditionalGroupTable = groupCell:AddTable(tostring(i), 2)
		conditionalGroupTable.Resizable = true

		local classRow = conditionalGroupTable:AddRow()
		local classDefCell = classRow:AddCell()
		---@type ExtuiText
		local errorText

		local groupTable = classDefCell:AddTable("", 2)
		groupTable.SizingStretchSame = true

		local headerRow = groupTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText("Class")
		headerRow:AddCell():AddText("Level % ( ? )"):Tooltip():AddText([[
	What % of the selected entity's character level should be used for this class's level (rounded as needed)
e.g. if a class is set to 75% and the entity's level is 10, they will be level 7 in that specific class
All %s in this group must add up to 100% - input is disabled if there is only 1 class in the group]])

		if classConditionalGroup.classIds then
			for classId, levelPercentage in TableUtils:OrderedPairs(classConditionalGroup.classIds, function(_, value)
				return value
			end) do
				local groupRow = groupTable:AddRow()

				local name = self.translationMap[classId]
				---@type ResourceClassDescription
				local class = Ext.StaticData.Get(classId, "ClassDescription")

				if self.translationMap[class.ParentGuid] then
					name = self.translationMap[class.ParentGuid] .. " - " .. name
				end

				local classCell = groupRow:AddCell()
				local deleteClass = Styler:ImageButton(classCell:AddImageButton("delete" .. classId, "ico_red_x", { 16, 16 }))
				deleteClass.OnClick = function()
					classConditionalGroup.classIds[classId] = nil
					if TableUtils:CountElements(classConditionalGroup.classIds) ~= 0 then
						for otherID, otherLevelPercentage in pairs(classConditionalGroup.classIds) do
							if levelPercentage + otherLevelPercentage <= 100 then
								classConditionalGroup.classIds[otherID] = otherLevelPercentage + levelPercentage
								break
							end
						end
					else
						classConditionalGroup.classIds.delete = true
					end

					self:renderMutator(parent, mutator)
				end

				Styler:HyperlinkText(classCell, name, function(parent)
					ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(classId, "ClassDescription"), parent)
				end).SameLine = true

				local levelPercentageInput = groupRow:AddCell():AddInputInt("%", levelPercentage)
				levelPercentageInput.IDContext = classId
				levelPercentageInput.UserData = classId
				levelPercentageInput.ItemWidth = Styler:ScaleFactor() * 80
				levelPercentageInput.SameLine = true

				if TableUtils:CountElements(classConditionalGroup.classIds) == 1 then
					levelPercentageInput.Disabled = true
				else
					levelPercentageInput.OnChange = function()
						local total = levelPercentageInput.Value[1]
						for _, childRow in pairs(groupTable.Children) do
							local input = childRow.Children[2].Children[1]
							if input.UserData and input.UserData ~= classId then
								---@cast input ExtuiInputInt
								total = total + input.Value[1]
							end
						end

						if total ~= 100 then
							errorText.Visible = true
						else
							errorText.Visible = false
						end
					end

					levelPercentageInput.OnDeactivate = function()
						if levelPercentageInput.Value[1] < 0 then
							levelPercentageInput.Value = { 0, 0, 0, 0 }
						end

						local total = levelPercentageInput.Value[1]
						for _, childRow in pairs(groupTable.Children) do
							local input = childRow.Children[2].Children[1]
							if input.UserData and input.UserData ~= classId then
								---@cast input ExtuiInputInt
								total = total + input.Value[1]
							end
						end

						if total ~= 100 then
							errorText.Visible = true
						else
							for _, childRow in pairs(groupTable.Children) do
								local input = childRow.Children[2].Children[1]
								if input.UserData then
									---@cast input ExtuiInputInt
									classConditionalGroup.classIds[input.UserData] = input.Value[1]
								end
							end

							self:renderMutator(parent, mutator)
						end
					end
				end
			end
		end

		errorText = classDefCell:AddText("All %s must add up to 100%!")
		-- Red
		errorText:SetColor("Text", { 1, 0.02, 0, 1 })
		errorText.Visible = false

		groupCell:AddButton("Add Class").OnClick = function()
			Helpers:KillChildren(popup)
			popup:Open()

			for classId, subclasses in TableUtils:OrderedPairs(self.classesAndSubclasses, function(key, value)
				return self.translationMap[key]
			end) do
				if next(subclasses) then
					---@type ExtuiMenu
					local menu = popup:AddMenu(self.translationMap[classId])
					menu.Disabled = (classConditionalGroup.classIds and classConditionalGroup.classIds[classId]) ~= nil

					menu:AddSelectable(self.translationMap[classId]).OnClick = function()
						classConditionalGroup.classIds = classConditionalGroup.classIds or {}
						classConditionalGroup.classIds[classId] = TableUtils:CountElements(classConditionalGroup.classIds) == 0 and 100 or 0

						self:renderMutator(parent, mutator)
					end

					for _, subclassId in TableUtils:OrderedPairs(subclasses, function(key, value)
						return self.translationMap[value]
					end) do
						if not menu.Disabled then
							menu.Disabled = (classConditionalGroup.classIds and classConditionalGroup.classIds[subclassId]) ~= nil
						end

						menu:AddSelectable(self.translationMap[subclassId]).OnClick = function()
							classConditionalGroup.classIds = classConditionalGroup.classIds or {}
							classConditionalGroup.classIds[subclassId] = TableUtils:CountElements(classConditionalGroup.classIds) == 0 and 100 or 0

							self:renderMutator(parent, mutator)
						end
					end

					if menu.Disabled then
						menu:SetStyle("Alpha", 0.5)
					end
				end
			end
		end

		local conditionalCell = classRow:AddCell()

		local inputToPreventOffset = conditionalCell:AddInputInt("")
		inputToPreventOffset:SetStyle("Alpha", 0)
		inputToPreventOffset.ItemWidth = 0

		conditionalCell:AddText("Must have been assigned ").SameLine = true
		local spellListNumberInput = conditionalCell:AddInputInt("", classConditionalGroup.numberOfSpellLists or 0)
		spellListNumberInput.ItemWidth = Styler:ScaleFactor() * 40
		spellListNumberInput.SameLine = true
		spellListNumberInput.OnDeactivate = function()
			if spellListNumberInput.Value[1] < 0 then
				spellListNumberInput.Value = { 0, 0, 0, 0 }
			end
			classConditionalGroup.numberOfSpellLists = spellListNumberInput.Value[1]
		end

		conditionalCell:AddText(" or more of the following Spell Lists:").SameLine = true

		if classConditionalGroup.spellListDependencies then
			for i, spellListId in TableUtils:OrderedPairs(classConditionalGroup.spellListDependencies, function(key, value)
					return MutationConfigurationProxy.lists.spellLists[value].name
				end,
				function(key, value)
					return MutationConfigurationProxy.lists.spellLists[value] ~= nil
				end)
			do
				local delete = Styler:ImageButton(conditionalCell:AddImageButton("delete" .. spellListId, "ico_red_x", { 16, 16 }))
				delete.OnClick = function()
					for x = i, TableUtils:CountElements(classConditionalGroup.spellListDependencies) do
						classConditionalGroup.spellListDependencies[x] = classConditionalGroup.spellListDependencies[x + 1]
					end

					self:renderMutator(parent, mutator)
				end

				local spellList = MutationConfigurationProxy.lists.spellLists[spellListId]
				local spellListLink = conditionalCell:AddTextLink(spellList.name .. (spellList.modId and string.format(" (%s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
				spellListLink.IDContext = spellListId
				spellListLink.SameLine = true
				spellListLink.OnClick = function()
					SpellListDesigner:launch(spellListId)
				end
			end
		end

		conditionalCell:AddButton("Add Spell List").OnClick = function()
			Helpers:KillChildren(popup)
			popup:Open()

			for spellListId, spellList in TableUtils:OrderedPairs(MutationConfigurationProxy.lists.spellLists, function(key, value)
				return value.name .. (value.modId and string.format(" (%s)", Ext.Mod.GetMod(value.modId).Info.Name) or "")
			end) do
				---@type ExtuiSelectable
				local select = popup:AddSelectable(spellList.name .. (spellList.modId and string.format(" (%s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
				select.Selected = TableUtils:IndexOf(classConditionalGroup.spellListDependencies, spellListId) ~= nil
				select.OnClick = function()
					-- selected is flipped by the time this fires
					if not select.Selected then
						for x = TableUtils:IndexOf(classConditionalGroup.spellListDependencies, spellListId), TableUtils:CountElements(classConditionalGroup.spellListDependencies) do
							classConditionalGroup.spellListDependencies[x] = classConditionalGroup.spellListDependencies[x + 1]
						end
					else
						classConditionalGroup.spellListDependencies = classConditionalGroup.spellListDependencies or {}
						table.insert(classConditionalGroup.spellListDependencies, spellListId)
					end
					self:renderMutator(parent, mutator)
				end
			end
		end

		conditionalCell:AddSeparatorText("Ability Overrides ( ? )"):Tooltip():AddText("\t If any of the below are not specified, the entity's default value will be preserved")
		local abilities = { "None", "Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma", "Sentinel" }

		local abilityOverrideTable = conditionalCell:AddTable("AbilityOverride", 2)
		abilityOverrideTable.SizingFixedFit = true

		local abilityFields = {
			{ label = "Spell Casting Ability",  field = "spellCastingAbility" },
			{ label = "Ranged Attack Ability",  field = "rangedAttackAbility" },
			{ label = "Unarmed Attack Ability", field = "unarmedAttackAbility" }
		}

		for _, abilityConfig in ipairs(abilityFields) do
			local row = abilityOverrideTable:AddRow()
			row:AddCell():AddText(abilityConfig.label)
			local combo = row:AddCell():AddCombo("")
			combo.WidthFitPreview = true
			combo.Options = abilities
			combo.SelectedIndex = (classConditionalGroup.statAbilityOverrides
				and TableUtils:IndexOf(abilities, classConditionalGroup.statAbilityOverrides[abilityConfig.field])
				or 0) - 1

			combo.OnChange = function()
				local val = combo.Options[combo.SelectedIndex + 1]
				if val == "None" then
					if classConditionalGroup.statAbilityOverrides then
						classConditionalGroup.statAbilityOverrides[abilityConfig.field] = nil
						if not classConditionalGroup.statAbilityOverrides() then
							classConditionalGroup.statAbilityOverrides.delete = true
						end
					end
					combo.SelectedIndex = -1
				else
					classConditionalGroup.statAbilityOverrides = classConditionalGroup.statAbilityOverrides or {}
					classConditionalGroup.statAbilityOverrides[abilityConfig.field] = val
				end
			end
		end
	end

	parent:AddButton("Add Class Group").OnClick = function()
		table.insert(mutator.values, {})
		self:renderMutator(parent, mutator)
	end
end

---@param mutator ClassesAndSubclassesMutator
function ClassesAndSubclassesMutator:handleDependencies(_, mutator, removeMissingDependencies)
	if not mutator.values then
		return
	end
	local classesIndex = Ext.StaticData.GetSources("ClassDescription")
	for c, classGroup in pairs(mutator.values) do
		for classId in pairs(classGroup.classIds) do
			---@type ResourceClassDescription
			local class = Ext.StaticData.Get(classId, "ClassDescription")
			if not class then
				classGroup.classIds[classId] = nil
				if not next(classGroup.classIds._real or classGroup.classIds) then
					mutator.values[c].delete = true
					mutator.values[c] = nil
				end
			elseif not removeMissingDependencies then
				local classSource = TableUtils:IndexOf(classesIndex, function(value)
					return TableUtils:IndexOf(value, classId) ~= nil
				end)
				if classSource then
					mutator.modDependencies = mutator.modDependencies or {}
					if not mutator.modDependencies[classSource] then
						local name, author, version = Helpers:BuildModFields(classSource)
						if author == "Larian" then
							goto continue
						end
						mutator.modDependencies[classSource] = {
							modName = name,
							modAuthor = author,
							modVersion = version,
							modId = classSource,
							packagedItems = {}
						}
					end

					mutator.modDependencies[classSource].packagedItems[classId] = class.DisplayName:Get() or class.Name
				end
				::continue::
			end
		end
	end
	TableUtils:ReindexNumericTable(mutator.values)
end

function ClassesAndSubclassesMutator:undoMutator(entity, entityVar)
	entity.Classes.Classes = {}
	if entityVar.originalValues[self.name] then
		for _, classDef in pairs(entityVar.originalValues[self.name].classes) do
			---@cast classDef ClassInfo
			entity.Classes.Classes[#entity.Classes.Classes + 1] = {
				ClassUUID = classDef.ClassUUID,
				SubClassUUID = classDef.SubClassUUID,
				Level = classDef.Level
			}
		end

		Logger:BasicDebug("Reverted classes to %s", entityVar.originalValues[self.name].classes)
	end

	if entityVar.originalValues[self.name].spellCastingAbility then
		Logger:BasicDebug("Reverted spellCastingAbility to %s", entityVar.originalValues[self.name].spellCastingAbility)
		entity.Stats.SpellCastingAbility = entityVar.originalValues[self.name].spellCastingAbility
	end

	if entityVar.originalValues[self.name].rangedAttackAbility then
		Logger:BasicDebug("Reverted rangedAttackAbility to %s", entityVar.originalValues[self.name].rangedAttackAbility)
		entity.Stats.RangedAttackAbility = entityVar.originalValues[self.name].rangedAttackAbility
	end

	if entityVar.originalValues[self.name].unarmedAttackAbility then
		Logger:BasicDebug("Reverted unarmedAttackAbility to %s", entityVar.originalValues[self.name].unarmedAttackAbility)
		entity.Stats.UnarmedAttackAbility = entityVar.originalValues[self.name].unarmedAttackAbility
	end
end

function ClassesAndSubclassesMutator:applyMutator(entity, entityVar)
	local classesMutators = entityVar.appliedMutators[self.name]
	if not classesMutators[1] then
		classesMutators = { classesMutators }
	end
	---@cast classesMutators ClassesAndSubclassesMutator[]

	---@type ClassesConditionalGroup[]
	local chosenClassGroups = {}

	for _, classesMutator in TableUtils:OrderedPairs(classesMutators) do
		for _, classConditonal in TableUtils:OrderedPairs(classesMutator.values) do
			if classConditonal.numberOfSpellLists and classConditonal.numberOfSpellLists > 0 then
				if classConditonal.spellListDependencies and next(classConditonal.spellListDependencies) then
					local numberMatched = 0
					if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists then
						for appliedSpellListId in pairs(entityVar.appliedMutators[SpellListMutator.name].appliedLists) do
							if TableUtils:IndexOf(classConditonal.spellListDependencies, appliedSpellListId) then
								numberMatched = numberMatched + 1
							end
						end
					end

					if numberMatched < classConditonal.numberOfSpellLists then
						Logger:BasicDebug("Skipping a class group because the number of matched spell lists, %s, is less than the defined minimum %s",
							numberMatched,
							classConditonal.numberOfSpellLists)

						goto continue
					end
				else
					Logger:BasicWarning("Skipping a Classes and Subclasses mutator spellList check because no spellLists were added to it despite specifying a number: %s",
						classConditonal)
				end
			end
			table.insert(chosenClassGroups, classConditonal)
			::continue::
		end
	end

	if next(chosenClassGroups) then
		Logger:BasicDebug("%s potential class groups were identified - randomly choosing one", #chosenClassGroups)
		---@type ClassesConditionalGroup
		local classGroup = chosenClassGroups[math.random(#chosenClassGroups)]
		if classGroup.classIds then
			entityVar.originalValues[self.name] = {
				classes = TableUtils:DeeplyCopyTable(Ext.Types.Serialize(entity.Classes.Classes))
			}

			entity.Classes.Classes = {}

			local classesLeft = TableUtils:CountElements(classGroup.classIds)
			local classLevelsLeft = entity.AvailableLevel.Level
			for classId, levelPercentage in pairs(classGroup.classIds) do
				---@type ResourceClassDescription
				local class = Ext.StaticData.Get(classId, "ClassDescription")
				if class then
					local hasParentClass = Ext.StaticData.Get(class.ParentGuid, "ClassDescription") ~= nil

					if classesLeft == 1 then
						entity.Classes.Classes[#entity.Classes.Classes + 1] = {
							ClassUUID = hasParentClass and class.ParentGuid or classId,
							Level = classLevelsLeft,
							SubClassUUID = hasParentClass and classId or nil
						}
						Logger:BasicDebug("Added class %s at level %s", class.DisplayName:Get() or class.Name, classLevelsLeft)
					else
						local desiredClassLevel = math.ceil(entity.AvailableLevel.Level * (levelPercentage / 100))
						if desiredClassLevel > 0 then
							entity.Classes.Classes[#entity.Classes.Classes + 1] = {
								ClassUUID = hasParentClass and class.ParentGuid or classId,
								Level = desiredClassLevel,
								SubClassUUID = hasParentClass and classId or nil
							}

							Logger:BasicDebug("Added class %s at level %s", class.DisplayName:Get() or class.Name, desiredClassLevel)
							classLevelsLeft = classLevelsLeft - desiredClassLevel
						end
					end

					classesLeft = classesLeft - 1
					if classLevelsLeft == 0 then
						break
					end
				end
			end

			if classGroup.statAbilityOverrides then
				if classGroup.statAbilityOverrides.spellCastingAbility and entity.Stats.SpellCastingAbility ~= classGroup.statAbilityOverrides.spellCastingAbility then
					entityVar.originalValues[self.name].spellCastingAbility = entity.Stats.SpellCastingAbility
					entity.Stats.SpellCastingAbility = classGroup.statAbilityOverrides.spellCastingAbility
				end

				if classGroup.statAbilityOverrides.rangedAttackAbility and entity.Stats.RangedAttackAbility ~= classGroup.statAbilityOverrides.rangedAttackAbility then
					entityVar.originalValues[self.name].rangedAttackAbility = entity.Stats.RangedAttackAbility
					entity.Stats.RangedAttackAbility = classGroup.statAbilityOverrides.rangedAttackAbility
				end

				if classGroup.statAbilityOverrides.unarmedAttackAbility and entity.Stats.UnarmedAttackAbility ~= classGroup.statAbilityOverrides.unarmedAttackAbility then
					entityVar.originalValues[self.name].unarmedAttackAbility = entity.Stats.UnarmedAttackAbility
					entity.Stats.UnarmedAttackAbility = classGroup.statAbilityOverrides.unarmedAttackAbility
				end
			end
		end
	else
		Logger:BasicDebug("No class groups were chosen - finishing early")
	end
end

function ClassesAndSubclassesMutator:FinalizeMutator(entity)
	entity:Replicate("Classes")
	entity:Replicate("Stats")
end

---@return MazzleDocsDocumentation
function ClassesAndSubclassesMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Classes And Subclasses",
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
Composable: Yes - Class Groups will be combined into one pool and one will be randomly chosen (post filtering)]]
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
					[[Functionally speaking, Classes have very little impact on gameplay functionality - as far as I'm aware, it only matters for specific spells that check Class level instead of entity level.
Still, it's good flavour, useful in those cases, and a valuable dependency for the Action Resources Mutator, so here we are.]]
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

Class Groups: Configured on the left hand side, this section contains a list of classes that should _all_ be assigned to the entity, adding up to 100% of the entity's Level (per the EocLevel component).
You can add multiple subclasses from one main class, but if you add the Main class you won't be allowed to add any subclasses from it.

Modifiers: On the right hand side you'll find two modifiers:

	Spell List Dependencies - this is a simple dependency that stats the entity must have been assigned at least 1 level of the specific amount of lists from the dependency pool - for example, you can specify that the group should only apply if the entity had the Bard AND Wizard spell lists applied, _or_ the Bard OR the Wizard lists, allowing for precise multi-class control.
	
	Ability Overrides: Allows specifying what ability the entity should use for the applicable rolls, otherwise whatever is currently on the entity will be used (can be found under the Stats component on the Entity in the Inspector).
		

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
					[[When setting the classes, the `Classes.Classes` component is overwritten entirely; any specific Abilities overwrite their respective Stat component property: SpellCastingAbility, RangedAttackAbility, UnarmedAttackAbility. ]]
				}
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function ClassesAndSubclassesMutator:generateChangelog()
	return {
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Sligtly widens inputs and makes sure UI elements scale appropriately",
				"Changes from Transient to _not_ transient, allowing Lab to undo the changes itself"
			}
		} --[[@as MazzleDocsContentItem]]
	}
end
