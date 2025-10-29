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

Ext.Require("Shared/MonsterLab/MonsterLabConfigurationProxy.lua")
Ext.Require("Client/MonsterLab/MonsterLabExportImport.lua")
Ext.Require("Client/MonsterLab/MonsterLab.lua")

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
		background             = { 0.07, 0.07, 0.07, 1.0 }, -- WindowBg
		content_area_bg        = { 0.07, 0.07, 0.07, 1.0 }, -- WindowBg
		title_bg               = { 0.07, 0.07, 0.07, 1.00 }, -- TitleBg
		title_bg_active        = { 0.32, 0.24, 0.16, 0.78 }, -- TitleBgActive (BoxActiveColor)
		title_bg_collapsed     = { 0.05, 0.05, 0.05, 0.75 }, -- TitleBgCollapsed
		text                   = { 0.86, 0.79, 0.68, 0.78 }, -- Text
		border                 = { 0.24, 0.15, 0.08, 1.00 }, -- Border
		border_shadow          = { 0.07, 0.07, 0.07, 0.78 }, -- BorderShadow

		-- Navigation
		nav_button_hovered     = { 0.80, 0.60, 0.30, 0.80 },
		nav_button_active      = { 0.90, 0.70, 0.40, 0.90 },
		nav_area_bg            = { 0.05, 0.05, 0.05, 0.95 },
		nav_header_text        = { 0.86, 0.79, 0.68, 0.95 },
		nav_topic_text         = { 0.86, 0.79, 0.68, 0.90 },
		nav_subtopic_text      = { 0.80, 0.74, 0.64, 0.90 },
		nav_slide_text         = { 0.86, 0.79, 0.68, 0.90 },
		slide_index_text       = { 0.86, 0.79, 0.68, 0.90 },
		nav_button_text        = { 0.10, 0.10, 0.10, 1.00 },

		-- Content text hierarchy
		content_text           = { 0.86, 0.79, 0.68, 0.95 },
		heading_text           = { 0.824, 0.863, 0.824, 1 },
		subheading_text        = { 0.745, 0.804, 0.725, 1 },
		section_text           = { 0.686, 0.745, 0.667, 1 },
		note_text              = { 0.80, 0.72, 0.58, 0.95 },
		callout_text           = { 0.95, 0.88, 0.75, 1.00 },

		-- Code blocks
		code_text              = { 0.95, 0.95, 0.95, 1.00 },
		code_bg                = { 0.09, 0.09, 0.09, 1.00 },

		-- Lists / separators
		bullet_text            = { 0.86, 0.79, 0.68, 0.95 },
		separator_color        = { 0.24, 0.15, 0.08, 0.60 },

		-- Buttons
		button_bg              = { 0.32, 0.24, 0.16, 0.78 },
		button_text            = { 0.95, 0.88, 0.75, 1.00 },
		button_hover           = { 0.37, 0.28, 0.20, 0.85 },
		button_active          = { 0.27, 0.20, 0.14, 0.90 },

		-- Scrollbar
		scrollbar_bg           = { 0.05, 0.05, 0.05, 0.60 },
		scrollbar_grab         = { 0.32, 0.24, 0.16, 0.90 },
		scrollbar_grab_hovered = { 0.37, 0.28, 0.20, 0.95 },
		scrollbar_grab_active  = { 0.27, 0.20, 0.14, 1.00 },

		-- New text accents
		keyword_text           = { 0.90, 0.75, 0.30, 1.00 },
		highlight_text         = { 0.95, 0.88, 0.75, 1.00 },
		warning_text           = { 0.95, 0.55, 0.40, 1.00 },

		-- Action point colors
		action_color           = { 0.25, 0.80, 0.40, 1.00 }, -- green
		bonus_action_color     = { 0.95, 0.65, 0.25, 1.00 }, -- orange

		-- Input widgets
		input_text             = { 0.90, 0.83, 0.72, 1.00 },
		input_bg               = { 0.10, 0.10, 0.10, 1.00 },
		input_bg_hover         = { 0.13, 0.13, 0.13, 1.00 },
		input_bg_active        = { 0.16, 0.16, 0.16, 1.00 },
		slider_grab            = { 0.32, 0.24, 0.16, 0.90 },
		slider_grab_active     = { 0.27, 0.20, 0.14, 1.00 },
		checkbox_bg            = { 0.10, 0.10, 0.10, 1.00 },
		checkbox_bg_hover      = { 0.13, 0.13, 0.13, 1.00 },
		checkbox_bg_active     = { 0.16, 0.16, 0.16, 1.00 },
		checkbox_check         = { 0.95, 0.88, 0.75, 1.00 },
		progress_bar           = { 0.32, 0.24, 0.16, 0.90 },
		progress_bar_bg        = { 0.07, 0.07, 0.07, 1.00 },
		callout_prefix         = { 0.95, 0.88, 0.75, 1.00 },

		-- Background image support
		bg_image               = nil, -- "parchment_bg" | "evil_parchment_bg" | "leather_bg" | "stone_bg" | "monitor_bg"

		-- Window constraints
		min_window_width       = nil,
		min_window_height      = 400,
		max_window_width       = nil,
		max_window_height      = nil,
	}
}
