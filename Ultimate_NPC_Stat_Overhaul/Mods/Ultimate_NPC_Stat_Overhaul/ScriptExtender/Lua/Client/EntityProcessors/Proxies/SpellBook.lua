SpellBookProxy = EntityProxy:new()

EntityProxy:RegisterResourceProxy("SpellBook", SpellBookProxy)

---@param spellDataList SpellBookComponent
function SpellBookProxy:RenderDisplayableValue(parent, spellDataList)
	for _, spellData in ipairs(spellDataList.Spells) do
		local header = parent:AddCollapsingHeader(spellData.Id.Prototype)
		EntityManager:RenderDisplayableValue(header, spellData)
		if #header.Children == 0 then
			header:Destroy()
		end
	end
end
