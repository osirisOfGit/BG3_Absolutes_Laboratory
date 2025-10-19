Ext.Require("Utilities/Common/_Index.lua")
Ext.Require("Utilities/Networking/Channels.lua")
Ext.Require("Utilities/Client/IMGUI/_Index.lua")
Ext.Require("Client/MazzleDocs.lua")
Ext.Require("Shared/MissingEnums.lua")

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")

ConfigurationStructure:InitializeConfig()

---@type MazzleDocsDocumentation
Absolutes_Lab_Documentation = {
}

Ext.Require("Shared/EntityRecorder.lua")
Ext.Require("Shared/Channels.lua")
Ext.Require("Client/RandomHelpers.lua")
Ext.Require("Client/StatBrowser.lua")
Ext.Require("Client/Styler.lua")
Ext.Require("Client/Inspector/CharacterInspector.lua")

Ext.Require("Shared/Mutations/MutationConfigurationProxy.lua")
Ext.Require("Client/Mutations/MutationExternalProfileUtility.lua")
Ext.Require("Client/Mutations/MutationProfileManager.lua")
Ext.Require("Client/Mutations/ProfileExecutionStatus.lua")

---@type MazzleDocsConfig
Absolutes_Lab_Doc_Config = {
	mod_name = "Absolute's Laboratory",
	documentation_name = "Absolute's Laboratory",
	window_title = "Welcome to the Lab!",
	type = "documentation",
	window_width = Ext.IMGUI.GetViewportSize()[1] / 3,
	window_height = Ext.IMGUI.GetViewportSize()[2] * 0.99,
	image_config = {
		atlas_key = "Lab_Docs",
		columns = 4,
		rows = 3,
		image_width = 860,
		image_height = 484
	},
	theme_override = {
		-- Window / Frame
		background         = { 0.07, 0.07, 0.07, 0.90 }, -- WindowBg
		title_bg           = { 0.07, 0.07, 0.07, 1.00 }, -- TitleBg
		title_bg_active    = { 0.32, 0.24, 0.16, 0.78 }, -- TitleBgActive (BoxActiveColor)
		title_bg_collapsed = { 0.05, 0.05, 0.05, 0.75 }, -- TitleBgCollapsed
		text               = { 0.86, 0.79, 0.68, 0.78 }, -- Text
		border             = { 0.24, 0.15, 0.08, 0.00 }, -- Border
		border_shadow      = { 0.07, 0.07, 0.07, 0.78 }, -- BorderShadow

		-- Navigation
		nav_button_hovered = { 0.80, 0.60, 0.30, 0.80 }, -- Approx. hovered accent in BG3SE UI
		nav_button_active  = { 0.90, 0.70, 0.40, 0.90 }, -- Active accent
		nav_area_bg        = { 0.05, 0.05, 0.05, 0.95 }, -- Sidebar/area background
		nav_header_text    = { 0.86, 0.79, 0.68, 0.95 }, -- Header text
		nav_topic_text     = { 0.86, 0.79, 0.68, 0.90 }, -- Topic text
		nav_subtopic_text  = { 0.80, 0.74, 0.64, 0.90 }, -- Subtopic text
		nav_slide_text     = { 0.86, 0.79, 0.68, 0.90 }, -- Slide text
		slide_index_text   = { 0.86, 0.79, 0.68, 0.90 }, -- Slide index numbers
		nav_button_text    = { 0.10, 0.10, 0.10, 1.00 }, -- Expand/collapse glyphs

		-- Content text hierarchy
		content_text       = { 0.86, 0.79, 0.68, 0.95 },
		heading_text       = { 0.95, 0.88, 0.75, 1.00 },
		subheading_text    = { 0.90, 0.83, 0.72, 0.95 },
		section_text       = { 0.90, 0.83, 0.72, 0.95 },
		note_text          = { 0.80, 0.72, 0.58, 0.95 },
		callout_text       = { 0.95, 0.88, 0.75, 1.00 },

		-- Code blocks
		code_text          = { 0.95, 0.95, 0.95, 1.00 },
		code_bg            = { 0.09, 0.09, 0.09, 1.00 },

		-- Lists / separators
		bullet_text        = { 0.86, 0.79, 0.68, 0.95 },
		separator_color    = { 0.24, 0.15, 0.08, 0.60 },

		-- Buttons
		button_bg          = { 0.32, 0.24, 0.16, 0.78 }, -- BoxActiveColor base
		button_text        = { 0.95, 0.88, 0.75, 1.00 },
		button_hover       = { 0.37, 0.28, 0.20, 0.85 },
		button_active      = { 0.27, 0.20, 0.14, 0.90 },

		-- Scrollbar
		scrollbar_bg       = { 0.05, 0.05, 0.05, 0.60 },
		scrollbar_grab     = { 0.32, 0.24, 0.16, 0.90 },
	}
}
