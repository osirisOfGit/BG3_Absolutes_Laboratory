ProgressionProxy = ResourceProxy:new()

ProgressionProxy.fieldsToParse = {
	"AddSpells",
	"AllowImprovement",
	"Boosts",
	"IsMulticlass",
	"Level",
	"Name",
	["PassivePrototypesAdded"] = {
		"BoostConditionsIndex",
		"BoostContext",
		"ConditionsIndex",
		"Description",
		"EnabledConditions",
		"EnabledContext",
		"Name",
		"PriorityOrder",
		"Properties",
		"StatsFunctorContext",
		"StatsFunctors",
		"ToggleGroup",
		"ToggleOffContext",
		"ToggleOffEffect",
		"ToggleOffFunctors",
		"ToggleOnEffect",
		"ToggleOnFunctors",
		"TooltipConditionalDamage",
	},
	["PassivePrototypesRemoved"] = {
		"BoostConditionsIndex",
		"BoostContext",
		"ConditionsIndex",
		"Description",
		"EnabledConditions",
		"EnabledContext",
		"Name",
		"PriorityOrder",
		"Properties",
		"StatsFunctorContext",
		"StatsFunctors",
		"ToggleGroup",
		"ToggleOffContext",
		"ToggleOffEffect",
		"ToggleOffFunctors",
		"ToggleOnEffect",
		"ToggleOnFunctors",
		"TooltipConditionalDamage",
	},
	"PassivesAdded",
	"PassivesRemoved",
	"ProgressionType",
	"SelectAbilities",
	"SelectAbilityBonus",
	"SelectEquipment",
	"SelectPassives",
	"SelectSkills",
	"SelectSkillsExpertise",
	"SelectSpells",
	"SubClasses",
	"TableUUID",
	"field_D0",
}

ResourceProxy:RegisterResourceProxy("ProgressionTableUUID", ProgressionProxy)
ResourceProxy:RegisterResourceProxy("Progressions", ProgressionProxy)
ResourceProxy:RegisterResourceProxy("resource::Progression", ProgressionProxy)

---@param progressionTableId string
function ProgressionProxy:RenderDisplayableValue(parent, progressionTableId, statType)
	if progressionTableId and progressionTableId ~= "00000000-0000-0000-0000-000000000000" then
		---@type ResourceProgression
		local progression = Ext.StaticData.Get(progressionTableId, "Progression")

		if not progression then
			local progressions = CharacterIndex.progressionIndex[progressionTableId]

			if progressions then
				local header = parent:AddCollapsingHeader("Progressions")
				header:SetColor("Header", { 1, 1, 1, 0 })

				local table = Styler:TwoColumnTable(header, "progressions")
				for _, progressionID in TableUtils:OrderedPairs(progressions, function(key)
					return Ext.StaticData.Get(progressions[key], "Progression").Level or key
				end) do
					if progressionID ~= "00000000-0000-0000-0000-000000000000" then
						---@type ResourceProgression
						local progression = Ext.StaticData.Get(progressionID, "Progression")

						if progression then
							local row = table:AddRow()
							row:AddCell():AddText(progressionID)
							ResourceManager:RenderDisplayWindow(progression, row:AddCell())
						end
					end
				end
			end
		else
			local table = Styler:TwoColumnTable(parent, "progressions")
			if progression then
				local row = table:AddRow()
				row:AddCell():AddText(progression.Name)
				ResourceManager:RenderDisplayWindow(progression, row:AddCell())
			end
		end
	end
end
