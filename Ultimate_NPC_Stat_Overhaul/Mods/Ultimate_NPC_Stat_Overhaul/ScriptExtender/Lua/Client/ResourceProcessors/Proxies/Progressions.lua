ProgressionProxy = ResourceProxy:new()

ProgressionProxy.fieldsToParse = {
	"AddSpells",
	"AllowImprovement",
	"BoostPrototypes",
	"Boosts",
	"IsMulticlass",
	"Level",
	"Name",
	"PassivePrototypesAdded",
	"PassivePrototypesRemoved",
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
	if progressionTableId then
		local progressions = CharacterIndex.progressionIndex[progressionTableId]

		if progressions then
			local header = parent:AddCollapsingHeader("Progressions")
			header:SetColor("Header", {1, 1, 1, 0})

			local table = Styler:TwoColumnTable(header, "progressions")
			for _, progressionID in TableUtils:OrderedPairs(progressions, function(key)
				return Ext.StaticData.Get(progressions[key], "Progression").Level or key
			end) do
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
end
