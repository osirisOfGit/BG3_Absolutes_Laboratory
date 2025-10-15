PrepMarkerSelector = SelectorInterface:new("Prep Marker")

---@class PrepMarkerSelector : Selector
---@field criteriaValue Guid[]

---@param existingSelector PrepMarkerSelector
function PrepMarkerSelector:renderSelector(parent, existingSelector)
	parent:AddText(("!! Dry Running this selector will use the %ss in the Active Profile !!"):format(PrepPhaseMarkerMutator.name))

	existingSelector.criteriaValue = existingSelector.criteriaValue or {}

	local prepPhaseCategories = MutationConfigurationProxy.prepPhaseMarkers

	local markerTable = parent:AddTable("markerTable", 3)
	local row = markerTable:AddRow()

	for categoryId, prepPhaseCategory in pairs(prepPhaseCategories, function(key, value)
		return value.name
	end) do
		local box = row:AddCell():AddCheckbox(prepPhaseCategory.name, TableUtils:IndexOf(existingSelector.criteriaValue, categoryId) ~= nil)

		box.OnChange = function()
			local index = TableUtils:IndexOf(existingSelector.criteriaValue, categoryId)

			if index then
				existingSelector.criteriaValue[index] = nil
				TableUtils:ReindexNumericTable(existingSelector.criteriaValue)
			else
				table.insert(existingSelector.criteriaValue, categoryId)
			end
		end

		if prepPhaseCategory.description and prepPhaseCategory.description ~= "" then
			box:Tooltip():AddText("\t " .. prepPhaseCategory.description)
		end
	end
end

---@param selector PrepMarkerSelector
function PrepMarkerSelector:handleDependencies(export, selector, removeMissingDependencies)
	for i, markerId in ipairs(selector.criteriaValue) do
		local marker = MutationConfigurationProxy.prepPhaseMarkers[markerId]
		if not marker then
			selector.criteriaValue[i] = nil
		elseif not removeMissingDependencies then
			if marker.modId then
				selector.modDependencies = selector.modDependencies or {}
				if not selector.modDependencies[marker.modId] then
					local name, author, version = Helpers:BuildModFields(marker.modId)
					if author == "Larian" then
						goto continue
					end
					selector.modDependencies[marker.modId] = {
						modName = name,
						modAuthor = author,
						modVersion = version,
						modId = marker.modId,
						packagedItems = {}
					}
				end
				selector.modDependencies[marker.modId].packagedItems[markerId] = marker.name
			else
				export.prepPhaseMarkers[markerId] = TableUtils:DeeplyCopyTable(marker._real or marker)
			end
		end
		::continue::
	end
	TableUtils:ReindexNumericTable(selector.criteriaValue)
end

---@param selector PrepMarkerSelector
---@return fun(entity: (EntityHandle|EntityRecord), entityVar: MutatorEntityVar): boolean
function PrepMarkerSelector:predicate(selector)
	local cachedSelectors = {}
	local activeProfile = MutationConfigurationProxy.profiles[Ext.Vars.GetModVariables(ModuleUUID).ActiveMutationProfile]

	return function(entity, entityVar)
		local appliedCategories = {}
		for i, mProfileRule in ipairs(activeProfile.prepPhaseMutations) do
			local mutation = MutationConfigurationProxy.folders[mProfileRule.mutationFolderId].mutations[mProfileRule.mutationId]
			mutation = mutation._real or mutation

			---@type PrepMarkerCategory[]
			local markerMutator = mutation.mutators[1].values or {}
			for _, category in ipairs(markerMutator) do
				if TableUtils:IndexOf(selector.criteriaValue, category) then
					if not cachedSelectors[mProfileRule.mutationFolderId] then
						cachedSelectors[mProfileRule.mutationFolderId] = {}
					end
					if not cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId] then
						cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId] = SelectorInterface:createComposedPredicate(mutation.selectors)
					end

					if cachedSelectors[mProfileRule.mutationFolderId][mProfileRule.mutationId]:Test(entity) then
						for _, mutator in pairs(mutation.mutators) do
							if mProfileRule.additive then
								if appliedCategories[1] then
									table.insert(appliedCategories, mutator.values)
								else
									appliedCategories = { TableUtils:DeeplyCopyTable(appliedCategories), mutator.values }
								end
								if entityVar then
									entityVar.appliedMutators[mutator.targetProperty] = mutator
									entityVar.appliedMutatorsPath[mutator.targetProperty][i] = mProfileRule
								end
							else
								appliedCategories = mutator.values._real or mutator.values
								if entityVar then
									entityVar.appliedMutators[mutator.targetProperty] = mutator
									entityVar.appliedMutatorsPath[mutator.targetProperty] = { [i] = mProfileRule }
								end
							end
						end
					end
					goto next
				end
			end
			::next::
		end
		if next(appliedCategories) then
			return true
		else
			return false
		end
	end
end

function PrepMarkerSelector:generateDocs()
end
