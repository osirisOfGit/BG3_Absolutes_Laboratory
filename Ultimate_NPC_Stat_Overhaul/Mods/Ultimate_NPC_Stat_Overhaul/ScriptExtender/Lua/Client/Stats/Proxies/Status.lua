CharacterProxy = StatProxy:new()

StatProxy:RegisterStatType("StatusData", CharacterProxy)
StatProxy:RegisterStatType("DifficultyStatuses", CharacterProxy)


function CharacterProxy:buildHyperlinkedStrings(parent, statString)
	if statString and statString ~= "" then
		for statGroup in self:SplitSpring(statString) do
			-- Accounting for `STATUS_EASY: HEALTHREDUCTION_EASYMODE;` type stats
			for stat in string.gmatch(statString, "([^:]+)") do

			end
		end
	end
end
