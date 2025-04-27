ActionResourceProxy = ResourceProxy:new()
ActionResourceProxy.fieldsToParse = {
	"Description",
	"DiceType",
	"DisplayName",
	"Error",
	"IsHidden",
	"IsSpellResource",
	"MaxLevel",
	"MaxValue",
	"Name",
	"PartyActionResource",
	"ReplenishType",
	"ShowOnActionResourcePanel",
	"UpdatesSpellPowerLevel",
}


ResourceProxy:RegisterResourceProxy("resource::ActionResource", ActionResourceProxy)
