EntityHandleProxy = EntityProxy:new()
EntityHandleProxy.fieldsToParse = {
	"ActionResources",
	"AddedSpells",
	"AttitudesToPlayers",
	"AttributeFlags",
	"AvailableLevel",
	"BaseHp",
	"BaseStats",
	"BoostsContainer",
	"CanBeDisarmed",
	"CanBeLooted",
	"Classes",
	"CombatParticipant",
	"Concentration",
	"DifficultyCheck",
	"DisplayName",
	"DualWielding",
	"EocLevel",
	"Expertise",
	"Faction",
	"FleeCapability",
	"HealBlock",
	"Health",
	"Hearing",
	"InterruptContainer",
	"InterruptPreferences",
	"Invisibility",
	"LearnedSpells",
	"LevelUp",
	"Loot",
	"Movement",
	"ObjectInteraction",
	"OriginalTemplate",
	"PassiveContainer",
	"Proficiency",
	"ProgressionContainer",
	"Race",
	"Resistances",
	"ServerAiArchetype",
	"ServerAnubisTag",
	"ServerBaseProficiency",
	"ServerBaseStats",
	"ServerBoostBase",
	"ServerBoostTag",
	"ServerCanStartCombat",
	"ServerDelayDeathCause",
	"ServerPassiveBase",
	"ServerPassivePersistentData",
	"ServerPickpocket",
	"ServerShapeshiftStates",
	"ShapeshiftHealthReservation",
	"SpellAiConditions",
	"SpellBook",
	"SpellBookCooldowns",
	"SpellBookPrepares",
	"SpellCastCanBeTargeted",
	"SpellContainer",
	"Stats",
	"StatusImmunities",
	"SurfacePathInfluences",
	"Tag",
	"Uuid",
	"WeaponSet"
}


EntityProxy:RegisterResourceProxy("Entity", EntityHandleProxy)

---@param entity EntityHandle
function EntityHandleProxy:RenderDisplayWindow(entity, parent)
	EntityProxy.entityId = entity.Uuid.EntityUuid

	Channels.GetEntityDump:RequestToServer({
		entity = entity.Uuid.EntityUuid,
		fields = self.fieldsToParse
	}, function(data)
		local displayTable = Styler:TwoColumnTable(parent, entity.Uuid.EntityUuid)
		for key, value in TableUtils:OrderedPairs(data) do
			local row = displayTable:AddRow()
			row:AddCell():AddText(key)
			local valueCell = row:AddCell()
			EntityManager:RenderDisplayableValue(valueCell, value, key)
			if #valueCell.Children == 0 then
				row:Destroy()
			end
		end
	end)
end
