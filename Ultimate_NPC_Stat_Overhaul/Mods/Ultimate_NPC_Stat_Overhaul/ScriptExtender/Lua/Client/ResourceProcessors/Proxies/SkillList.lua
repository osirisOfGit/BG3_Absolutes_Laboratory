SkillListProxy = ResourceProxy:new()
SkillListProxy.fieldsToParse = {
	"Conditions",
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

			for _, property in TableUtils:OrderedPairs(self.fieldsToParse) do
				local value = spellData[property]
				
				if type(value) == "userdata"  then
					value = tostring(value)
				end
				if value and value ~= "" and value ~= "None" then
					local row = displayTable:AddRow()
					row:AddCell():AddText(property)
					ResourceManager:RenderDisplayableValue(row:AddCell(), value, property)
				end
			end
		end
	end
end
