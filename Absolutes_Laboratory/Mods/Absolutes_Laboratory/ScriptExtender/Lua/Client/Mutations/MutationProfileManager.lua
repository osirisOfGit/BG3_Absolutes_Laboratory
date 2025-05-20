MutationProfileManager = {}

---@param parent ExtuiTreeParent
---@param activeProfle MutationProfile
function MutationProfileManager:BuildProfileManager(parent, activeProfle)
	Helpers:KillChildren(parent)

	local rulesTable = parent:AddTable("ProfileRules", 3)

	local counter = 0
	for _, mutationFolder in pairs(ConfigurationStructure.config.mutations.folders) do
		for mutationName, mutation in pairs(mutationFolder.mutations) do
			counter = counter + 1

			local row = rulesTable:AddRow()

			row:AddCell():AddText(tostring(counter)).CanDrag = true

			if activeProfle.mutationRules[counter] then
				local mutationRule = activeProfle.mutationRules[counter]
				row.UserData = mutationRule._real

				row:AddCell():AddText(mutationRule.mutationFolder .. "/" .. mutationRule.mutationName)

				local additiveBox = row:AddCell():AddCheckbox("Additive", mutationRule.additive)
				additiveBox.OnChange = function()
					mutationRule.additive = additiveBox.Checked
				end
			end
		end
	end
end
