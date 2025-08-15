---@class ProgressionProxy : ResourceProxy
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
ResourceProxy:RegisterResourceProxy("Progression", ProgressionProxy)
ResourceProxy:RegisterResourceProxy("resource::Progression", ProgressionProxy)

---@type {[Guid]: (Guid[]|Guid)}
ProgressionProxy.progressionTableMappings = {}

---@type {[Guid]: string}
ProgressionProxy.translationMap = {}

function ProgressionProxy:buildProgressionIndex()
	if not next(self.progressionTableMappings) then
		for _, progressionId in pairs(Ext.StaticData.GetAll("Progression")) do
			---@type ResourceProgression
			local progression = Ext.StaticData.Get(progressionId, "Progression")

			if progression and progression.ResourceUUID then
				ProgressionProxy.progressionTableMappings[progression.ResourceUUID] = progression.TableUUID
				ProgressionProxy.progressionTableMappings[progression.TableUUID] = ProgressionProxy.progressionTableMappings[progression.TableUUID] or {}

				if type(self.progressionTableMappings[progression.TableUUID]) == "table" then
					table.insert(self.progressionTableMappings[progression.TableUUID], progression.ResourceUUID)
				else
					Logger:BasicWarning("Progression TableUUID %s on progression %s (%s) is the same as a previously registered ResourceUUID - not sure how?", progression.TableUUID, progression.ResourceUUID, progression.Name)
				end

				if not self.translationMap[progression.TableUUID] then
					self.translationMap[progression.TableUUID] = progression.Name
				end
			end
		end

		for _, progressions in pairs(self.progressionTableMappings) do
			if type(progressions) == "table" then
				table.sort(progressions, function(a, b)
					return Ext.StaticData.Get(a, "Progression").Level < Ext.StaticData.Get(b, "Progression").Level
				end)
			end
		end
	end
end

---@param progressionTableId string
function ProgressionProxy:RenderDisplayableValue(parent, progressionTableId)
	self:buildProgressionIndex()

	if progressionTableId and progressionTableId ~= "00000000-0000-0000-0000-000000000000" then
		---@type ResourceProgression
		local progression = Ext.StaticData.Get(progressionTableId, "Progression")

		if not progression then
			local progressions = self.progressionTableMappings[progressionTableId]

			if progressions then
				-- local header = parent:AddCollapsingHeader("Progressions")
				-- header:SetColor("Header", { 1, 1, 1, 0 })

				local table = Styler:TwoColumnTable(parent, "progressions")
				for _, progressionID in ipairs(progressions) do
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
