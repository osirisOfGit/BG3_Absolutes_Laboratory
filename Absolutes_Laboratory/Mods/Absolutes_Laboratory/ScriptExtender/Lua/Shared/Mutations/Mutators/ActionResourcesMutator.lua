ActionResourcesMutator = MutatorInterface:new("Action Resources")

function ActionResourcesMutator:priority()
	return self:recordPriority(ClassesAndSubclassesMutator:priority() + 1)
end

function ActionResourcesMutator:canBeAdditive()
	return true
end

---@class ActionResourceConfig
---@field resourceId Guid
---@field resourceLevel number?
---@field amount number
---@field initialEntityOrClassLevel number
---@field everyXLevels number?
---@field reduceByYEachIteration number?

---@class ClassDependentActionResources
---@field requiresClasses Guid[]
---@field actionResources ActionResourceConfig[]

---@class ActionResourceMutatorValues
---@field general ActionResourceConfig[]?
---@field classDependent ClassDependentActionResources[]?

---@class ActionResourcesMutator : Mutator
---@field values ActionResourceMutatorValues

---@param mutator ActionResourcesMutator
function ActionResourcesMutator:renderMutator(parent, mutator)
	Helpers:KillChildren(parent)
	mutator.values = mutator.values or {}

	local popup = parent:AddPopup("")

	parent:AddSeparatorText("General (All Entities)").Font = "Large"
	local generalGroupTable = parent:AddTable("general", 7)
	generalGroupTable:AddColumn("", "WidthFixed")
	generalGroupTable:AddColumn("", "WidthFixed")
	generalGroupTable.SizingStretchSame = true

	---@param parentTable ExtuiTable
	---@param config ActionResourceConfig[]
	local function buildGeneral(parentTable, config)
		Helpers:KillChildren(parentTable)

		local headerRow = parentTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell()
		headerRow:AddCell():AddText("Resource")
		headerRow:AddCell():AddText("Level ( ? )"):Tooltip():AddText("\t If the Resource supports it, i.e. for Spell Slots, this could be level 1 or level 3")
		headerRow:AddCell():AddText("Base Amount ( ? )"):Tooltip():AddText("\t What amount of the resource to give at the specified Entity Level, and every x levels after")
		headerRow:AddCell():AddText("Base Level ( ? )"):Tooltip():AddText("\t Minimum level of the Entity to receive the Base Amount and begin X level logic")
		headerRow:AddCell():AddText("Every X Level ( ? )"):Tooltip():AddText(
			"\t Add the Base amount to the entity every specified level after the Base. If not set, will only be given once")
		headerRow:AddCell():AddText("Reduce By ( ? )"):Tooltip():AddText([[
	How much to reduce the Base amount every time the X Level logic triggers - will apply on first iteration after the Base amount is assigned and compound every iteration after
Decimal values will result in the nearest whole number, prioritizing rounding down.
i.e if Base is 5 and this is 2, the next value given will be 3 - if this is 0.3, it will be 5, then 4, 4, 3, 3, etc]])

		for i, actionResourceConfig in TableUtils:OrderedPairs(config or {}) do
			local row = parentTable:AddRow()

			local deleteConfig = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. actionResourceConfig.resourceId, "ico_red_x", { 16, 16 }))
			deleteConfig.OnClick = function()
				config[i].delete = true
				TableUtils:ReindexNumericTable(config)

				buildGeneral(parentTable, config)
			end

			---@type ResourceActionResource
			local resource = Ext.StaticData.Get(actionResourceConfig.resourceId, "ActionResource")
			Styler:HyperlinkText(row:AddCell(), resource.DisplayName:Get() or resource.Name, function(parent)
				ResourceManager:RenderDisplayWindow(resource, parent)
			end)

			for _, inputType in ipairs({ "resourceLevel", "amount", "initialEntityOrClassLevel", "everyXLevels" }) do
				local input = row:AddCell():AddInputInt("", actionResourceConfig[inputType])
				input.ItemWidth = 80
				if inputType == "amount" and (resource.MaxValue > 0) then
					input:Tooltip():AddText(string.format("\t Max Value is %s", resource.MaxValue))
				end

				if inputType ~= "resourceLevel" or resource.MaxLevel > 0 then
					if inputType == "everyXLevels" then
						input.ParseEmptyRefVal = true
						input.DisplayEmptyRefVal = true
					end
					input.OnChange = function()
						if input.Value[1] <= 0
							or (inputType == "amount" and (resource.MaxValue > 0 and input.Value[1] > resource.MaxValue))
						then
							if inputType == "everyXLevels" then
								actionResourceConfig[inputType] = nil
								input.Value = { 0, 0, 0, 0 }
							else
								local currVal = actionResourceConfig[inputType]
								input.Value = { currVal, currVal, currVal, currVal }
							end
						else
							actionResourceConfig[inputType] = input.Value[1]
						end

						if inputType == "everyXLevels" then
							buildGeneral(parentTable, config) -- Otherwise it unfocuses every field and that's just annoying
						end
					end
				else
					input.Disabled = true
				end
			end

			if actionResourceConfig.everyXLevels then
				local input = row:AddCell():AddInputScalar("", actionResourceConfig.reduceByYEachIteration)
				input.ItemWidth = 80
				input.ParseEmptyRefVal = true
				input.DisplayEmptyRefVal = true

				input.OnChange = function()
					if input.Value[1] <= 0 then
						actionResourceConfig.reduceByYEachIteration = nil
						input.Value = { 0, 0, 0, 0 }
					else
						actionResourceConfig.reduceByYEachIteration = input.Value[1]
					end
				end
			end
		end
	end
	buildGeneral(generalGroupTable, mutator.values.general)

	---@param config ActionResourceConfig[]
	---@param onSelectFunc fun()
	local function resourcePopup(config, onSelectFunc)
		Helpers:KillChildren(popup)
		local popWin = popup:AddChildWindow("")
		popup:Open()
		for _, actionResourceId in TableUtils:OrderedPairs(Ext.StaticData.GetAll("ActionResource"), function(key, value)
			return Ext.StaticData.Get(value, "ActionResource").Name
		end, function(key, value)
			return not Ext.StaticData.Get(value, "ActionResource").IsHidden
		end) do
			local existingIndex = TableUtils:IndexOf(config, function(value)
				return value.resourceId == actionResourceId
			end)

			---@type ResourceActionResource
			local actionResource = Ext.StaticData.Get(actionResourceId, "ActionResource")
			---@type ExtuiSelectable
			local select = popWin:AddSelectable(string.format("%s (%s)", actionResource.Name, actionResource.DisplayName:Get()), "DontClosePopups")
			select.Selected = actionResource.MaxLevel == 0 and existingIndex ~= nil

			Styler:HyperlinkRenderable(select, actionResource.Name, "Shift", true, nil, function(parent)
				ResourceManager:RenderDisplayWindow(actionResource, parent)
			end)

			select.OnClick = function()
				-- Value is flipped by the time this fires
				if not select.Selected then
					config[TableUtils:IndexOf(config, function(value)
						return value.resourceId == actionResourceId
					end)].delete = true

					TableUtils:ReindexNumericTable(config)

					onSelectFunc()
				else
					table.insert(config, {
						resourceId = actionResourceId,
						resourceLevel = actionResource.MaxLevel,
						amount = actionResource.MaxValue,
						initialEntityOrClassLevel = 1
					} --[[@as ActionResourceConfig]])

					if actionResource.MaxLevel > 0 then
						select.Selected = false
					end
				end
				onSelectFunc()
			end
		end
	end

	parent:AddButton("Add General Resource Rule").OnClick = function()
		mutator.values.general = mutator.values.general or {}
		resourcePopup(mutator.values.general, function() buildGeneral(generalGroupTable, mutator.values.general) end)
	end

	local classSep = parent:AddSeparatorText("Class-Specific")
	classSep.Font = "Large"
	classSep:Tooltip():AddText("\t Resources defined here will override their General counterparts above if applicable")

	local classParentTable = parent:AddTable("classParent", 1)
	classParentTable.BordersInnerH = true

	ClassesAndSubclassesMutator:initClassIndex()

	local function buildClasses()
		Helpers:KillChildren(classParentTable)

		for i, classDependentActionResources in TableUtils:OrderedPairs(mutator.values.classDependent) do
			local cell = classParentTable:AddRow():AddCell()
			cell:AddText("Group " .. i).Font = "Large"

			for c, classId in TableUtils:OrderedPairs(classDependentActionResources.requiresClasses or {}) do
				local name = ClassesAndSubclassesMutator.translationMap[classId]
				---@type ResourceClassDescription
				local class = Ext.StaticData.Get(classId, "ClassDescription")

				if ClassesAndSubclassesMutator.translationMap[class.ParentGuid] then
					name = ClassesAndSubclassesMutator.translationMap[class.ParentGuid] .. " - " .. name
				end

				local classGroup = cell:AddGroup(classId)
				classGroup.SameLine = (c - 1) % 3 ~= 0

				local deleteClass = Styler:ImageButton(classGroup:AddImageButton("delete" .. classId, "ico_red_x", { 16, 16 }))
				deleteClass.OnClick = function()
					classDependentActionResources.requiresClasses[i] = nil
					TableUtils:ReindexNumericTable(classDependentActionResources.requiresClasses)
					buildClasses()
				end

				Styler:HyperlinkText(classGroup, name, function(parent)
					ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(classId, "ClassDescription"), parent)
				end).SameLine = true
			end
			local classButton = cell:AddButton("Add New (Sub)Class")
			classButton.Font = "Small"
			classButton.OnClick = function()
				Helpers:KillChildren(popup)
				popup:Open()

				for classId, subclasses in TableUtils:OrderedPairs(ClassesAndSubclassesMutator.classesAndSubclasses, function(key, value)
					return ClassesAndSubclassesMutator.translationMap[key]
				end) do
					if next(subclasses) then
						---@type ExtuiMenu
						local menu = popup:AddMenu(ClassesAndSubclassesMutator.translationMap[classId])
						menu.Disabled = TableUtils:IndexOf(classDependentActionResources.requiresClasses, classId) ~= nil

						menu:AddSelectable(ClassesAndSubclassesMutator.translationMap[classId]).OnClick = function()
							classDependentActionResources.requiresClasses = classDependentActionResources.requiresClasses or {}
							table.insert(classDependentActionResources.requiresClasses, classId)

							buildClasses()
						end

						for _, subclassId in TableUtils:OrderedPairs(subclasses, function(key, value)
							return ClassesAndSubclassesMutator.translationMap[value]
						end) do
							---@type ExtuiSelectable
							local select = menu:AddSelectable(ClassesAndSubclassesMutator.translationMap[subclassId])
							select.Selected = TableUtils:IndexOf(classDependentActionResources.requiresClasses, subclassId) ~= nil

							select.OnClick = function()
								if not select.Selected then
									classDependentActionResources.requiresClasses[TableUtils:IndexOf(classDependentActionResources.requiresClasses, subclassId)] = nil
									TableUtils:ReindexNumericTable(classDependentActionResources.requiresClasses)
								else
									classDependentActionResources.requiresClasses = classDependentActionResources.requiresClasses or {}
									table.insert(classDependentActionResources.requiresClasses, subclassId)
								end

								buildClasses()
							end
						end

						if menu.Disabled then
							menu:SetStyle("Alpha", 0.5)
						end
					end
				end
			end

			local classGroupTable = cell:AddTable("classGroup" .. i, 7)
			classGroupTable:AddColumn("", "WidthFixed")
			classGroupTable:AddColumn("", "WidthFixed")
			classGroupTable.SizingStretchSame = true
			buildGeneral(classGroupTable, classDependentActionResources.actionResources)
			cell:AddButton("Add Resource Rule").OnClick = function()
				classDependentActionResources.actionResources = classDependentActionResources.actionResources or {}
				resourcePopup(classDependentActionResources.actionResources, function() buildClasses() end)
			end
		end
	end

	buildClasses()

	parent:AddButton("Add Class(es) Group").OnClick = function()
		mutator.values.classDependent = mutator.values.classDependent or {}
		table.insert(mutator.values.classDependent, {})
		buildClasses()
	end
end

function ActionResourcesMutator:applyMutator(entity, entityVar)

end

function ActionResourcesMutator:undoMutator(entity, entityVar, primedEntityVar, reprocessTransient)

end
