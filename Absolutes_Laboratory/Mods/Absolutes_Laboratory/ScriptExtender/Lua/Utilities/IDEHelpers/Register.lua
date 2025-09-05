--- Sets up the parameters for a collection of object groups
--- @param collection_name string
--- @param object_type string
--- @param parameters MLT_Collection_Metadata?
function Object_Manager:Register_Collection(collection_name, object_type, parameters)
	if (collection_name) then
		self.Object_Group_Type_Info[collection_name] = {
			collection_name = collection_name,
			object_type = object_type or "orb",
			allow_timer_removal = false,
			allow_faraway_removal = false,
			allow_single_group_per_character_removal = false,
			allow_single_group_per_target_removal = false,
			allow_single_group_per_party_removal = false,
			allow_clear_removal = true,
			allow_removal_when_objects_maxed = true,
			allow_end_of_turn_removal = false,
			allow_thinning = false,
			allow_level_unload = true,
			allow_manual_removal = true,
			poof_on_delete = true,
			timer_duration = 2,
			faraway_distance = 60,
			thinning_separation = 0.4,
			refresh_function = false,
			duplicate_function = false,
			delete_callback = false
		}
		if (parameters) then
			self:Process_Parameters(collection_name, parameters)
		end
		-- DP("MazzleLib's ObjectManager registered collection %s.", collection_name)
	end
end

--- Prints the parameters of all object group collections that are registered
function Object_Manager:Print_Collection_Registrations()
	MLPrint("Collection Name         Type  Refresh   Dupe   Timer  Faraway   1Char 1Target Party  Clear  MaxClear  EoTurn   Thin   Manual   Poof")
	for name, info in pairs(self.Object_Group_Type_Info) do
		MLPrint("%-23s %-10s %-9s %-6s %-6s %-6s %-9s %-6s %-6s %-6s %-9s %-8s %-6s %-6s %-6s",
		info.collection_name, info.object_type, info.refresh_function ~= nil, info.duplicate_function ~= nil, info.allow_timer_removal, 
		info.allow_faraway_removal, info.allow_single_group_per_character_removal, info.allow_single_group_per_target_removal, info.allow_single_group_per_party_removal, 
		info.allow_clear_removal, info.allow_removal_when_objects_maxed, info.allow_end_of_turn_removal, info.allow_thinning, info.allow_manual_removal, info.poof_on_delete)
	end
end

--- Gets current setting for a collection parameter
--- @param collection_name string
--- @param setting string
function Object_Manager:Get_Parameter_Setting(collection_name, setting)
	if (collection_name and self.Object_Group_Type_Info[collection_name]) then
		return self.Object_Group_Type_Info[collection_name][setting] 
	end
	MLWarn("Cannot check setting.  %s is not a valid collection.", collection_name)
	assert(false)
	return false
end

--- Sets the parameters of a collection based on a table of parameters
--- @param collection_name string
--- @param parameters MLT_Collection_Metadata
function Object_Manager:Process_Parameters(collection_name, parameters)
	for parameter_name, parameter_value in pairs (parameters) do
		self:Register_Parameter(collection_name, parameter_name, parameter_value)
	end
end

--- Sets a parameter for a collection
--- @param collection_name string
--- @param parameter_name string
--- @param parameter_value any
function Object_Manager:Register_Parameter(collection_name, parameter_name, parameter_value)
	if (not collection_name or not self.Object_Group_Type_Info[collection_name]) then
		MLWarn("Cannot register a parameter for an unregistered collection %s!", collection_name)
		return
	end
	if (self.Object_Group_Type_Info[collection_name][parameter_name] ~= nil) then
		self.Object_Group_Type_Info[collection_name][parameter_name] = parameter_value
	else
		MLWarn("Invalid parameter registration! Parameter %s is not a valid parameter for %s.", parameter_name, collection_name)
	end
end

--- Returns true if the collection's deletion-related parameter allows that form of deletion
--- @param collection_name string
--- @param parameter_name string
--- @return boolean
function Object_Manager:Collection_Allows_Deletion_Type(collection_name, parameter_name)
	if (collection_name and self.Object_Group_Type_Info[collection_name]) then
		return self.Object_Group_Type_Info[collection_name][parameter_name]
	else
		MLWarn("Collection %s is unregistered!", collection_name)
	end
	return true
end

--- Sets the function to call to regenerate the object sets in the collection when the Refresh spell is cast
--- @param collection_name string
--- @param refresh_function function
function Object_Manager:Set_Refresh_Function(collection_name, refresh_function)
	self:Register_Parameter(collection_name, "refresh_function", refresh_function)
end

--- Sets the function that checks if two object groups have the same values in their group metadata 
--- @param collection_name string
--- @param duplicate_function function
function Object_Manager:Set_Duplicate_Function(collection_name, duplicate_function)
	self:Register_Parameter(collection_name, "duplicate_function", duplicate_function)
end

--- Sets the function that checks if two object groups have the same values in their group metadata 
--- @param collection_name string
--- @param delete_callback function
function Object_Manager:Set_Delete_Callback(collection_name, delete_callback)
	self:Register_Parameter(collection_name, "delete_callback", delete_callback)
end

--- Sets whether new objects sets created should be removed when a timer expires
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Timer_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_timer_removal", is_allowed)
end

--- Sets whether objects sets should be deleted when they are too far away from the player
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Faraway_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_faraway_removal", is_allowed)
end

--- Sets whether objects sets should be deleted at the end of a turn (in combat)
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_End_Of_Turn_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_end_of_turn_removal", is_allowed)
end

--- Sets whether a character can only have one object set associated with them.  (Previous ones will be deleted when a new object set is created for that character.)
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Single_Group_Per_Character_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_single_group_per_character_removal", is_allowed)
end

--- Sets whether a character can only have one object set associated with them.  (Previous ones will be deleted when a new object set is created for that character.)
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Single_Target_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_single_group_per_target_removal", is_allowed)
end


--- Sets whether a party can only have one object set associated with any of their characters.  (Previous objects sets will be deleted when a new one is created for any party member.)
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Single_Group_Per_Party_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_single_group_per_party_removal", is_allowed)
end

--- Sets whether MazzleLib's Clear spell will delete the object sets in this collection.
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Clear_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_clear_removal", is_allowed)
end

--- Sets whether older objects can be deleted to make room for new ones when the maximum number of objects is reached
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Max_Objects_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_removal_when_objects_maxed", is_allowed)
end

--- Sets whether objects will skip creation of any new objects if they would be too close to the last object created.
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Thinning(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_thinning", is_allowed)
end

--- Sets whether objects can be deleted by using the 'Clear' spell and clicking on an object in the collection.
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Manual_Removal(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_manual_removal", is_allowed)
end

--- Sets whether objects can be deleted when the level is unloaded
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Allow_Level_Unload(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "allow_level_unload", is_allowed)
end

--- Sets the distance at which object groups will be deleted if they are too far away from the player.  allow_faraway_removal must be enabled.
--- @param collection_name string
--- @param value number
function Object_Manager:Set_Faraway_Distance(collection_name, value)
	self:Register_Parameter(collection_name, "faraway_distance", value)
end

--- Sets how long object groups will exist before being deleted by a timer.  allow_timer_removal must be enabled.
--- @param collection_name string
--- @param value number
function Object_Manager:Set_Timer_Duration(collection_name, value)
	self:Register_Parameter(collection_name, "timer_duration", value)
end
--- Sets the minimum distance between objects created.  allow_thinning must be enabled.
--- @param collection_name string
--- @param value number
function Object_Manager:Set_Thinning_Separation(collection_name, value)
	self:Register_Parameter(collection_name, "thinning_separation", value)
end

--- Sets whether deleted objects have a chance to poof when they are removed
--- @param collection_name string
--- @param is_allowed boolean
function Object_Manager:Set_Poof_On_Delete(collection_name, is_allowed)
	self:Register_Parameter(collection_name, "poof_on_delete", is_allowed)
end