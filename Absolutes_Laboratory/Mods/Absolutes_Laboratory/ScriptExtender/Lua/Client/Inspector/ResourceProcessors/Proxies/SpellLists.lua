SpellListProxy = ResourceProxy:new()

ResourceProxy:RegisterResourceProxy("SpellUUID", SpellListProxy)
ResourceProxy:RegisterResourceProxy("SpellList", SpellListProxy)

function SpellListProxy:RenderDisplayableValue(parent, spellListId)
	if spellListId then
		---@type ResourceSpellList
		local spellList = Ext.StaticData.Get(spellListId, "SpellList")

		if spellList then
			Styler:HyperlinkText(parent, spellList.Name, function (parent)
				ResourceManager:RenderDisplayWindow(spellList, parent)
			end)
		end
	end
end
