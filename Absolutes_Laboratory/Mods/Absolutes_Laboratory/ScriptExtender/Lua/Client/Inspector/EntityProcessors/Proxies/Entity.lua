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
	"StatusContainer",
	"StatusImmunities",
	"SurfacePathInfluences",
	"Tag",
	"Uuid",
	"WeaponSet"
}


EntityProxy:RegisterResourceProxy("Entity", EntityHandleProxy)
EntityProxy:RegisterResourceProxy("ItemEntity", EntityHandleProxy)
EntityProxy:RegisterResourceProxy("Owner", EntityHandleProxy)

---@param entity EntityHandle
function EntityHandleProxy:RenderDisplayWindow(entity, parent)
	if entity then
		Channels.GetEntityDump:RequestToServer({
			entity = entity.Uuid.EntityUuid,
			fields = self.fieldsToParse
		}, function(data)
			EntityProxy.entityId = entity.Uuid.EntityUuid

			local displayTable = Styler:TwoColumnTable(parent, EntityProxy.entityId)
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
end

function EntityHandleProxy:RenderDisplayableValue(parent, entityId, resourceType)
	-- Stopping recursion
	if entityId ~= EntityProxy.entityId then
		Styler:HyperlinkText(parent, entityId, function(parent)
			EntityHandleProxy:RenderDisplayWindow(Ext.Entity.Get(entityId), parent:Tooltip())
		end)
	else
		parent:AddText("SELF - " .. entityId)
	end
end
