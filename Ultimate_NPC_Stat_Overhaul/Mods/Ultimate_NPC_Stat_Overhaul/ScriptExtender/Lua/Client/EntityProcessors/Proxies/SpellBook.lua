SpellBookProxy = EntityProxy:new()

EntityProxy:RegisterResourceProxy("SpellBook", SpellBookProxy)

---@param spellDataList SpellBookComponent
function SpellBookProxy:RenderDisplayableValue(parent, spellDataList)
	for i, spellData in ipairs(spellDataList.Spells) do
		local header = parent:AddCollapsingHeader(spellData.Id.Prototype)
		header:SetColor("Header", {1, 1, 1, 0})
		header.IDContext = header.Label .. i

		EntityManager:RenderDisplayableValue(header, spellData)
		if #header.Children == 0 then
			header:Destroy()
		end
	end
end
