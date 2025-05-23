ItemTemplateProxy = ResourceProxy:new()

ItemTemplateProxy.fieldsToParse = {
	"ActivationGroupId",
	"AllowSummonGenericUse",
	"Amount",
	"AnubisConfigName",
	"AttackableWhenClickThrough",
	"BloodSurfaceType",
	"BloodType",
	"BookType",
	"CanBeImprovisedWeapon",
	"CanBeMoved",
	"CanBePickedUp",
	"CanBePickpocketed",
	["CombatComponent"] = {
		"Archetype",
		"CanFight",
		"CanJoinCombat",
		"CombatGroupID",
		"Faction",
		"IsBoss",
		"StartCombatRange",
		"StayInAiHints",
		"SwarmGroup",
	},
	"ConstellationConfigName",
	"ContainerAutoAddOnPickup",
	"ContainerContentFilterCondition",
	"CriticalHitType",
	"DefaultState",
	"Description",
	"DestroyWithStack",
	"Destroyed",
	"DisarmDifficultyClassID",
	"DisplayNameAlchemy",
	"Equipment",
	"ExcludeInDifficulty",
	"ForceAffectedByAura",
	"FreezeGravity",
	"GravityType",
	"Hostile",
	"Icon",
	"IgnoreGenerics",
	"InteractionFilterList",
	"InteractionFilterRequirement",
	"InteractionFilterType",
	"InventoryList",
	"InventoryType",
	"IsBlueprintDisabledByDefault",
	"IsDroppedOnDeath",
	"IsInteractionDisabled",
	"IsKey",
	"IsPlatformOwner",
	"IsPortal",
	"IsPortalProhibitedToPlayers",
	"IsPublicDomain",
	"IsSourceContainer",
	"IsSurfaceBlocker",
	"IsSurfaceCloudBlocker",
	"IsTrap",
	"ItemList",
	"Key",
	"LevelOverride",
	"LockDifficultyClassID",
	"MaxStackAmount",
	"OnUseDescription",
	"OnUsePeaceActions",
	"OnlyInDifficulty",
	"Owner",
	"PermanentWarnings",
	"ShortDescription",
	"ShortDescriptionParams",
	"ShowAttachedSpellDescriptions",
	"Stats",
	"StatusList",
	"StoryItem",
	"TechnicalDescription",
	"TechnicalDescriptionParams",
	"Tooltip",
	"TreasureLevel",
	"TreasureOnDestroy",
	"Unimportant",
	"UseOcclusion",
	"UseOnDistance",
	"UsePartyLevelForTreasureLevel",
	"UseRemotely",
}

ResourceProxy:RegisterResourceProxy("ItemTemplate", ItemTemplateProxy)
