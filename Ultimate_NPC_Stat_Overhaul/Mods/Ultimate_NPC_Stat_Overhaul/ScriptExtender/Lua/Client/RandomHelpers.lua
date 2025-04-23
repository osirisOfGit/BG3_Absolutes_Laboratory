Helpers = {}

---@param tooltip ExtuiTooltip
---@param itemName string?
---@param itemStat Object|Weapon|Armor
function Helpers:BuildTooltip(tooltip, itemName, itemStat)
	if itemName then
		tooltip:AddText("\t " .. itemName)
	else
		tooltip:AddText("\n")
	end

	if itemStat.ModId ~= "" then
		local mod = Ext.Mod.GetMod(itemStat.ModId).Info
		tooltip:AddText(string.format(Translator:translate("From mod '%s' by '%s'"), mod.Name, mod.Author ~= "" and mod.Author or "Larian")).TextWrapPos = 600
	end

	if itemStat.OriginalModId ~= "" and itemStat.OriginalModId ~= itemStat.ModId then
		local mod = Ext.Mod.GetMod(itemStat.OriginalModId).Info
		tooltip:AddText(string.format(Translator:translate("Originally from mod '%s' by '%s'"), mod.Name, mod.Author ~= "" and mod.Author or "Larian")).TextWrapPos = 600
	end
end

---@param ... ExtuiTreeParent
function Helpers:KillChildren(...)
	for _, parent in pairs({ ... }) do
		for _, child in pairs(parent.Children) do
			if child.UserData ~= "keep" then
				child:Destroy()
			end
		end
	end
end

function Helpers:ClearEmptyTablesInProxyTree(proxyTable)
	local parentTable = proxyTable._parent_proxy
	if not proxyTable() then
		proxyTable.delete = true
		if parentTable then
			Helpers:ClearEmptyTablesInProxyTree(parentTable)
		end
	end
end

Translator:RegisterTranslation({
	["From mod '%s' by '%s'"] = "hb46981c098c145978bd8daa53a1453aeb9c0",
	["Originally from mod '%s' by '%s'"] = "h1d4bb3618c794d8bb495a19db4fd9a52325e",
})
