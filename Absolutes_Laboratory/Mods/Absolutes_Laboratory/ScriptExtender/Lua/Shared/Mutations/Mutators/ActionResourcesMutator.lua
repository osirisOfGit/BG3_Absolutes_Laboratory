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

	parent:AddSeparatorText("General (All Entities)"):SetStyle("SeparatorTextAlign", 0.2, 0.5)
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

	local classSep = parent:AddSeparatorText("Class-Specific ( ? )")
	classSep:SetStyle("SeparatorTextAlign", 0.2, 0.5)
	classSep:Tooltip():AddText(
		"\t Resources defined here will override their General counterparts above if applicable. Later groups will override earlier groups in the list if both are applicable.")

	local classParentTable = parent:AddTable("classParent", 2)
	classParentTable:AddColumn("", "WidthFixed")
	classParentTable.BordersInnerH = true

	ClassesAndSubclassesMutator:initClassIndex()

	local function buildClasses()
		Helpers:KillChildren(classParentTable)

		for i, classDependentActionResources in TableUtils:OrderedPairs(mutator.values.classDependent) do
			local row = classParentTable:AddRow()
			local deleteButton = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. i, "ico_red_x", { 16, 16 }))
			deleteButton.OnClick = function()
				mutator.values.classDependent[i].delete = true
				TableUtils:ReindexNumericTable(mutator.values.classDependent)
				buildClasses()
			end

			local cell = row:AddCell()
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

---@param mutator ActionResourcesMutator
function ActionResourcesMutator:handleDependencies(export, mutator, removeMissingDependencies)
	local resourcesIndex = Ext.StaticData.GetSources("ActionResource")

	local function record(actionResourceConfig)
		local resource = Ext.StaticData.Get(actionResourceConfig.resourceId, "ActionResource")
		if not resource then
			return false
		elseif not removeMissingDependencies then
			local resourceSource = TableUtils:IndexOf(resourcesIndex, function(value)
				return TableUtils:IndexOf(value, actionResourceConfig.resourceId) ~= nil
			end)

			if resourceSource then
				mutator.modDependencies = mutator.modDependencies or {}
				if not mutator.modDependencies[resourceSource] then
					local name, author, version = Helpers:BuildModFields(resourceSource)
					if author == "Larian" then
						return true
					end
					mutator.modDependencies[resourceSource] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = resourceSource,
						packagedItems = {}
					}
				end

				mutator.modDependencies[resourceSource].packagedItems[actionResourceConfig.resourceId] =
					resource.DisplayName:Get() ~= ""
					and resource.DisplayName:Get()
					or resource.Name
			end
		end
	end

	if mutator.values.general then
		for i, actionResourceConfig in pairs(mutator.values.general) do
			if not record(actionResourceConfig) then
				mutator.values.general[i].delete = true
			end
		end
		TableUtils:ReindexNumericTable(mutator.values.general)
	end

	if mutator.values.classDependent then
		local classesIndex = Ext.StaticData.GetSources("ClassDescription")

		for co, classConfig in pairs(mutator.values.classDependent) do
			for ci, classId in pairs(classConfig.requiresClasses) do
				---@type ResourceClassDescription
				local class = Ext.StaticData.Get(classId, "ClassDescription")
				if not class then
					classConfig.requiresClasses[ci] = nil
					if not classConfig.requiresClasses() then
						mutator.values.classDependent[co].delete = true
						goto continueClass
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
			TableUtils:ReindexNumericTable(classConfig.requiresClasses)

			for i, resourceConfig in TableUtils:OrderedPairs(classConfig.actionResources) do
				if not record(resourceConfig) then
					classConfig.actionResources[i].delete = true
					if (not classConfig.__real and not next(classConfig.actionResources)) or (classConfig.__real and not classConfig.actionResources()) then
						mutator.values.classDependent[co].delete = true
						goto continueClass
					end
				end
			end
			TableUtils:ReindexNumericTable(classConfig.actionResources)
			::continueClass::
		end
		TableUtils:ReindexNumericTable(mutator.values.classDependent)
	end
end

-- Quantity then level
-- "Boosts" "ActionResource(Interrupt_MAG_Counterspell, 1, 0)"
function ActionResourcesMutator:applyMutator(entity, entityVar)
	local actionResourceMutators = entityVar.appliedMutators[self.name]
	if not actionResourceMutators[1] then
		actionResourceMutators = { actionResourceMutators }
	end
	---@cast actionResourceMutators ActionResourcesMutator[]

	---@type {[Guid]: ActionResourceConfig}
	local resourcePool = {}

	for _, actionResourceMutator in ipairs(actionResourceMutators) do
		if actionResourceMutator.values.general then
			for _, generalConfig in ipairs(actionResourceMutator.values.general) do
				if entity.EocLevel.Level >= generalConfig.initialEntityOrClassLevel then
					resourcePool[generalConfig.resourceId] = generalConfig
				end
			end
		end

		if actionResourceMutator.values.classDependent then
			for _, classConfig in ipairs(actionResourceMutator.values.classDependent) do
				---@type {[Guid]: ActionResourceConfig}
				local config = {}
				for _, classId in pairs(classConfig.requiresClasses) do
					for _, classOnEntity in pairs(entity.Classes.Classes) do
						if classOnEntity.ClassUUID == classId or classOnEntity.SubClassUUID == classId then
							Logger:BasicDebug("Class %s is present on the entity - adding resources", Ext.StaticData.Get(classId, "ClassDescription").Name)
							for _, resourceConfig in ipairs(classConfig.actionResources) do
								if classOnEntity.Level >= resourceConfig.initialEntityOrClassLevel then
									if not config[resourceConfig.resourceId] then
										resourceConfig.totalClassLevel = classOnEntity.Level
										config[resourceConfig.resourceId] = resourceConfig
									else
										config[resourceConfig.resourceId].totalClassLevel = config[resourceConfig.resourceId].totalClassLevel + classOnEntity.Level
									end
								end
							end
						end
					end
				end
				for resource, resourceConfig in pairs(config) do
					resourcePool[resource] = resourceConfig
				end
			end
		end
	end

	Logger:BasicTrace("Final resource configs: %s", resourcePool)

	local boostString = ""
	local template = "ActionResource(%s,%d,%d);"

	for resourceId, config in pairs(resourcePool) do
		---@type ResourceActionResource
		local resource = Ext.StaticData.Get(resourceId, "ActionResource")

		local amount = config.amount
		if config.everyXLevels then
			local iterationCounter = 0
			for _ = config.initialEntityOrClassLevel, (config.totalClassLevel or entity.EocLevel.Level), config.everyXLevels do
				iterationCounter = iterationCounter + 1

				local amountToReduce = ((config.reduceByYEachIteration or 0) * iterationCounter)
				-- Rounding to the nearest whole number, prioritizing flooring
				amount = amount + math.floor((config.amount - amountToReduce) + 0.49)
				Logger:BasicTrace("Adding %s for %s", math.floor((config.amount - amountToReduce) + 0.49), resource.Name)
			end
		end

		if amount > 0 then
			boostString = boostString .. string.format(template, resource.Name, amount, config.resourceLevel or 0)
		else
			Logger:BasicDebug("Not adding resource %s to the boosts as the final amount is %s", resource.Name, amount)
		end
	end
	Logger:BasicDebug("Final boosts are %s", boostString)

	local statName = "ABSOLUTES_LAB_RESOURCE_BOOST_" .. string.sub(entity.Uuid.EntityUuid, #entity.Uuid.EntityUuid - 11)
	if boostString ~= "" then
		if not Ext.Stats.Get(statName) then
			Logger:BasicDebug("Creating Resource Stat %s", statName)
			---@type StatusData
			local newStat = Ext.Stats.Create(statName, "StatusData", "ABSOLUTES_LAB_RESOURCE_BOOST")
			newStat.Boosts = boostString
			newStat:Sync()
		else
			Logger:BasicDebug("Updating Resource Stat %s", statName)
			---@type StatusData
			local stat = Ext.Stats.Get(statName)
			if stat.Boosts ~= boostString then
				stat.Boosts = boostString
				stat:Sync()
			end
		end

		entityVar.originalValues[self.name] = boostString

		Osi.ApplyStatus(entity.Uuid.EntityUuid, statName, -1, 1, "Lab")
	else
		Logger:BasicDebug("Removed status %s as there were no resource boosts to apply", statName)
		Osi.RemoveStatus(entity.Uuid.EntityUuid, statName)
	end
end

function ActionResourcesMutator:undoMutator(entity, entityVar, primedEntityVar, reprocessTransient)
	if not primedEntityVar or not primedEntityVar.appliedMutators[self.name] then
		local statName = "ABSOLUTES_LAB_RESOURCE_BOOST_" .. string.sub(entity.Uuid.EntityUuid, #entity.Uuid.EntityUuid - 11)
		if not Ext.Stats.Get(statName) then
			Logger:BasicDebug("Creating Resource Stat %s for proper removal", statName)
			---@type StatusData
			local newStat = Ext.Stats.Create(statName, "StatusData", "ABSOLUTES_LAB_RESOURCE_BOOST")
			newStat.Boosts = entityVar.originalValues[self.name] or ""
			newStat:Sync()
		end

		Logger:BasicDebug("Removed status %s as no resource mutator will be executed for this entity", statName)
		Osi.RemoveStatus(entity.Uuid.EntityUuid, statName)
	else
		Logger:BasicDebug("Skipping undoing as there is an action resource mutator primed for this entity")
	end
end
