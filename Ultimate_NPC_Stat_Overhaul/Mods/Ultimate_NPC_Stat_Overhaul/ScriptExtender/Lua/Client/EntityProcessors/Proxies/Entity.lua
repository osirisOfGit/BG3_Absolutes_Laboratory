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
	"Bound",
	"CanBeDisarmed",
	"CanBeLooted",
	"CanBeWielded",
	"CanDeflectProjectiles",
	"CanDoActions",
	"CanEnterChasm",
	"CanInteract",
	"CanModifyHealth",
	"CanMove",
	"CanSeeThrough",
	"CanSense",
	"CanSpeak",
	"CanTravel",
	"Classes",
	"CombatParticipant",
	"Concentration",
	"Data",
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
	"Icon",
	"InterruptContainer",
	"InterruptPreferences",
	"Invisibility",
	"LearnedSpells",
	"Level",
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
	"ServerBaseData",
	"ServerBaseProficiency",
	"ServerBaseSize",
	"ServerBaseStats",
	"ServerBoostBase",
	"ServerBoostTag",
	"ServerCanStartCombat",
	"ServerDelayDeathCause",
	"ServerOsirisTag",
	"ServerPassiveBase",
	"ServerPassivePersistentData",
	"ServerPickpocket",
	"ServerRaceTag",
	"ServerReplicationDependencyOwner",
	"ServerShapeshiftStates",
	"ServerStatusDifficultyModifiers",
	"ServerTemplateTag",
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
	"WeaponSet"
}


EntityProxy:RegisterResourceProxy("Entity", EntityHandleProxy)

---@param entity EntityHandle
function EntityProxy:RenderDisplayWindow(entity, parent)
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
