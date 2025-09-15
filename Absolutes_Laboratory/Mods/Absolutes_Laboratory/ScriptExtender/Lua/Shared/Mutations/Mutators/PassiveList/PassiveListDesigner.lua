Ext.Require("Client/Mutations/ListDesignerBaseClass.lua")

---@class PassiveListDesigner : ListDesignerBaseClass
PassiveListDesigner = ListDesignerBaseClass:new("Passive List",
	"passiveLists",
	{ "startOfCombatOnly", "onLoadOnly", "onDeathOnly" },
	{ "PassivePrototypesAdded", "PassivePrototypesRemoved", "PassivesAdded", "PassivesRemoved" },
	---@param passiveMeta ResourceProgressionPassive|StatsPassivePrototype
	function(passiveMeta, addToListFunc)
		if type(passiveMeta) == "string" then
			addToListFunc(passiveMeta)
		elseif Ext.Types.GetObjectType(passiveMeta) == "resource::ProgressionPassive" then
			---@type ResourcePassiveList
			local progSpellList = Ext.StaticData.Get(passiveMeta.UUID, "PassiveList")

			if progSpellList then
				for _, spellName in pairs(progSpellList.Passives) do
					addToListFunc(spellName)
				end
			else
				error(string.format("UUID %s is not a valid PassiveList", passiveMeta.UUID))
			end
		else
			addToListFunc(passiveMeta.Name)
		end
	end)

PassiveListDesigner.progressNodeTranslations = {
	["PassivePrototypesAdded"] = "PassivesAdded",
	["PassivePrototypesRemoved"] = "PassivesRemoved"
}

function PassiveListDesigner:buildBrowser()
	if not self.browserTabs["PassiveData"] then
		self.browserTabs["PassiveData"] = self.browserTabParent:AddTabItem("Passives"):AddChildWindow("Passive Browser")
		self.browserTabs["PassiveData"].NoSavedSettings = true
	end

	self:buildProgressionBrowser()
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
			local spellList = MutationConfigurationProxy.spellLists[spellListId]
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
	buildTable()

	local addDependencyButton = parent:AddButton("Add Spell List Dependency")
	addDependencyButton.Font = "Small"
	addDependencyButton.Disabled = self.activeList.modId ~= nil
	addDependencyButton.OnClick = function()
		Helpers:KillChildren(self.popup)
		self.popup:Open()

		for spellListId, spellList in pairs(MutationConfigurationProxy.spellLists) do
			if spellList.useGameLevel == self.activeList.useGameLevel then
				---@type ExtuiSelectable
				local select = self.popup:AddSelectable(spellList.name .. (spellList.modId and string.format(" (from %s)", Ext.Mod.GetMod(spellList.modId).Info.Name) or ""),
					"DontClosePopups")
				select.Selected = TableUtils:IndexOf(self.activeList.spellListDependencies, spellListId) ~= nil

				select.OnClick = function()
					if not select.Selected then
						self.activeList.spellListDependencies[TableUtils:IndexOf(self.activeList.spellListDependencies, spellListId)] = nil
						TableUtils:ReindexNumericTable(self.activeList.spellListDependencies)
					else
						self.activeList.spellListDependencies = self.activeList.spellListDependencies or {}
						self.activeList.spellListDependencies[#self.activeList.spellListDependencies + 1] = spellListId
					end

					buildTable()
				end
			end
		end
	end
end
