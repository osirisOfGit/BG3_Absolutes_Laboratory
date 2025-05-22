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

function Helpers:BuildModString(modId)
	if modId then
		local mod = Ext.Mod.GetMod(modId)
		if mod then
			return string.format("%s (v%s)", mod.Info.Name, table.concat(mod.Info.ModVersion, "."))
		else
			return "Invalid Mod Id - " .. modId
		end
	end
end

-- Shoutout to Skiz for this
local toggleTimer

---@param collapse boolean
---@param targetWidth number? when expanding
---@param widthFunc fun(width: number?): number
---@param groupVisibility ExtuiStyledRenderable
---@param finalFunc fun()?
function Helpers:CollapseExpand(collapse, targetWidth, widthFunc, groupVisibility, finalFunc)
	if not toggleTimer then
		local cWidth = widthFunc()
		local stepDelay = 10
		if collapse then
			local function stepCollapse()
				if cWidth > 0 then
					cWidth = math.max(0, cWidth - (cWidth * 0.1)) -- Reduce by 10%
					cWidth = cWidth < 10 and 0 or cWidth

					widthFunc(cWidth)
					stepDelay = math.min(50, stepDelay * 1.02) -- Increase delay per step to make it like soft-close drawer
					toggleTimer = Ext.Timer.WaitFor(stepDelay, stepCollapse)
				else
					groupVisibility.Visible = false
					toggleTimer = nil

					if finalFunc then
						finalFunc()
					end
				end
			end
			stepCollapse()
		else
			local widthStep = 1
			local max = math.min(350, targetWidth)
			local function stepExpand()
				cWidth = cWidth == 0 and 1 or cWidth

				groupVisibility.Visible = true
				if cWidth < max then
					widthStep = math.max(0.01, widthStep - (widthStep * .125))

					cWidth = math.min(max, cWidth + (cWidth * widthStep))
					widthFunc(cWidth)

					stepDelay = math.min(50, stepDelay)
					toggleTimer = Ext.Timer.WaitFor(stepDelay, stepExpand)
				else
					toggleTimer = nil
					if finalFunc then
						finalFunc()
					end
				end
			end
			stepExpand()
		end
	end
end

Translator:RegisterTranslation({
	["From mod '%s' by '%s'"] = "hb46981c098c145978bd8daa53a1453aeb9c0",
	["Originally from mod '%s' by '%s'"] = "h1d4bb3618c794d8bb495a19db4fd9a52325e",
})
