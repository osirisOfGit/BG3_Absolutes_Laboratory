---@class Object_Manager: MetaClass
---@field Object_Count integer
---@field Object_Group_Type_Info table<string, MLT_Collection_Metadata>
---@field Object_DB table<integer, MLT_Collection>
Object_Manager = _Class:Create("Object_Manager")
Object_Manager.Object_Count = 0
Object_Manager.Object_Group_Type_Info = {}
Object_Manager.Object_DB = {}

--- Sets up the object collection database and initializes the internal object count.
function Object_Manager:Start()
    self:Get_Object_DB()
	self:Initialize_Object_Count()
	self:Update_Debug_Viz_Monitor_Window()
	-- MLPrint('MazzleLib Object_Manager started. Re-calculated object count = %s',self.Object_Count)
end

--- Loads the object collection database from mod variable and sets metatable for object groups.
function Object_Manager:Get_Object_DB()
    local modVars = Ext.Vars.GetModVariables(ML_UUID)
    local config = {}
    if modVars and modVars[ML_CONSTANTS.OBJECT_DB_ID] then
        config = modVars[ML_CONSTANTS.OBJECT_DB_ID]
    end
    self.Object_DB = {}
    for collection_name, collection in pairs(config) do
        self.Object_DB[collection_name] = {}
        for i, group in pairs(collection) do
            table.insert(self.Object_DB[collection_name], group)
            setmetatable(group, Object_Group)
			-- group.visibility_locked = false
		end
    end
end

--- Saves the object collection database to mod variable.
function Object_Manager:Save_Object_DB()
    Ext.Vars.GetModVariables(ML_UUID)[ML_CONSTANTS.OBJECT_DB_ID] = self.Object_DB
end

--- Creates and initializes a new object group in an object group collection
--- @param collection_name string
--- @param group_metadata MLT_Group_Metadata
--- @param storage_character Guid?
--- @return Object_Group
function Object_Manager:Start_Object_Group(collection_name, group_metadata, storage_character)
	if (collection_name and self.Object_Group_Type_Info[collection_name]) then
		group_metadata = group_metadata or {}
		group_metadata.time_created = Ext.Timer.MonotonicTime()
		local new_group = Object_Group:New({
			object_type = self.Object_Group_Type_Info[collection_name].object_type,
			group_metadata = group_metadata,
			collection_name = collection_name,
			storage_character = storage_character and Get_GUID_For_Character(storage_character),
			object_finalization_state = {}
		})
		-- DP("Object group started.  %s objects available.  %s/%s", self:Get_Available_Object_Count(new_group), self.Object_Count, ML_Settings.ML_MaxObjects)
		return new_group
	end
	MLWarn("Mod must first register the object group type %s before creating one!", collection_name)
	return Object_Group{}
end

--- Aborts an object group and deletes all objects in the group.  (Group is not yet in its collection, so no need to delete it from there.)
--- @param object_group Object_Group
function Object_Manager:Abort_Object_Group(object_group)
	if (object_group.collection_name and self.Object_Group_Type_Info[object_group.collection_name]) then
		object_group:Release_Objects()
		DP("Object group aborted.  %s objects available.  %s/%s", self:Get_Available_Object_Count(object_group), self.Object_Count, ML_Settings.ML_MaxObjects)
	else
		MLWarn("Mod must first register the object group type %s before creating one!", object_group.collection_name)
	end
	object_group.group_metadata.time_finalize = Ext.Timer.MonotonicTime()
end

--- Finalizes an object group which saves the object group to its collection, and sets up a deletion timer_duration if necessary.
--- @param object_group Object_Group
function Object_Manager:Finalize_Object_Group(object_group)
	if (object_group.collection_name and self.Object_Group_Type_Info[object_group.collection_name]) then
		object_group.finalized = true
		object_group.group_metadata.time_finalize = Ext.Timer.MonotonicTime()
		self:Save_Object_Group(object_group)
		if (object_group.storage_character) then
			self:Delete_With_Timer_If_Necessary(object_group, object_group.storage_character)
		end
		-- DP("Object group finalized with %s objects.  %s objects available.  %s/%s", #(object_group.group_metadata.object_list), self:Get_Available_Object_Count(object_group), self.Object_Count, ML_Settings.ML_MaxObjects)
		self:Update_Debug_Viz_Monitor_Window()
	else
		MLWarn("Mod must first register the object group type %s before creating one!", object_group.collection_name)
	end
end

--- Creates an invisible helper object (or the custom template specified for the collection) and updates the internal object count.
--- This function should not be called directly.  Create an Object_Group and call Object_Group:Get_Object instead.
--- @param create_location Location
--- @param collection_name string
--- @return Guid
function Object_Manager:Get_Object_Internal(create_location, collection_name, color)
	local object_template
	if (self.Object_Group_Type_Info[collection_name].object_type == "orb") then
		object_template = Color_To_Orb_Template(color)
	else
		object_template = self.Object_Group_Type_Info[collection_name].object_type
	end
	local object = Osi.CreateAt(object_template, create_location.x, create_location.y, create_location.z, 0, 0, "")
	if (object) then
		self.Object_Count = self.Object_Count + 1
	end
	return object
end

--- Updates internal object count for externally created object added to an object set
--- This function should not be called directly.  Create an Object_Group and call Object_Group:Add_Object instead.
function Object_Manager:Add_Object_Internal(object)
	if (object) then
		self.Object_Count = self.Object_Count + 1
	end
end

--- Gets a collection from the object collection database.
--- @param collection_name string
--- @return MLT_Collection|nil
function Object_Manager:Get_Collection(collection_name)
	if (self.Object_Group_Type_Info[collection_name]) then
		return self.Object_DB[collection_name] or {}
	else
		MLWarn("Object group type %s has not been registered!", collection_name)
	end
	return nil
end

--- Returns the collection specified at index group_index.
--- @param collection_name string
--- @param group_index integer
--- @return Object_Group?
function Object_Manager:Get_Object_Group_At_Index(collection_name, group_index)
	local collection = self:Get_Collection(collection_name)
	if (collection) then
		if  (collection[group_index]) then
			return collection[group_index]
		end
	end
	return nil
end

--- @param object_group_reference MLT_Object_Group_Reference
--- @return Object_Group?
function Object_Manager:Find_Object_Group_Reference(object_group_reference)
	if (not object_group_reference) then return nil end
	local collection = self:Get_Collection(object_group_reference.collection_name)
	if (collection) then
		for _, group in ipairs(collection) do
			if (group.group_id == object_group_reference.group_id) then
				return group
			end
		end
	end
	return nil
end

--- Adds an object group to its object collection and updates internal object count.
--- @param object_group Object_Group
function Object_Manager:Save_Object_Group(object_group)
	if (self.Object_Group_Type_Info[object_group.collection_name]) then
		if (self.Object_DB[object_group.collection_name]) then
			table.insert(self.Object_DB[object_group.collection_name], object_group)
		else
			self.Object_DB[object_group.collection_name] = {object_group}
		end
		self:Save_Object_DB()
	else
		MLWarn("Object group type %s has not been registered! Not saved.", object_group.collection_name)
	end
	self:Update_MCM_Object_Count()
end

--- Replaces the collection in the object collection database with a new collection.
--- @param collection_name string
--- @param new_collection MLT_Collection
function Object_Manager:Save_Collection(collection_name, new_collection)
	-- DP("Saving %s collection %s in %s", #new_collection, collection_name, character)
	if (self.Object_Group_Type_Info[collection_name]) then
		self.Object_DB[collection_name] = new_collection
		self:Save_Object_DB()
		-- DP("Saved collection in MazzleLib mod vars entry %s.", collection_name)
	else
		MLWarn("Object group type %s has not been registered! Not saved.", collection_name)
	end
	self:Update_MCM_Object_Count()
end

--- Calls the refresh function for the specified collection, if it exists.
--- @param collection_name string
--- @param character Guid?
--- @param disable_poof boolean?
function Object_Manager:Regenerate_Collection(collection_name, character, disable_poof)
	if (collection_name and self.Object_Group_Type_Info[collection_name] and self.Object_Group_Type_Info[collection_name].refresh_function) then
		self.Object_Group_Type_Info[collection_name].refresh_function(character, disable_poof)
	end
end

--- Calls the refresh function for all collections.
--- @param character Guid?
--- @param disable_poof boolean?
function Object_Manager:Regenerate_Collections(character, disable_poof)
	for collection_name, collection_info in pairs(self.Object_Group_Type_Info) do
		if (collection_info.refresh_function) then
			self.Object_Group_Type_Info[collection_name].refresh_function(character, disable_poof)
		end
	end
end

--- Checks if there are enough objects available.  If not, it attempts to free up space by deleting older object sets if the collection is configured to allow it.
--- @param object_group Object_Group
--- @param finalized_count_estimate integer?
--- @return boolean
function Object_Manager:Check_Object_Group_Size(object_group, finalized_count_estimate)
	local available = self:Get_Available_Object_Count(object_group)
	local num_objects_needed = -1 * (available - (finalized_count_estimate or 0))
	if (num_objects_needed > 0) then
		if (self.Object_Group_Type_Info[object_group.collection_name].allow_removal_when_objects_maxed) then
			MLWarn("Object group requires %s more objects.  Need %s more objects than %s available: %s/%s.  Trying to free objects. (Object_Count = %s)", finalized_count_estimate, num_objects_needed, available, ML_Settings.ML_MaxObjects-available, ML_Settings.ML_MaxObjects, self.Object_Count)
			if (not self:Delete_Number_of_Objects(object_group.collection_name, num_objects_needed)) then
				available = self:Get_Available_Object_Count(object_group)
				num_objects_needed = -1 * (available - (finalized_count_estimate or 0))
				MLWarn("Could not free objects for new object group! Still needs %s more objects than %s available: %s/%s. (Object_Count = %s)", num_objects_needed, available, ML_Settings.ML_MaxObjects-available, ML_Settings.ML_MaxObjects, self.Object_Count)
				return false
			end
		else
			MLWarn("Object group requires %s more objects.  Need %s more objects than %s available: %s/%s.  Cannot free objects because %s is not configured to allow it.", finalized_count_estimate, num_objects_needed, available, ML_Settings.ML_MaxObjects-available, ML_Settings.ML_MaxObjects, object_group.collection_name)
			return false
		end
	end
	return true
end

--- Returns a list of all custom data stored for objects in the collection specified at index group_index.
--- @param collection_name string
--- @param group_index integer
--- @return table
function Object_Manager:Get_All_Object_Data(collection_name, group_index)
	local collection = self:Get_Collection(collection_name)
	if (collection) then
		if  (collection[group_index]) then
			return collection[group_index]:Get_All_Object_Data()
		end
	end
	return {}
end

function Object_Manager:Set_Other_Groups_Offstage_For_Character(collection_name, character, desired_on_stage, toggle_instead, group_filter)
	local collection = self:Get_Collection(collection_name)
	if (collection) then
		for _, group in ipairs(collection) do
			if not (group_filter and not group_filter(group)) then
				if (group.storage_character ~= character) then
					if (toggle_instead) then
						-- DP("Toggling visibility of group %s of collection %s offstage", group.group_id, collection_name)
						group:Toggle_Visibility()
					else
						-- DP("Setting visibility of group %s of collection %s to %s", group.group_id, collection_name, desired_on_stage)
						group:Set_Visibility(desired_on_stage)
					end
				end
			end
		end
	end
end

function Object_Manager:Set_Groups_Offstage_For_Character(collection_name, character, desired_on_stage, toggle_instead, group_filter)
	local collection = self:Get_Collection(collection_name)
	if (collection) then
		for _, group in ipairs(collection) do
			if not (group_filter and not group_filter(group)) then
				if (group.storage_character == character) then
					if (toggle_instead) then
						-- DP("Toggling visibility of group %s of collection %s", group.group_id, collection_name)
						group:Toggle_Visibility()
					else
						-- DP("Setting visibility of group %s of collection %s to %s", group.group_id, collection_name, desired_on_stage)
						group:Set_Visibility(desired_on_stage)
					end
				end
			end
		end
	end
end

function Object_Manager:Set_All_Groups_Offstage(collection_name, desired_on_stage, toggle_instead, group_filter)
	local collection = self:Get_Collection(collection_name)
	if (collection) then
		for _, group in ipairs(collection) do
			if not (group_filter and not group_filter(group)) then
				if (toggle_instead) then
					-- DP("Toggling visibility of group %s of collection %s", group.group_id, collection_name)
					group:Toggle_Visibility()
				else
					-- DP("Setting visibility of group %s of collection %s to %s", group.group_id, collection_name, desired_on_stage)
					group:Set_Visibility(desired_on_stage)
				end
			end
		end
	end
end

function Object_Manager:Set_Visibility_Lock_For_Character(character, lock_value, toggle_instead, is_temporary_lock)
	local final_visibility
	local changed_visibility = false
	for _, collection_info in pairs(self.Object_Group_Type_Info) do
		local collection = self:Get_Collection(collection_info.collection_name)
		if (collection) then
			for _, group in pairs(collection) do
				if (group.storage_character == character) then
					if (is_temporary_lock) then
						group:Set_Temporary_Visibility_Lock(lock_value)
					else
						if (toggle_instead) then
							local is_viz_locked = group.visibility_locked or false
							group.visibility_locked = not is_viz_locked or nil
						else
							group.visibility_locked = lock_value or false
						end
						if (not group:Set_Visibility(group.visibility_locked and true or false)) then
							Object_Manager:Update_Debug_Viz_Monitor_Window()
						end
					end
					final_visibility = (group.visibility_locked or group.temp_visibility_locked) and true or false
					changed_visibility = true
				end
			end
		end
	end
	if (changed_visibility) then
		self:Save_Object_DB()
	end
	return final_visibility
end

--- @param collection_name string
--- @param character Guid
--- @return boolean, boolean, integer
function Object_Manager:Has_Visualization_In_Collection(collection_name, character, do_not_include_enemies)
	local collection = self:Get_Collection(collection_name)
	local has_onstage_viz, has_offstage_viz = false, false
	if (collection) then
		for _, group in ipairs(collection) do
			if (group.storage_character == character) and (not do_not_include_enemies or not group.group_metadata.is_enemy_viz) then
				has_onstage_viz = has_onstage_viz or group.on_stage
				has_offstage_viz = has_offstage_viz or not group.on_stage
			end
		end
		return has_onstage_viz, has_offstage_viz, #collection
	end
	return false, false, 0
end

-- Checks all collections and returns true if a collection with multiple groups has group where character is target
--- @param character Guid
--- @return boolean, boolean, integer
function Object_Manager:Has_Visualization(character, do_not_include_enemies)
	local largest_collection_size = 0
	local has_onstage_viz, has_offstage_viz = false, false
	for _, collection_info in pairs(self.Object_Group_Type_Info) do
		local collection_has_onstage_viz, collection_has_offstage_viz, num_groups = self:Has_Visualization_In_Collection(collection_info.collection_name, character, do_not_include_enemies)
		has_onstage_viz = has_onstage_viz or collection_has_onstage_viz
		has_offstage_viz = has_offstage_viz or collection_has_offstage_viz
		if (num_groups > largest_collection_size) then
			largest_collection_size = num_groups
		end
	end
	return has_onstage_viz, has_offstage_viz, largest_collection_size
end

--- @param collection_name string
--- @return table<Guid, integer>
--- @return table
function Object_Manager:Get_Characters_In_Collection(collection_name, characters, group_info, do_not_include_enemies)
	characters = characters or {}
	group_info = group_info or {}
	local collection = self:Get_Collection(collection_name)
	if (collection) then
		for _, group in ipairs(collection) do
			if (not do_not_include_enemies or not group.group_metadata.is_enemy_viz) then
				characters[group.storage_character] = (characters[group.storage_character] or 0) + 1
				local new_group_info = {
					group_id = group.group_id,
					on_stage = (group.on_stage == true) and "Yes" or "No",
					visibility_locked = (group.visibility_locked == true) and "Yes" or "No",
					temp_visibility_locked = (group.temp_visibility_locked == true) and "Yes" or "No",
					collection_name = collection_name,
					name = group.group_metadata.custom_name or group.group_metadata.name or group.group_metadata.spell or "Unnamed",
					num_objects = #(group.group_metadata.object_list),
					target = GetCharName(group.storage_character)
				}
				table.insert(group_info, new_group_info)
			end
		end
	end
	return characters, group_info
end

--- @param collection_name string
--- @param character Guid
--- @return Object_Group?
function Object_Manager:Get_First_Visualization_In_Collection(collection_name, character)
	local collection = self:Get_Collection(collection_name)
	if (collection) then
		for _, group in ipairs(collection) do
			if (group.storage_character == character) then
				return group
			end
		end
	end
end

-- TODO: Don't leave this enabled.  Just for debugging.
function Object_Manager:Update_Debug_Viz_Monitor_Window()
    if (Mods.RangeFinder and Mods.RangeFinder.RFSettings.RF_Show_Viz_Monitor) then
        local characters, groups = self:Get_Characters_In_Collection(ML_CONSTANTS.RF_VIZ_TYPE)
        characters, groups = self:Get_Characters_In_Collection(ML_CONSTANTS.RF_PATH_VIZ_TYPE, characters, groups)
        local entity = _C() --[[@as EntityHandle]]
        local current_character = entity and entity.Uuid and entity.Uuid.EntityUuid
        local viz_character_text = ""
        for char, viz_count in pairs(characters) do
			local char_entity = Ext.Entity.Get(char)
			local dist = (char_entity and entity and Map:Get_Distance_EE(entity, char_entity)) or -1
            viz_character_text = viz_character_text .. string.format("%s  (%.1f m): %s\n", GetCharName(char), dist, viz_count)
        end
        Ext.Net.BroadcastMessage("RF_Update_Debug_Viz_Monitor_Window", Ext.Json.Stringify({
            group_count = Object_Manager:Get_Group_Count(ML_CONSTANTS.RF_VIZ_TYPE), 
			locked = Mods.RangeFinder.Range_Finder.Internal_Vars.viz_visibility,
            viz_character_text = viz_character_text, 
            viz_list = groups
        }))
    end
end