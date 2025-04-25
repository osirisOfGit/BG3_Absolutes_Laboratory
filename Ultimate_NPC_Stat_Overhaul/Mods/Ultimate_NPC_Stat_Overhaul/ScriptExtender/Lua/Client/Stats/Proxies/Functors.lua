FunctorsProxy = StatProxy:new()

FunctorsProxy.fieldsToParse = {
}

StatProxy:RegisterStatType("StatsFunctors", FunctorsProxy)

---@param functors StatsFunctors
function FunctorsProxy:buildHyperlinkedStrings(parent, functors)
	if functors and functors ~= "" then
		for _, functor in ipairs(functors.FunctorList) do
			if functor.TypeId == "ApplyStatus" then
				local functorString = string.format("%s(%s, %s,%s,%s,%s)")

			elseif functor.TypeId == "RemoveStatus" then
			else
				parent:AddText(string.format("TypeId: %s, NOT MAPPED"), tostring(functor.TypeId))
			end
		end
	end
end
