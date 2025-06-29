ClassesAndSubclassesMutator = MutatorInterface:new("Classes And Subclasses")

function ClassesAndSubclassesMutator:priority()
	return SpellListMutator:priority() + 1
end

function ClassesAndSubclassesMutator:canBeAdditive()
	return true
end

---@class ClassesConditionalGroup
---@field classIds {[Guid] : number}?
---@field spellListDependencies Guid[]?
---@field numberOfSpellLists number?

---@class ClassesAndSubclassesMutator : Mutator
---@field values ClassesConditionalGroup[]


---@type {[Guid] : Guid[]}
local classesAndSubclasses = {}

---@type {[Guid]: string}
local translationMap = {}

local function initClassIndex()
	if not next(classesAndSubclasses) then
		for _, classId in pairs(Ext.StaticData.GetAll("ClassDescription")) do
			---@type ResourceClassDescription
			local class = Ext.StaticData.Get(classId, "ClassDescription")

			if class.ParentGuid and class.ParentGuid ~= "00000000-0000-0000-0000-000000000000" and class.ParentGuid ~= "" then
				if not classesAndSubclasses[class.ParentGuid] then
					classesAndSubclasses[class.ParentGuid] = {}
				end

				table.insert(classesAndSubclasses[class.ParentGuid], classId)
			elseif not classesAndSubclasses[classId] then
				classesAndSubclasses[classId] = {}
			end

			local name = class.DisplayName:Get() or class.Name

			translationMap[classId] = name
		end
	end
end

---@param mutator ClassesAndSubclassesMutator
function ClassesAndSubclassesMutator:renderMutator(parent, mutator)
	initClassIndex()
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

				local name = translationMap[classId]
				---@type ResourceClassDescription
				local class = Ext.StaticData.Get(classId, "ClassDescription")

				if translationMap[class.ParentGuid] then
					name = translationMap[class.ParentGuid] .. " - " .. name
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
				levelPercentageInput.ItemWidth = 40
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

			for classId, subclasses in TableUtils:OrderedPairs(classesAndSubclasses, function(key, value)
				return translationMap[key]
			end) do
				if next(subclasses) then
					---@type ExtuiMenu
					local menu = popup:AddMenu(translationMap[classId])
					menu.Disabled = (classConditionalGroup.classIds and classConditionalGroup.classIds[classId]) ~= nil

					menu:AddSelectable(translationMap[classId]).OnClick = function()
						classConditionalGroup.classIds = classConditionalGroup.classIds or {}
						classConditionalGroup.classIds[classId] = TableUtils:CountElements(classConditionalGroup.classIds) == 0 and 100 or 0

						self:renderMutator(parent, mutator)
					end

					for _, subclassId in TableUtils:OrderedPairs(subclasses, function(key, value)
						return translationMap[value]
					end) do
						if not menu.Disabled then
							menu.Disabled = (classConditionalGroup.classIds and classConditionalGroup.classIds[subclassId]) ~= nil
						end

						menu:AddSelectable(translationMap[subclassId]).OnClick = function()
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
		spellListNumberInput.ItemWidth = 40
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
				return MutationConfigurationProxy.spellLists[value].name
			end) do
				local delete = Styler:ImageButton(conditionalCell:AddImageButton("delete" .. spellListId, "ico_red_x", { 16, 16 }))
				delete.OnClick = function()
					for x = i, TableUtils:CountElements(classConditionalGroup.spellListDependencies) do
						classConditionalGroup.spellListDependencies[x] = classConditionalGroup.spellListDependencies[x + 1]
					end

					self:renderMutator(parent, mutator)
				end

				local spellList = MutationConfigurationProxy.spellLists[spellListId]
				local spellListLink = conditionalCell:AddTextLink(spellList.name .. (spellList.modId and string.format(" (%s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
				spellListLink.IDContext = spellListId
				spellListLink.SameLine = true
				spellListLink.OnClick = function()
					SpellListDesigner:buildSpellDesignerWindow(spellListId)
				end
			end
		end

		conditionalCell:AddButton("Add Spell List").OnClick = function()
			Helpers:KillChildren(popup)
			popup:Open()

			for spellListId, spellList in TableUtils:OrderedPairs(MutationConfigurationProxy.spellLists, function(key, value)
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
	end

	parent:AddButton("Add Class Group").OnClick = function()
		table.insert(mutator.values, {})
		self:renderMutator(parent, mutator)
	end
end

function ClassesAndSubclassesMutator:undoMutator(entity, entityVar)
	if entityVar.originalValues[self.name] then
		entity.Classes.Classes = {}
		for _, classDef in pairs(entityVar.originalValues[self.name]) do
			---@cast classDef ClassInfo
			entity.Classes.Classes[#entity.Classes.Classes + 1] = {
				ClassUUID = classDef.ClassUUID,
				SubClassUUID = classDef.SubClassUUID,
				Level = classDef.Level
			}
		end
		entity:Replicate("Classes")

		if Logger:IsLogLevelEnabled(Logger.PrintTypes.TRACE) then
			Logger:BasicTrace("Reverted to %s", Ext.Json.Stringify(entityVar.originalValues[self.name]))
		end
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

	for _, classesMutator in ipairs(classesMutators) do
		for _, classConditonal in ipairs(classesMutator.values) do
			if classConditonal.numberOfSpellLists and classConditonal.numberOfSpellLists > 0 then
				if classConditonal.spellListDependencies and next(classConditonal.spellListDependencies) then
					local numberMatched = 0
					if entityVar.appliedMutators[SpellListMutator.name] and entityVar.appliedMutators[SpellListMutator.name].appliedLists then
						for _, appliedSpellListId in pairs(entityVar.appliedMutators[SpellListMutator.name].appliedLists) do
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
						Ext.Json.Stringify(classConditonal))
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
		entityVar.originalValues[self.name] = Ext.Types.Serialize(entity.Classes.Classes)

		entity.Classes.Classes = {}

		local classesLeft = TableUtils:CountElements(classGroup.classIds)
		local classLevelsLeft = entity.AvailableLevel.Level
		for classId, levelPercentage in pairs(classGroup.classIds) do
			---@type ResourceClassDescription
			local class = Ext.StaticData.Get(classId, "ClassDescription")
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

		entity:Replicate("Classes")
	else
		Logger:BasicDebug("No class groups were chosen - finishing early")
	end
end
