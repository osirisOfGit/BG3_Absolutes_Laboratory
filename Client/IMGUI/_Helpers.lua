Helpers = {}

---@param ... ExtuiTreeParent
function Helpers:KillChildren(...)
	for _, parent in pairs({ ... }) do
		for _, child in pairs(parent.Children) do
			if child.UserData ~= "keep" then
				child:Destroy()
			end
		end
	end
end
