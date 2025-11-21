---@class ActionResourcesMutatorImpl : MutatorInterface
ActionResourcesMutator = MutatorInterface:new("Action Resources")
ActionResourcesMutator.affectedComponents = {
	"BoostsContainer"
}
function ActionResourcesMutator:priority()
	return self:recordPriority(ClassesAndSubclassesMutator:priority() + 1)
end

function ActionResourcesMutator:canBeAdditive()
	return true
end

---@class ActionResourcesConfig
---@field resourceId Guid
---@field resourceLevel number
---@field levelMap number[]
---@field additiveCurve boolean

---@class ClassDependentActionResources
---@field requiresClasses Guid[]
---@field actionResources (ActionResourcesConfig)[]

---@class ActionResourceMutatorValues
---@field general (ActionResourcesConfig)[]?
---@field classDependent ClassDependentActionResources[]?

---@class ActionResourcesMutator : Mutator
---@field values ActionResourceMutatorValues
---@field newVersion boolean

---@param mutator ActionResourcesMutator
function ActionResourcesMutator:renderMutator(parent, mutator)
	Helpers:KillChildren(parent)
	mutator.values = mutator.values or {
		general = {}
	}

	mutator.newVersion = true

	local savedPresetSpreads = ConfigurationStructure.config.mutations.settings.actionResourceDistributionPresets

	local popup = parent:AddPopup("")

	Styler:ScaledFont(parent:AddSeparatorText("General (All Entities)"), "Large"):SetStyle("SeparatorTextAlign", 0.5)

	local generalGroup = parent:AddGroup("general")

	---@param group ExtuiGroup
	---@param config ActionResourcesConfig[]
	local function buildGeneral(group, config)
		Helpers:KillChildren(group)

		local displayTable = group:AddTable("displayTable", 3)
		displayTable.NoSavedSettings = true
		displayTable.Borders = true
		local displayTableRow = displayTable:AddRow()

		for i, actionResourceConfig in TableUtils:OrderedPairs(config or {}, function(key, value)
			---@type ResourceActionResource?
			local resource = Ext.StaticData.Get(value.resourceId, "ActionResource")

			return (resource and resource.Name or "") .. tostring(value.resourceLevel)
		end) do
			---@type ResourceActionResource?
			local resource = Ext.StaticData.Get(actionResourceConfig.resourceId, "ActionResource")
			if not resource then
				Logger:BasicWarning("Action Resource %s doesn't exist, removing from config", actionResourceConfig.resourceId)
				actionResourceConfig.delete = true
				config[i] = nil
				TableUtils:ReindexNumericTable(config)
				buildGeneral(group, config)
				return
			else
				local resourceParent = displayTableRow:AddCell()
				Styler:ScaledFont(
					resourceParent:AddSeparatorText(string.format("%s (%s)%s",
						resource.Name,
						resource.DisplayName:Get(),
						actionResourceConfig.resourceLevel > 0 and (" - Level " .. actionResourceConfig.resourceLevel) or "")),
					"Big")

				local delete = Styler:ImageButton(resourceParent:AddImageButton("delete", "ico_red_x", { 16, 16 }))
				delete.OnClick = function()
					actionResourceConfig.delete = true
					TableUtils:ReindexNumericTable(config)
					buildGeneral(group, config)
				end

				Styler:MiddleAlignedColumnLayout(resourceParent, function(ele)
					Styler:DualToggleButton(ele, "Distribution", "Static Addition", false, function(swap)
						if swap then
							actionResourceConfig.additiveCurve = not actionResourceConfig.additiveCurve
						end
						return actionResourceConfig.additiveCurve
					end)
					local helpTooltip = ele:AddText("( ? )")
					helpTooltip.SameLine = true
					helpTooltip:Tooltip():AddText([[
	If set to Distribution, the Levels do not need to be consecutive - for example, you can set level 2 to give 3 of the specified resource, and level 5 to give 1 of the resource.
This will cause Lab to give the entity 3 of that resource every level for levels 2-4, and 1 of that resource every level from level 5 onwards. Setting to 0 will not add a resource for the applicable levels.

If set to 'Static Assignment', Lab will add exactly the amount specified at exactly the levels specified.

If Level 1 is set, Lab will hardset the existing resource on the entity (if applicable) to that value regardless of which option is selected, serving as the new base for all subsequent additions.]])
				end).SameLine = true

				local resourceDistributionTable = resourceParent:AddTable(actionResourceConfig.resourceId, 3)
				resourceDistributionTable:AddColumn("", "WidthFixed")

				local headers = resourceDistributionTable:AddRow()
				headers.Headers = true
				headers:AddCell()
				headers:AddCell():AddText("Level")

				headers:AddCell():AddText("# Of Resource")

				local enableDelete = false
				for level, numberOfResource in TableUtils:OrderedPairs(actionResourceConfig.levelMap) do
					local row = resourceDistributionTable:AddRow()
					if not enableDelete then
						row:AddCell()
						enableDelete = true
					else
						local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. level, "ico_red_x", { 16, 16 }))
						delete.OnClick = function()
							actionResourceConfig.levelMap[level] = nil
							row:Destroy()
						end
					end

					---@param input ExtuiInputInt
					row:AddCell():AddInputInt("", level).OnDeactivate = function(input)
						if not actionResourceConfig.levelMap[input.Value[1]] then
							actionResourceConfig.levelMap[input.Value[1]] = numberOfResource
							actionResourceConfig.levelMap[level] = nil
							buildGeneral(group, config)
						else
							input.Value = { level, level, level, level }
						end
					end

					---@param input ExtuiInputInt
					row:AddCell():AddInputInt("", numberOfResource).OnDeactivate = function(input)
						actionResourceConfig.levelMap[level] = input.Value[1]
					end
				end

				resourceParent:AddButton("+").OnClick = function()
					Helpers:KillChildren(popup)
					popup:Open()

					local add = popup:AddButton("Add Level")
					local input = popup:AddInputInt("", 0)
					input.SameLine = true

					local errorText = popup:AddText("Choose a level that isn't already specified")
					errorText:SetColor("Text", Styler:ConvertRGBAToIMGUI({ 255, 100, 100, 0.7 }))
					errorText.Visible = false

					add.OnClick = function()
						if actionResourceConfig.levelMap[input.Value[1]] then
							errorText.Visible = true
						else
							actionResourceConfig.levelMap[input.Value[1]] = 2
							buildGeneral(group, config)
						end
					end
				end

				local loadButton = resourceParent:AddButton("L")
				loadButton:Tooltip():AddText("\t Load a saved preset")
				loadButton.SameLine = true
				loadButton.OnClick = function()
					Helpers:KillChildren(popup)
					popup:Open()

					for presetName, spread in TableUtils:OrderedPairs(savedPresetSpreads) do
						if presetName ~= "Default" then
							local delete = Styler:ImageButton(popup:AddImageButton("delete" .. presetName, "ico_red_x", { 16, 16 }))
							delete.OnClick = function()
								savedPresetSpreads[presetName].delete = true
								loadButton:OnClick()
							end
						end
						local loadPreset = popup:AddSelectable(presetName)
						loadPreset.SameLine = presetName ~= "Default"
						loadPreset.OnClick = function()
							actionResourceConfig.levelMap.delete = true
							actionResourceConfig.levelMap = TableUtils:DeeplyCopyTable(spread._real)
							buildGeneral(group, config)
						end
					end
				end

				local saveButton = resourceParent:AddButton("S")
				saveButton:Tooltip():AddText("\t Save the current table to a new or existing preset")
				saveButton.SameLine = true
				saveButton.OnClick = function()
					Helpers:KillChildren(popup)
					popup:Open()

					local nameInput = popup:AddInputText("")
					nameInput.Hint = "New or Existing Preset Name"

					local overrideConfirmation = popup:AddText("Are you sure you want to override %s?")
					overrideConfirmation.Visible = false
					overrideConfirmation:SetColor("Text", { 1, 0.2, 0, 1 })

					local submitButton = popup:AddButton("Save")
					submitButton.OnClick = function()
						if overrideConfirmation.Visible or not savedPresetSpreads[nameInput.Text] then
							if savedPresetSpreads[nameInput.Text] then
								savedPresetSpreads[nameInput.Text].delete = true
							end
							savedPresetSpreads[nameInput.Text] = TableUtils:DeeplyCopyTable(actionResourceConfig.levelMap._real)
							buildGeneral(group, config)
						else
							overrideConfirmation.Label = string.format("Are you sure you want to override %s?", nameInput.Text)
							overrideConfirmation.Visible = true
						end
					end
				end
			end
		end

		displayTable.Columns = math.max(1, math.min(3, #displayTableRow.Children))
	end

	buildGeneral(generalGroup, mutator.values.general)

	---@param config ActionResourcesConfig[]
	---@param onSelectFunc fun()
	local function resourcePopup(config, onSelectFunc)
		Helpers:KillChildren(popup)
		popup:Open()

		---@param select ExtuiSelectable
		---@param actionResourceId string
		local function chooseResourceFunction(select, actionResourceId)
			-- Value is flipped by the time this fires
			if not select.Selected then
				local index = TableUtils:IndexOf(config, function(value)
					return value.resourceId == actionResourceId and value.resourceLevel == select.UserData
				end)
				config[index].delete = true

				TableUtils:ReindexNumericTable(config)
			else
				table.insert(config, {
					resourceId = actionResourceId,
					resourceLevel = tonumber(select.UserData),
					additiveCurve = true,
					levelMap = TableUtils:DeeplyCopyTable(savedPresetSpreads["Default"]._real)
				} --[[@as ActionResourcesConfig]])
			end
			onSelectFunc()
		end

		for _, actionResourceId in TableUtils:OrderedPairs(Ext.StaticData.GetAll("ActionResource"), function(key, value)
			return Ext.StaticData.Get(value, "ActionResource").Name
		end) do
			---@type ResourceActionResource
			local actionResource = Ext.StaticData.Get(actionResourceId, "ActionResource")

			if actionResource.MaxLevel > 0 then
				---@type ExtuiMenu
				local menu = popup:AddMenu(string.format("%s (%s)", actionResource.Name, actionResource.DisplayName:Get()))
				for i = 1, actionResource.MaxLevel do
					local existingIndex = TableUtils:IndexOf(config, function(value)
						return value.resourceId == actionResourceId and value.resourceLevel == i
					end)
					---@type ExtuiSelectable
					local select = menu:AddSelectable(string.format("%s - Level %d", actionResource.Name, i), "DontClosePopups")
					select.UserData = i
					select.Selected = existingIndex ~= nil

					Styler:HyperlinkRenderable(select, actionResource.Name, "Alt", true, nil, function(parent)
						ResourceManager:RenderDisplayWindow(actionResource, parent)
					end)
					select.OnClick = function(select)
						chooseResourceFunction(select, actionResourceId)
					end
				end
			else
				local existingIndex = TableUtils:IndexOf(config, function(value)
					return value.resourceId == actionResourceId
				end)
				---@type ExtuiSelectable
				local select = popup:AddSelectable(string.format("%s (%s)", actionResource.Name, actionResource.DisplayName:Get()), "DontClosePopups")
				select.UserData = 0
				select.Selected = existingIndex ~= nil

				Styler:HyperlinkRenderable(select, actionResource.Name, "Alt", true, nil, function(parent)
					ResourceManager:RenderDisplayWindow(actionResource, parent)
				end)
				select.OnClick = function(select)
					chooseResourceFunction(select, actionResourceId)
				end
			end
		end
	end

	parent:AddButton("Add General Resource Rule").OnClick = function()
		mutator.values.general = mutator.values.general or {}
		resourcePopup(mutator.values.general, function() buildGeneral(generalGroup, mutator.values.general) end)
	end

	local classSep = parent:AddSeparatorText("Class-Specific ( ? )")
	Styler:ScaledFont(classSep, "Large")
	classSep:SetStyle("SeparatorTextAlign", 0.5)
	classSep:Tooltip():AddText(
		"\t Resources defined here will override their General counterparts above if applicable. Later groups will override earlier groups in the list if both are applicable.")

	local classParentTable = parent:AddTable("classParent", 2)
	classParentTable:AddColumn("", "WidthFixed")
	classParentTable.BordersInnerH = true

	ClassesAndSubclassesMutator:initClassIndex()

	local function buildClasses()
		Helpers:KillChildren(classParentTable)

		for i, classDependentActionResources in TableUtils:OrderedPairs(mutator.values.classDependent or {}) do
			local row = classParentTable:AddRow()
			local deleteButton = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. i, "ico_red_x", { 16, 16 }))
			deleteButton.OnClick = function()
				mutator.values.classDependent[i].delete = true
				TableUtils:ReindexNumericTable(mutator.values.classDependent)
				buildClasses()
			end

			local cell = row:AddCell():AddCollapsingHeader("Group " .. i)
			cell.DefaultOpen = true

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
					classDependentActionResources.requiresClasses[c] = nil
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

						menu:AddSelectable(ClassesAndSubclassesMutator.translationMap[classId], "DontClosePopups").OnClick = function()
							classDependentActionResources.requiresClasses = classDependentActionResources.requiresClasses or {}
							table.insert(classDependentActionResources.requiresClasses, classId)

							buildClasses()
						end

						for _, subclassId in TableUtils:OrderedPairs(subclasses, function(key, value)
							return ClassesAndSubclassesMutator.translationMap[value]
						end) do
							---@type ExtuiSelectable
							local select = menu:AddSelectable(ClassesAndSubclassesMutator.translationMap[subclassId], "DontClosePopups")
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

			local classGroup = cell:AddGroup(i)
			buildGeneral(classGroup, classDependentActionResources.actionResources)
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

		return true
	end

	if mutator.values.general then
		for i, actionResourceConfig in pairs(mutator.values.general) do
			if not record(actionResourceConfig) then
				mutator.values.general[i].delete = true
				mutator.values.general[i] = nil
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
					classConfig.requiresClasses[ci].delete = true
					classConfig.requiresClasses[ci] = nil
					if not classConfig.requiresClasses() then
						mutator.values.classDependent[co].delete = true
						mutator.values.classDependent[co] = nil
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
					classConfig.actionResources[i] = nil
					if (not classConfig.__real and not next(classConfig.actionResources)) or (classConfig.__real and not classConfig.actionResources()) then
						mutator.values.classDependent[co].delete = true
						mutator.values.classDependent[co] = nil
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

	if TableUtils:IndexOf(actionResourceMutators, function(value)
			return not value.newVersion
		end) then
		Logger:BasicWarning("Skipping at least one mutator as it's using the deprecated version when a current version is eligible - all mutators being processed: %s",
			entityVar.appliedMutatorsPath[self.name])
		for i, mutator in ipairs(actionResourceMutators) do
			if not mutator.newVersion then
				actionResourceMutators[i] = nil
			end
		end
		TableUtils:ReindexNumericTable(actionResourceMutators)
	end

	---@type {[Guid]: ActionResourcesConfig[]}
	local resourcePool = {}

	for _, actionResourceMutator in ipairs(actionResourceMutators) do
		if actionResourceMutator.values.general then
			for _, generalConfig in ipairs(actionResourceMutator.values.general) do
				if resourcePool[generalConfig.resourceId] then
					resourcePool[generalConfig.resourceId][generalConfig.resourceLevel] = generalConfig
				else
					resourcePool[generalConfig.resourceId] = {
						[generalConfig.resourceLevel] = generalConfig
					}
				end
			end
		end

		if actionResourceMutator.values.classDependent then
			for _, classConfig in ipairs(actionResourceMutator.values.classDependent) do
				---@type {[Guid]: ActionResourcesConfig[]}
				local config = {}
				for _, classId in pairs(classConfig.requiresClasses or {}) do
					for _, classOnEntity in pairs(entity.Classes.Classes) do
						if classOnEntity.ClassUUID == classId or classOnEntity.SubClassUUID == classId then
							Logger:BasicDebug("Class %s is present on the entity - adding resources", Ext.StaticData.Get(classId, "ClassDescription").Name)
							for _, resourceConfig in ipairs(classConfig.actionResources) do
								if not config[resourceConfig.resourceId] then
									resourceConfig.totalClassLevel = classOnEntity.Level
									config[resourceConfig.resourceId] = {
										[resourceConfig.resourceLevel] = resourceConfig
									}
								elseif config[resourceConfig.resourceId][resourceConfig.resourceLevel] then
									config[resourceConfig.resourceId][resourceConfig.resourceLevel].totalClassLevel =
										config[resourceConfig.resourceId][resourceConfig.resourceLevel].totalClassLevel + classOnEntity.Level
								else
									resourceConfig.totalClassLevel = classOnEntity.Level
									config[resourceConfig.resourceId][resourceConfig.resourceLevel] = resourceConfig
								end
							end
						end
					end
				end
				for resource, resourceConfigs in pairs(config) do
					for level, resourceConfig in pairs(resourceConfigs) do
						resourcePool[resource] = resourcePool[resource] or {}
						resourcePool[resource][level] = resourceConfig
					end
				end
			end
		end
	end

	Logger:BasicTrace("Final resource configs: %s", resourcePool)

	local boostString = ""
	local template = "ActionResourceOverride(%s,%d,%d);"

	for resourceId, leveledConfigs in pairs(resourcePool) do
		---@type ResourceActionResource
		local resource = Ext.StaticData.Get(resourceId, "ActionResource")

		for resourceLevel, resourceConfig in TableUtils:OrderedPairs(leveledConfigs) do
			local amount = resourceConfig.levelMap[1]
			if not amount then
				for _, resources in pairs(entity.ActionResources.Resources) do
					local index = TableUtils:IndexOf(resources, function(value)
						return value.ResourceUUID == resourceId and value.Level == resourceLevel
					end)
					if index then
						amount = resources[index].MaxAmount
						break
					end
				end
			end
			amount = amount or 0
			Logger:BasicDebug("Base amount for subsequent additions is: %d", amount)

			local lastLevelValue = 0
			for i = 2, (resourceConfig.totalClassLevel or entity.EocLevel.Level) do
				if resourceConfig.levelMap[i] then
					amount = amount + resourceConfig.levelMap[i]
					lastLevelValue = resourceConfig.levelMap[i]
				elseif resourceConfig.additiveCurve then
					amount = amount + lastLevelValue
				end
			end

			if amount > 0 then
				boostString = boostString .. string.format(template, resource.Name, amount, resourceConfig.resourceLevel or 0)
			else
				Logger:BasicDebug("Not adding resource %s to the boosts as the final amount is %s", resource.Name, amount)
			end
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

---@return MazzleDocsDocumentation
function ActionResourcesMutator:generateDocs()
	return {
		{
			Topic = self.Topic,
			SubTopic = self.SubTopic,
			content = {
				{
					type = "Heading",
					text = "Action Resources",
				},
				{
					type = "Separator"
				},
				{
					type = "CallOut",
					prefix = "",
					prefix_color = "Yellow",
					text = [[
Dependency On: Classes/Subclasses
Transient: No (Unless the game is restarted, then yes)
Composable: Yes - Resources will be merged together into one pool, with later mutators overwriting earlier ones if the same resource is configured]]
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
					text = [[Conceptually, this mutator is fairly straightforward - assign Action Resources to entities by defining their resource curve, mimicking progressions;
however, there are important technical nuances that need to be strictly observed as documented below.]]
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
There are two main sections - General and Class-specific. General configs use the current level of the entity (according to the EocLevel component) when applying, and Class-specific overwrite General configs where applicable, and use the **sum** of all the relevant classes on the entity (i.e. if you give 1 spell slot per level to Warlock and Wizard, and the selected entity is level 6 but has 2 levels in Wizard and Warlock, they'll only be given 4 spell slots).

An important behavior to note is that this mutator _adds_ the defined amount of resources to the entity, according to their current level; meaning, if the entity is currently level 4 and has 3 Ki Points, and you give them 2 Ki Points per level starting from level 2, they'll end up with 9 Ki Points.
However, if you specify Level 1 in the config, then that will override the existing amount on the entity, using that number as the base - in the previous example, if you give them 1 Ki Point at Level 1, and 2 every level after, they'll end with 7 Ki Points (1 + (2 * 3)), as opposed to (3 + (2 * 3)).

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
					text = [[
This mutator has a unique problem: Boosts that aren't backed by a Status or Passive are wiped on reload (or loading a different campaign), and Action Resources added/changed by a Boost are reset when the boost is wiped - since adding a resource gives the entity a full charge in that resource, this would mean that NPCs would regain things like spell slots if the user reloads mid-combat.

To combat (heh) this, Lab dynamically creates a new BOOST Status for every entity processed by this mutator, using the naming scheme `ABSOLUTES_LAB_RESOURCE_BOOST_{last 12 characters of the entity's UUID}`.

This ensures that the boosts don't get wiped between reloads - however, it can't prevent the boosts from being wiped on game restart, as the status itself isn't backed by a static stat entry - it won't exist until Lab runs again, but the entity is processed by the game before Lab can run, so BG3 won't see the status and will clean up the entity.

As this only affects scenarios where a user saves mid-combat and restarts the game, it's currently being left as a hopefully rare, but known, gap. Addressing this issue will require local file writes per campaign to track created resources. Feedback is required!]]
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
					text = "Selected entities should have:"
				},
				{
					type = "Bullet",
					text = {
						"exactly 7 Level 1 spell slots by level 5",
						"7 more Level 1 spell slots than they usually do by level 5",
						"2 Bladesong charges if they're a Bladesong",
						"1 Extra Action Point if they're just a Rogue, or 2 if they're equally multiclassed as a Rogue and a Fighter"
					}
				} --[[@as MazzleDoctsBullet]],
			}
		}
	} --[[@as MazzleDocsDocumentation]]
end

---@return {[string]: MazzleDocsContentItem}
function ActionResourcesMutator:generateChangelog()
	return {
		["1.8.4"] = {
			type = "Bullet",
			text = {
				"Fix issue with import process that was wiping action resource configs inappropriately"
			}
		},
		["1.8.0"] = {
			type = "Bullet",
			text = {
				"Deleted Deprecated version of this mutator - only the version introduced as of 1.7.0 is supported"
			}
		},
		["1.7.1"] = {
			type = "Bullet",
			text = {
				"Removed isHidden filtering when displaying the possible Action Resources to add"
			}
		},
		["1.7.0"] = {
			type = "Bullet",
			text = {
				"Deprecated the previous implementation, implementing a new version"
			}
		}
	} --[[@as {[string]: MazzleDocsContentItem}]]
end
