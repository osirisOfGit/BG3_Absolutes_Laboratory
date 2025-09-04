---@class Mazzle_Orbs: MetaClass
Mazzle_Orbs = _Class:Create("Mazzle_Orbs")
Mazzle_Orbs.current_color = 0

--- Returns the next color.  Used for selecting a different color for different visualizations or to create the Christmas Lights coloring.
--- @return string
function Mazzle_Orbs:Get_Next_Color()
	self.current_color = self.current_color + 1
	if (self.current_color > #ML_CONSTANTS.ORB_COLORS) then
		self.current_color = 1
	end
	return ML_CONSTANTS.ORB_COLORS[self.current_color]
end

--- Creates an orb with a specific color.  If no color is provided, it will use the next color in the list.
--- This is meant to be used with the invisible orb objects that the Object Manager creates.
--- @param object Guid
--- @param color? string
function Mazzle_Orbs:Make_Object_Colored_Orb(object, color)
	local current_color
	if (not color or (color == "Christmas Lights") or (color == "any")) then
		current_color = self:Get_Next_Color()
	else
		current_color = color
	end
	if (current_color == "Black") then current_color = "Gray" end
	Osi.ApplyStatus(object,"ML_VFX_Orb_"..current_color, -1.0, 1)
end

--- Recolors an orb object to a specific color.
--- @param object Guid
--- @param color string?
function Mazzle_Orbs:ReColor_Orb(object, color, add_extra_white)
	for _,c in ipairs(ML_CONSTANTS.ORB_COLORS) do
		Osi.RemoveStatus(object, "ML_VFX_Orb_" .. c)		
	end
	if (color) then
		self:Make_Object_Colored_Orb(object, color)
		if (add_extra_white) then
			self:Make_Object_Colored_Orb(object, "White")
		end
	end
end

--- Adds a visual effect to an object.  This is used for adding the moonbeam or red disc VFX to objects.
--- @param object Guid
--- @param vfx_name "moonbeam"|"moonbeam_white"|"moonbeam_red"|"moonbeam_gold"|"moonbeam_blue"|"moonbeam_green"|"red_disc"|"gold_aura"|"white_fire"|"chest_beam"?
--- @param vfx_duration number?
function Mazzle_Orbs:Add_VFX_to_Object(object, vfx_name, vfx_duration)
	if (not object or not vfx_name) then return end
	local status_effect_name
	if (vfx_name == "moonbeam") then
		status_effect_name = "ML_VFX_Moonbeam"
	elseif (vfx_name == "moonbeam_white") then
		status_effect_name = "ML_VFX_Moonbeam_White"
	elseif (vfx_name == "moonbeam_red") then
		status_effect_name = "ML_VFX_Moonbeam_Red"
	elseif (vfx_name == "moonbeam_gold") then
		status_effect_name = "ML_VFX_Moonbeam_Gold"
	elseif (vfx_name == "moonbeam_blue") then
		status_effect_name = "ML_VFX_Moonbeam_Blue"
	elseif (vfx_name == "moonbeam_green") then
		status_effect_name = "ML_VFX_Moonbeam_Green"
	elseif (vfx_name == "gold_aura") then
		status_effect_name = "ML_VFX_Gold_Aura"
	elseif (vfx_name == "silver_aura") then
		status_effect_name = "ML_VFX_SilverOrb_Aura"
	elseif (vfx_name == "invisible") then
		status_effect_name = "ML_VFX_Invisible"
	elseif (vfx_name == "white_fire") then
		status_effect_name = "ML_VFX_White_Fire"
	elseif (vfx_name == "chest_beam") then
		status_effect_name = "ML_VFX_Chest_Beam_Out"
	elseif (vfx_name == "red_disc") then
		status_effect_name = "ML_Show_Radius2"
	end
	if (status_effect_name) then
		Osi.ApplyStatus(object, status_effect_name, vfx_duration or -1.0, 1)
	end
end

--- Removes one of our visual effects from an object.
--- @param object Guid
--- @param vfx_name "moonbeam"|"moonbeam_white"|"moonbeam_red"|"moonbeam_gold"|"moonbeam_blue"|"moonbeam_green"|"red_disc"|"gold_aura"|"white_fire"|"chest_beam"|"all"?
function Mazzle_Orbs:Remove_VFX_from_Object(object, vfx_name)
	if (not object or not vfx_name) then return end
	vfx_name = vfx_name or "all"
	if (vfx_name == "moonbeam") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Moonbeam")
	end
	if (vfx_name == "moonbeam_red") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Moonbeam_Red")
	end
	if (vfx_name == "moonbeam_white") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Moonbeam_White")
	end
	if (vfx_name == "moonbeam_gold") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Moonbeam_Gold")
	end
	if (vfx_name == "moonbeam_blue") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Moonbeam_Blue")
	end
	if (vfx_name == "moonbeam_green") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Moonbeam_Green")
	end
	if (vfx_name == "gold_aura") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Gold_Aura")
	end
	if (vfx_name == "silver_aura") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_SilverOrb_Aura")
	end
	if (vfx_name == "invisible") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Invisible")
	end
	if (vfx_name == "white_fire") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_White_Fire")
	end
	if (vfx_name == "chest_beam") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_VFX_Chest_Beam_Out")
	end
	if (vfx_name == "red_disc") or (vfx_name == "all") then
		Osi.RemoveStatus(object, "ML_Show_Radius2")
	end
	for _,c in ipairs(ML_CONSTANTS.ORB_COLORS) do
		if (vfx_name == c) or (vfx_name == "all") then
			Osi.RemoveStatus(object, "ML_VFX_Orb_" .. c)
		end
	end
end

local should_use_secondary_color = false
function Mazzle_Orbs:Connect_Orbs(orb1, orb2, color, secondary_color)
	if (secondary_color) then
		if (should_use_secondary_color) then
			should_use_secondary_color = false
			color = secondary_color
		else
			should_use_secondary_color = true
			color = color or "White"
		end
	else
		color = color or "White"
	end
	if (color == "Black") then color = "Gray" end
	Osi.ApplyStatus(orb1, "ML_"..color.."_Laser", -1, 1, orb2)
	-- local fxHandle = Osi.PlayLoopBeamEffect(orb1, orb2,"42c757f2-52e3-6002-f0d3-9f743d4a24e8", "dummy_Helper_Invisible_A", "dummy_Helper_Invisible_A")
	-- local fxHandle = Osi.PlayLoopBeamEffect(orb1, orb2,"42c757f2-52e3-6002-f0d3-9f743d4a24e8", "Dummy_Root", "Dummy_Root")
end
function Mazzle_Orbs:Disconnect_Orbs(orb1, orb2, color)
	color = color or "White"
	if (color == "Black") then color = "Gray" end
	Osi.RemoveStatus(orb1, "ML_"..color.."_Laser")
end
--- Pings a location on the map. We use this as a visual effect.
--- @param location Location
function Mazzle_Orbs:Ping(location)
	Osi.RequestPing(location.x, location.y, location.z, "", "")
end

--- @param x number
--- @param y number
--- @param z number
function Mazzle_Orbs:Ping2(x, y, z)
	Osi.RequestPing(x, y, z, "", "")
end

--- Creates a set of orbs at the locations specified in points.
--- @param points table<number,Location>
--- @param color string?
--- @param add_moonbeam boolean?
function Mazzle_Orbs:Points_To_Orbs(points, color, add_moonbeam)
	local character = Osi.GetHostCharacter()
	local center_loc = Map:Get_Object_Location(character)
	if (not center_loc) then return end
	local new_group_metadata = Object_Manager:Get_Simple_Description("ML_Points_To_Orbs_".. Mazzle_Lib:Get_Next_ID(), character, center_loc, center_loc)
	local new_group = Object_Manager:Start_Object_Group(ML_CONSTANTS.DEBUG_OBJECTS, new_group_metadata)
	for i,point in ipairs(points) do
		local new_object = new_group:Get_Object(point, color)
		if (add_moonbeam) then
			self:Add_VFX_to_Object(new_object, "moonbeam_white")
		end
	end
	Object_Manager:Finalize_Object_Group(new_group)
end

function Mazzle_Orbs:Create_Debug_Orb(x, y, z, color)
    local drop_loc = { x = x, y = y, z = z }
    local hostGUID = Ext.Entity.GetAllEntitiesWithComponent("ClientControl")[1].Uuid.EntityUuid
	local object_group = Object_Manager:Get_Object_Group_At_Index(ML_CONSTANTS.DEBUG_OBJECTS, 1)
	local created_new_group = false
	local new_object
	if (not object_group) then
	    local new_group_metadata = Object_Manager:Get_Simple_Description(string.format("Debug_%s_%s_%s",math.floor(x), math.floor(y), math.floor(z)), hostGUID, drop_loc, drop_loc)
	    object_group = Object_Manager:Start_Object_Group(ML_CONSTANTS.DEBUG_OBJECTS, new_group_metadata)
		created_new_group = true
	end
	if (object_group) then
		color = color or "White"
		drop_loc.color = color
		new_object = object_group:Get_Object(drop_loc)
		if (new_object) then
			-- MLPrint("Dropping marker %s at %.2f %.2f %.2f", new_object, x, y, z)
			-- Mazzle_Orbs:Add_VFX_to_Object(new_object, "moonbeam")
			DP("Created orb %s", new_object)
			if (created_new_group) then
				Object_Manager:Finalize_Object_Group(object_group)
			end
		else
			MLWarn("Failed to create object for marker at %.2f %.2f %.2f", x, y, z)
			if (created_new_group) then
				Object_Manager:Abort_Object_Group(object_group)
			end
		end
	else
		MLWarn("Failed to create object group for marker at %.2f %.2f %.2f", x, y, z)
	end
	return new_object
end


function Mazzle_Orbs:Create_Utility_Debug_Orb(character, x, y, z)
    local drop_loc = { x = x, y = y, z = z }
	local object_group = Object_Manager:Get_Object_Group_At_Index(ML_CONSTANTS.DEBUG_OBJECTS, 1)
	local created_new_group = false
	local new_object
	if (not object_group) then
	    local new_group_metadata = Object_Manager:Get_Simple_Description("MLUtility", character, drop_loc, drop_loc)
	    object_group = Object_Manager:Start_Object_Group(ML_CONSTANTS.DEBUG_OBJECTS, new_group_metadata)
		created_new_group = true
	end
	if (object_group) then
		new_object = object_group:Get_Object(drop_loc, "none")
		if (new_object) then
			if (created_new_group) then
				Object_Manager:Finalize_Object_Group(object_group)
			end
		else
			if (created_new_group) then
				Object_Manager:Abort_Object_Group(object_group)
			end
		end
	end
	return new_object
end
function Mazzle_Orbs:Remove_Radar_Effect(character)
	Object_Manager:Delete_Collection(ML_CONSTANTS.DEBUG_OBJECTS)
	character = character or Osi.GetHostCharacter()
	Osi.RemoveStatus(character, "ML_VFX_Radar")
end

-- Mods.Mazzle_Lib.Mazzle_Orbs:Create_Radar_Effect()
function Mazzle_Orbs:Create_Radar_Effect(character)
	Object_Manager:Delete_Collection(ML_CONSTANTS.DEBUG_OBJECTS)
	character = character or Osi.GetHostCharacter()
	Osi.RemoveStatus(character, "ML_VFX_Radar")
	local x, y, z = Osi.GetPosition(character)
 	local orb1 = Mazzle_Orbs:Create_Utility_Debug_Orb(character, x-0.5, y+0.05, z-0.5)
 	local orb2 = Mazzle_Orbs:Create_Utility_Debug_Orb(character, x-0.5, y+0.05, z+0.5)
 	local orb3 = Mazzle_Orbs:Create_Utility_Debug_Orb(character, x+0.5, y+0.05, z-0.5)
 	local orb4 = Mazzle_Orbs:Create_Utility_Debug_Orb(character, x+0.5, y+0.05, z+0.5)
	Osi.ApplyStatus(character, "ML_VFX_Radar", -1, 1, orb1)
	Osi.ApplyStatus(character, "ML_VFX_Radar", -1, 1, orb2)
	Osi.ApplyStatus(character, "ML_VFX_Radar", -1, 1, orb3)
	Osi.ApplyStatus(character, "ML_VFX_Radar", -1, 1, orb4)
end
