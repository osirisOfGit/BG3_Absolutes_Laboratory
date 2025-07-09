Ext.Require("Client/Mutations/ListDesignerBaseClass.lua")

---@class PassiveListDesigner : ListDesignerBaseClass
PassiveListDesigner = ListDesignerBaseClass:new("Passive List",
	"passiveLists",
	{ "PassivePrototypesAdded", "PassivePrototypesRemoved", "PassivesAdded", "PassivesRemoved" },
	---@param passiveMeta ResourceProgressionPassive|StatsPassivePrototype
	function(passiveMeta, addToListFunc)
		if type(passiveMeta) == "string" then
			addToListFunc(passiveMeta)
		elseif Ext.Types.GetObjectType(passiveMeta) == "resource::ProgressionPassive" then
			---@type ResourcePassiveList
			local progSpellList = Ext.StaticData.Get(passiveMeta.UUID, "PassiveList")

			for _, spellName in pairs(progSpellList.Passives) do
				addToListFunc(spellName)
			end
		else
			addToListFunc(passiveMeta.Name)
		end
	end)

function PassiveListDesigner:buildBrowser()
	if not SpellListDesigner.browserTabs["PassiveData"] then
		self.browserTabs["PassiveData"] = self.browserTabParent:AddTabItem("Passives"):AddChildWindow("Passive Browser")
		self.browserTabs["PassiveData"].NoSavedSettings = true
	end

	self:buildProgressionBrowser()
	self:buildStatBrowser("PassiveData")
end
