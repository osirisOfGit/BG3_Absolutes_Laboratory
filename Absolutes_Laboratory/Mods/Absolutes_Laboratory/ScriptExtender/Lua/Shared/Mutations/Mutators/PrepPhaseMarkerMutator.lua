Ext.Vars.RegisterUserVariable("Absolutes_Lab_Prep_Phase_Marker", {
	Server = true,
	Client = true
})

PrepPhaseMarkerMutator = MutatorInterface:new("Prep Phase Marker")

function PrepPhaseMarkerMutator:Transient()
	return false
end

function PrepPhaseMarkerMutator:canBeAdditive()
	return true
end

---@param mutator PrepPhaseMarkerMutator
function PrepPhaseMarkerMutator:handleDependencies(export, mutator, removeMissingDependencies)
	for i, markerId in ipairs(mutator.values) do
		local marker = MutationConfigurationProxy.prepPhaseMarkers[markerId]
		if not marker then
			mutator.values[i] = nil
		elseif not removeMissingDependencies then
			if marker.modId then
				mutator.modDependencies = mutator.modDependencies or {}
				if not mutator.modDependencies[marker.modId] then
					local name, author, version = Helpers:BuildModFields(marker.modId)
					if author == "Larian" then
						goto continue
					end
					mutator.modDependencies[marker.modId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = marker.modId,
						packagedItems = {}
					}
				end
				mutator.modDependencies[marker.modId].packagedItems[markerId] = marker.name
			else
				export.prepPhaseMarkers[markerId] = TableUtils:DeeplyCopyTable(marker._real or marker)
			end
		end
		::continue::
	end
end

---@class PrepPhaseMarkerMutator : Mutator
---@field values PrepMarkerCategory[]

---@param mutator PrepPhaseMarkerMutator
function PrepPhaseMarkerMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}

	Helpers:KillChildren(parent)
	local popup = parent:AddPopup("")

	local prepPhaseCategories = MutationConfigurationProxy.prepPhaseMarkers

	local markerTable = parent:AddTable("markerTable", 3)
	local row = markerTable:AddRow()

	for categoryId, prepPhaseCategory in TableUtils:OrderedPairs(prepPhaseCategories, function(key, value)
		return value.name
	end) do
		local box = row:AddCell():AddCheckbox(prepPhaseCategory.name, TableUtils:IndexOf(mutator.values, categoryId) ~= nil)

		box.OnChange = function()
			local index = TableUtils:IndexOf(mutator.values, categoryId)

			if index then
				mutator.values[index] = nil
				TableUtils:ReindexNumericTable(mutator.values)
			else
				table.insert(mutator.values, categoryId)
			end
		end

		if prepPhaseCategory.description and prepPhaseCategory.description ~= "" then
			box:Tooltip():AddText("\t " .. prepPhaseCategory.description)
		end
	end

	local manageMarkersButton = row:AddCell():AddButton("Manage Markers")
	manageMarkersButton.OnClick = function()
		Helpers:KillChildren(popup)
		popup:Open()

		for categoryId, prepPhaseCategory in TableUtils:OrderedPairs(prepPhaseCategories, function(key, value)
			return value.name
		end) do
			---@type ExtuiMenu
			local menu = popup:AddMenu(prepPhaseCategory.name)

			---@type ExtuiMenu
			local editMenu = menu:AddMenu("Edit")
			FormBuilder:CreateForm(editMenu, function(formResults)
				prepPhaseCategory.name = formResults.Name
				prepPhaseCategory.description = formResults.Description
				manageMarkersButton:OnClick()
			end, {
				{
					label = "Name",
					type = "Text",
					defaultValue = prepPhaseCategory.name,
					errorMessageIfEmpty = "Name is required"
				},
				{
					label = "Description",
					type = "Multiline",
					defaultValue = prepPhaseCategory.description
				}
			})

			---@param selectable ExtuiSelectable
			menu:AddSelectable("Delete", "DontClosePopups").OnClick = function(selectable)
				if selectable.Label ~= "Delete" then
					ConfigurationStructure.config.mutations.prepPhaseMarkers[categoryId].delete = true

					for _, folder in TableUtils:OrderedPairs(ConfigurationStructure.config.mutations.folders) do
						for _, mutation in TableUtils:OrderedPairs(folder.mutations) do
							if mutation.prepPhase then
								for _, mutator in ipairs(mutation.mutators) do
									---@cast mutator PrepPhaseMarkerMutator
									local index = TableUtils:IndexOf(mutator.values, categoryId)
									if index then
										mutator.values[index].delete = true
										TableUtils:ReindexNumericTable(mutator.values)
									end
								end
							end
						end
					end

					self:renderMutator(parent, mutator)
				else
					selectable.Label = "Are you sure?"
					Styler:Color(selectable, "ErrorText")
					selectable.DontClosePopups = false
				end
			end
		end

		FormBuilder:CreateForm(popup:AddMenu("Create New"), function(formResults)
			ConfigurationStructure.config.mutations.prepPhaseMarkers[FormBuilder:generateGUID()] = {
				name = formResults.Name,
				description = formResults.Description
			} --[[@as PrepMarkerCategory]]
			self:renderMutator(parent, mutator)
		end, {
			{
				label = "Name",
				type = "Text",
				errorMessageIfEmpty = "Name is required"
			},
			{
				label = "Description",
				type = "Multiline",
			}
		})
	end
end

function PrepPhaseMarkerMutator:applyMutator(entity, entityVar)
	-- ---@type Guid[]
	-- local prepMarkers = entityVar.appliedMutators[self.name].values

	-- local prepPhaseCategories = MutationConfigurationProxy.prepPhaseMarkers

	-- entity.Vars.Absolutes_Lab_Prep_Phase_Marker = {}

	-- for _, prepMarkerId in ipairs(prepMarkers) do
	-- 	if prepPhaseCategories[prepMarkerId] then
	-- 		table.insert(entity.Vars.Absolutes_Lab_Prep_Phase_Marker, prepMarkerId)
	-- 	end
	-- end
end

function PrepPhaseMarkerMutator:undoMutator(entity, entityVar)
	-- entity.Vars.Absolutes_Lab_Prep_Phase_Marker = nil
end
