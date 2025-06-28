ClassesAndSubclassesMutator = MutatorInterface:new("Classes And Subclasses")

function ClassesAndSubclassesMutator:priority()
	return SpellListMutator:priority() + 1
end

---@class ClassesConditionalGroup
---@field classIds {[Guid] : number}
---@field spellListDependencies Guid[]

---@class ClassesAndSubclassesMutator : Mutator
---@field values ClassesConditionalGroup[]


---@type {[Guid] : Guid[]}
local classesAndSubclasses = {}

---@type {[Guid]: string}
local translationMap = {}

local function initClassIndex()
	if not next(classesAndSubclasses) then
		for _, classId in pairs(Ext.StaticData.GetAll("ClassDescription")) do
			---@type ResourceClassDescription
			local class = Ext.StaticData.Get(classId, "ClassDescription")

			if class.ParentGuid and class.ParentGuid ~= "00000000-0000-0000-0000-000000000000" and class.ParentGuid ~= "" then
				if not classesAndSubclasses[class.ParentGuid] then
					classesAndSubclasses[class.ParentGuid] = {}
				end

				table.insert(classesAndSubclasses[class.ParentGuid], classId)
			elseif not classesAndSubclasses[classId] then
				classesAndSubclasses[classId] = {}
			end

			local name = class.DisplayName:Get() or class.Name

			translationMap[classId] = name
		end
	end
end

---@param mutator ClassesAndSubclassesMutator
function ClassesAndSubclassesMutator:renderMutator(parent, mutator)
	initClassIndex()
	mutator.values = mutator.values or {}

	Helpers:KillChildren(parent)

	local popup = parent:AddPopup("")

	local classTable = Styler:TwoColumnTable(parent)
	classTable.ColumnDefs[1].Width = 20
	classTable.BordersV = false
	classTable.Resizable = false
	classTable.Borders = false
	classTable.BordersH = true

	for i, classConditionalGroup in ipairs(mutator.values) do
		local row = classTable:AddRow()

		local delete = Styler:ImageButton(row:AddCell():AddImageButton("delete" .. mutator.targetProperty, "ico_red_x", { 16, 16 }))
		delete.OnClick = function()
			for x = i, TableUtils:CountElements(mutator.values) do
				mutator.values[x].delete = true
				mutator.values[x] = TableUtils:DeeplyCopyTable(mutator.values._real[x + 1])
			end
			Helpers:KillChildren(parent)
			self:renderMutator(parent, mutator)
		end

		local groupCell = row:AddCell()
		local conditionalGroupTable = groupCell:AddTable(tostring(i), 2)
		conditionalGroupTable.Resizable = true

		local classRow = conditionalGroupTable:AddRow()
		local classDefCell = classRow:AddCell()
		---@type ExtuiText
		local errorText

		local groupTable = classDefCell:AddTable("", 2)
		groupTable.SizingStretchSame = true

		local headerRow = groupTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText("Class")
		headerRow:AddCell():AddText("Level % ( ? )"):Tooltip():AddText([[
	What % of the selected entity's character level should be used for this class's level (rounded as needed)
e.g. if a class is set to 75% and the entity's level is 10, they will be level 7 in that specific class
All %s in this group must add up to 100% - input is disabled if there is only 1 class in the group]])

		if classConditionalGroup.classIds then
			for classId, levelPercentage in TableUtils:OrderedPairs(classConditionalGroup.classIds, function(_, value)
				return value
			end) do
				local groupRow = groupTable:AddRow()

				local name = translationMap[classId]
				---@type ResourceClassDescription
				local class = Ext.StaticData.Get(classId, "ClassDescription")

				if translationMap[class.ParentGuid] then
					name = translationMap[class.ParentGuid] .. " - " .. name
				end

				local classCell = groupRow:AddCell()
				local deleteClass = Styler:ImageButton(classCell:AddImageButton("delete" .. classId, "ico_red_x", { 16, 16 }))
				deleteClass.OnClick = function()
					classConditionalGroup.classIds[classId] = nil
					if TableUtils:CountElements(classConditionalGroup.classIds) ~= 0 then
						for otherID, otherLevelPercentage in pairs(classConditionalGroup.classIds) do
							if levelPercentage + otherLevelPercentage <= 100 then
								classConditionalGroup.classIds[otherID] = otherLevelPercentage + levelPercentage
								break
							end
						end
					else
						classConditionalGroup.classIds.delete = true
					end

					self:renderMutator(parent, mutator)
				end

				Styler:HyperlinkText(classCell, name, function(parent)
					ResourceManager:RenderDisplayWindow(Ext.StaticData.Get(classId, "ClassDescription"), parent)
				end).SameLine = true

				local levelPercentageInput = groupRow:AddCell():AddInputInt("%", levelPercentage)
				levelPercentageInput.IDContext = classId
				levelPercentageInput.UserData = classId
				levelPercentageInput.ItemWidth = 40
				levelPercentageInput.SameLine = true

				if TableUtils:CountElements(classConditionalGroup.classIds) == 1 then
					levelPercentageInput.Disabled = true
				else
					levelPercentageInput.OnChange = function()
						local total = levelPercentageInput.Value[1]
						for _, childRow in pairs(groupTable.Children) do
							local input = childRow.Children[2].Children[1]
							if input.UserData and input.UserData ~= classId then
								---@cast input ExtuiInputInt
								total = total + input.Value[1]
							end
						end

						if total ~= 100 then
							errorText.Visible = true
						else
							errorText.Visible = false
						end
					end

					levelPercentageInput.OnDeactivate = function()
						if levelPercentageInput.Value[1] < 0 then
							levelPercentageInput.Value = { 0, 0, 0, 0 }
						end

						local total = levelPercentageInput.Value[1]
						for _, childRow in pairs(groupTable.Children) do
							local input = childRow.Children[2].Children[1]
							if input.UserData and input.UserData ~= classId then
								---@cast input ExtuiInputInt
								total = total + input.Value[1]
							end
						end

						if total ~= 100 then
							errorText.Visible = true
						else
							for _, childRow in pairs(groupTable.Children) do
								local input = childRow.Children[2].Children[1]
								if input.UserData then
									---@cast input ExtuiInputInt
									classConditionalGroup.classIds[input.UserData] = input.Value[1]
								end
							end

							self:renderMutator(parent, mutator)
						end
					end
				end
			end
		end

		errorText = classDefCell:AddText("All %s must add up to 100%!")
		-- Red
		errorText:SetColor("Text", { 1, 0.02, 0, 1 })
		errorText.Visible = false

		groupCell:AddButton("Add Class").OnClick = function()
			Helpers:KillChildren(popup)
			popup:Open()

			for classId, subclasses in TableUtils:OrderedPairs(classesAndSubclasses, function(key, value)
				return translationMap[key]
			end) do
				if next(subclasses) then
					---@type ExtuiMenu
					local menu = popup:AddMenu(translationMap[classId])
					menu.Disabled = (classConditionalGroup.classIds and classConditionalGroup.classIds[classId]) ~= nil

					menu:AddSelectable(translationMap[classId]).OnClick = function()
						classConditionalGroup.classIds = classConditionalGroup.classIds or {}
						classConditionalGroup.classIds[classId] = TableUtils:CountElements(classConditionalGroup.classIds) == 0 and 100 or 0

						self:renderMutator(parent, mutator)
					end

					for _, subclassId in TableUtils:OrderedPairs(subclasses, function(key, value)
						return translationMap[value]
					end) do
						if not menu.Disabled then
							menu.Disabled = (classConditionalGroup.classIds and classConditionalGroup.classIds[subclassId]) ~= nil
						end

						menu:AddSelectable(translationMap[subclassId]).OnClick = function()
							classConditionalGroup.classIds = classConditionalGroup.classIds or {}
							classConditionalGroup.classIds[subclassId] = TableUtils:CountElements(classConditionalGroup.classIds) == 0 and 100 or 0

							self:renderMutator(parent, mutator)
						end
					end

					if menu.Disabled then
						menu:SetStyle("Alpha", 0.5)
					end
				end
			end
		end
	end

	parent:AddButton("Add Class Group").OnClick = function()
		table.insert(mutator.values, {})
		self:renderMutator(parent, mutator)
	end
end
