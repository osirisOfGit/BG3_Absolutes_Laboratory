---@param parent ExtuiTreeParent
---@return number
local function countNumberOfChildrenInTree(parent)
	local counter = 0

	pcall(function()
		local maxChildren = 0
		for _, child in pairs(parent.Children) do
			if child.UserData ~= "collapsed" then
				local children = countNumberOfChildrenInTree(child.UserData == "row" and child.Children[2] or child)
				counter = counter + 1
				if children > maxChildren then
					maxChildren = children
				end
			end
		end
		counter = counter + maxChildren
	end)

	return counter
end

---@param parent ExtuiTreeParent
---@param resource Resource
---@param resourceType string?
function Styler:SimpleRecursiveTwoColumnTable(parent, resource, resourceType)
	local subTable = Styler:TwoColumnTable(parent)
	subTable.Borders = false
	subTable.BordersInnerH = true
	for key, value in TableUtils:OrderedPairs(resource, function(key)
		return tonumber(key) or key
	end) do
		local row = subTable:AddRow()
		row.UserData = "row"

		if type(value) == "table" then
			row:AddCell():AddText(tostring(key))

			local valueCell = row:AddCell()
			EntityManager:RenderDisplayableValue(valueCell, value, key)
			if #valueCell.Children == 0 then
				row:Destroy()
			end
			-- and (not tonumber(value) or tonumber(value) > 0)
		elseif (value ~= "" and value ~= "00000000-0000-0000-0000-000000000000") then
			row:AddCell():AddText(key)
			local displayCell = row:AddCell()
			EntityManager:RenderDisplayableValue(displayCell, value, key)
			if #displayCell.Children == 0 then
				Styler:SelectableText(displayCell, resourceType, tostring(value))
			end
		else
			row:Destroy()
		end
	end

	if #subTable.Children == 0 then
		subTable:Destroy()
	elseif parent.UserData ~= "collapsed" and countNumberOfChildrenInTree(subTable) >= 15 then
		parent:DetachChild(subTable)
		parent = parent:AddCollapsingHeader(resourceType or parent.Label or parent.IDContext or "")
		parent.UserData = "collapsed"
		parent:AttachChild(subTable)
		parent:SetColor("Header", { 1, 1, 1, 0 })
	end
end

---@generic K: string|number
---@generic T: table
---@param parent ExtuiTreeParent
---@param retrieveConfigFunc fun(config: MutationsConfig): {[K]: T}?
---@param transformForSortingFunc (fun(key: K, value: T):any)?
---@param filterFunc (fun(key: K, listItem: T): boolean)?
---@param selectCustomizer fun(select: ExtuiSelectable, id: K, item: T)
function Styler:BuildCompleteUserAndModLists(parent, retrieveConfigFunc, transformForSortingFunc, filterFunc, selectCustomizer)
	local userList = retrieveConfigFunc(ConfigurationStructure.config.mutations)

	parent:SetStyle("SeparatorTextAlign", 0.5)

	local selectHeight = 0
	local optimalWidth = 0

	local userSep = parent:AddSeparatorText("Your Lists")
	userSep:SetStyle("SeparatorTextAlign", 0.5)

	local userListGroup = parent:AddChildWindow("userLists")
	userListGroup.NoSavedSettings = true

	if userList then
		for guid, item in TableUtils:OrderedPairs(userList, transformForSortingFunc, filterFunc) do
			---@type ExtuiSelectable
			local select = userListGroup:AddSelectable(guid, "DontClosePopups")
			select.IDContext = guid
			selectCustomizer(select, guid, item)
			local width, optimalHeight = self:calculateTextDimensions(select.Label)
			selectHeight = selectHeight + optimalHeight
			optimalWidth = width > optimalWidth and width or optimalWidth
		end
	end

	if #userListGroup.Children == 0 then
		userListGroup:Destroy()
		userSep:Destroy()
	else
		userListGroup.Size = { optimalWidth, math.min(500, selectHeight) }
	end

	local modListSep = parent:AddSeparatorText("Mod-Added Lists")
	Styler:ScaledFont(modListSep, "Big")

	---@type LocalModCache
	local modLists = retrieveConfigFunc(MutationModProxy.ModProxy)

	local destroySep = true
	if modLists then
		---@type {[Guid]: {[Guid]: table}}
		local modOwnedLists = {}

		for modId, modCache in pairs(modLists) do
			---@cast modCache +LocalModCache

			local list = retrieveConfigFunc(modCache --[[@as MutationsConfig]])
			if list and next(list) then
				modOwnedLists[modId] = {}
				for guid in pairs(list) do
					modOwnedLists[modId][guid] = modLists[guid]
				end
			end
		end

		if next(modOwnedLists) then
			for modId, lists in TableUtils:OrderedPairs(modOwnedLists, function(key, value)
				return Ext.Mod.GetMod(key).Info.Name
			end) do
				selectHeight = 0
				optimalWidth = 0

				local modSep = parent:AddSeparatorText(Ext.Mod.GetMod(modId).Info.Name)
				modSep.Font = "Small"

				local modGroup = parent:AddChildWindow("Mods" .. modId)
				modGroup.NoSavedSettings = true

				for guid, item in TableUtils:OrderedPairs(lists, transformForSortingFunc, filterFunc) do
					---@type ExtuiSelectable
					local select = modGroup:AddSelectable(transformForSortingFunc and transformForSortingFunc(guid, item) or item.name, "DontClosePopups")
					select.IDContext = guid
					selectCustomizer(select, guid, item)

					local width, optimalHeight = self:calculateTextDimensions(select.Label)
					selectHeight = selectHeight + optimalHeight
					optimalWidth = width > optimalWidth and width or optimalWidth
				end
				if #modGroup.Children == 0 then
					modGroup:Destroy()
					modSep:Destroy()
				else
					destroySep = false
					modGroup.Size = { optimalWidth, math.min(500, selectHeight) }
				end
			end
		end
	end
	if destroySep then
		modListSep:Destroy()
	end
end


