ClassDescriptionProxy = ResourceProxy:new()
ClassDescriptionProxy.fieldsToParse = {
	"AnimationSetPriority",
	"BaseHp",
	"CanLearnSpells",
	"CharacterCreationPose",
	"ClassEquipment",
	"ClassHotbarColumns",
	"CommonHotbarColumns",
	"Description",
	"DisplayName",
	"HasGod",
	"HpPerLevel",
	"IsDefaultForUseSpellAction",
	"ItemsHotbarColumns",
	"LearningStrategy",
	"MulticlassSpellcasterModifier",
	"MustPrepareSpells",
	"Name",
	"ParentGuid",
	"PrimaryAbility",
	"ProgressionTableUUID",
	"SomaticEquipmentSet",
	"SoundClassType",
	"SpellCastingAbility",
	"SpellList",
	"SubclassTitle",
	"Tags"
}


ResourceProxy:RegisterResourceProxy("resource::ClassDescription", ClassDescriptionProxy)
ResourceProxy:RegisterResourceProxy("ClassUUID", ClassDescriptionProxy)
ResourceProxy:RegisterResourceProxy("SubClassUUID", ClassDescriptionProxy)

function ClassDescriptionProxy:RenderDisplayableValue(parent, resourceValue)
	---@type ResourceClassDescription
	local class = Ext.StaticData.Get(resourceValue, "ClassDescription")

	if class then
		Styler:HyperlinkText(parent, class.DisplayName:Get() or class.Name, function(parent)
			ResourceManager:RenderDisplayWindow(class, parent)
		end)
	else
		parent:AddText(resourceValue .. " - UNKNOWN CLASS")
	end
end
