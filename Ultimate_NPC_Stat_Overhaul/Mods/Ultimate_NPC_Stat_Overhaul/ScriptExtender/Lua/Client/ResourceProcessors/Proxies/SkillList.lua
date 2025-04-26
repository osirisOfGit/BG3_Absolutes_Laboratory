SkillListProxy = ResourceProxy:new()
SkillListProxy.fieldsToParse = {
	"Conditions",
	"LearningStrategy",
	"Spell",
	"SpellCastingAbility",
}

ResourceProxy:RegisterResourceProxy("SkillList", SkillListProxy)

---@param resourceValue CharacterSpellData[]
function SkillListProxy:RenderDisplayableValue(parent, resourceValue)
	if resourceValue then
		for _, spellData in ipairs(resourceValue) do
			local displayTable = parent:AddTable("spellData" .. spellData.Spell, 2)
			displayTable.Borders = true
			displayTable:AddColumn("", "WidthFixed")
			displayTable:AddColumn("", "WidthStretch")

			for property, value in TableUtils:OrderedPairs(spellData) do
				if type(value) == "userdata"  then
					value = tostring(value)
				end
				if value and value ~= "" and value ~= "None" then
					local row = displayTable:AddRow()
					row:AddCell():AddText(property)
					ResourceManager:RenderDisplayableValue(row:AddCell(), value, "Spell")
				end
			end
		end
	end
end
