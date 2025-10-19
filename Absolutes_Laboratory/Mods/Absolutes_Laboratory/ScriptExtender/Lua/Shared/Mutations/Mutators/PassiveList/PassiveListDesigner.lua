Ext.Require("Client/Mutations/ListDesignerBaseClass.lua")

---@class PassiveListDesigner : ListDesignerBaseClass
PassiveListDesigner = ListDesignerBaseClass:new("Passive List",
	"passiveLists",
	{ "startOfCombatOnly", "onLoadOnly", "onDeathOnly" })

function PassiveListDesigner:buildBrowser()
	if not self.browserTabs["PassiveData"] then
		self.browserTabs["PassiveData"] = self.browserTabParent:AddTabItem("Passives"):AddChildWindow("Passive Browser")
		self.browserTabs["PassiveData"].NoSavedSettings = true
	end

	self:buildLiteProgressionBrowser()
	self:buildStatBrowser("PassiveData")
end

function PassiveListDesigner:customizeDesigner(parent)
	Styler:CheapTextAlign("Linked Spell Lists ( ? )", parent):Tooltip():AddText("\t Spell Lists linked here will be automatically used as dependencies for Passive List Mutators")
	local linkedSpellListsTable = parent:AddTable("LinkedSpellLists", 1)
	linkedSpellListsTable.BordersOuter = true
	linkedSpellListsTable.SizingFixedFit = true

	local function buildTable()
		Helpers:KillChildren(linkedSpellListsTable)

		for s, spellListId in ipairs(self.activeList.spellListDependencies or {}) do
			local spellList = MutationConfigurationProxy.lists.spellLists[spellListId]
			if spellList then
				local cell = linkedSpellListsTable:AddRow():AddCell()

				local delete = Styler:ImageButton(cell:AddImageButton("delete" .. spellList.name, "ico_red_x", { 16, 16 }))
				delete.Disabled = self.activeList.modId ~= nil
				delete.OnClick = function()
					for x = s, TableUtils:CountElements(self.activeList.spellListDependencies) do
						self.activeList.spellListDependencies[x] = nil
						self.activeList.spellListDependencies[x] = TableUtils:DeeplyCopyTable(self.activeList.spellListDependencies._real[x + 1])
					end
					buildTable()
				end

				local link = cell:AddTextLink(spellList.name .. (spellList.modId and string.format(" (from %s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""))
				link.Font = "Small"
				link.SameLine = true
				link.OnClick = function()
					SpellListDesigner:launch(spellListId)
				end
			end
		end
	end
	buildTable()

	local addDependencyButton = parent:AddButton("Add Spell List Dependency")
	addDependencyButton.Font = "Small"
	addDependencyButton.Disabled = self.activeList.modId ~= nil
	addDependencyButton.OnClick = function()
		Helpers:KillChildren(self.popup)
		self.popup:Open()

		Styler:BuildCompleteUserAndModLists(self.popup,
			function(config)
				return config.lists and config.lists.spellLists and next(config.lists.spellLists) and config.lists.spellLists
			end,
			function(key, value)
				return value.name
			end,
			function(key, listItem)
				return self.activeList.useGameLevel == listItem.useGameLevel
			end,
			function(select, id, item)
				select.Label = item.name
				select.Selected = TableUtils:IndexOf(self.activeList.spellListDependencies, id) ~= nil

				select.OnClick = function()
					if not select.Selected then
						self.activeList.spellListDependencies[TableUtils:IndexOf(self.activeList.spellListDependencies, id)] = nil
						TableUtils:ReindexNumericTable(self.activeList.spellListDependencies)
					else
						self.activeList.spellListDependencies = self.activeList.spellListDependencies or {}
						self.activeList.spellListDependencies[#self.activeList.spellListDependencies + 1] = id
					end

					buildTable()
				end
			end)
	end
end
