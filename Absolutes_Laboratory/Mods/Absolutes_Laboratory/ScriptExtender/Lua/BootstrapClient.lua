Ext.Require("Utilities/Common/_Index.lua")
Ext.Require("Utilities/Networking/Channels.lua")
Ext.Require("Utilities/Client/IMGUI/_Index.lua")
Ext.Require("Client/MazzleDocs.lua")

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

Absolutes_Lab_Doc_Config = {
	mod_name = "Absolute's Laboratory",
	documentation_name = "Absolute's Laboratory",
	window_title = "Welcome to the Lab!",
	type = "documentation",
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
		nav_button_hovered = { 0.38, 0.26, 0.21, 0.78 }, -- HeaderHovered / BoxHoverColor
		nav_button_active  = { 0.32, 0.24, 0.16, 0.78 }, -- HeaderActive / BoxActiveColor
		nav_area_bg        = { 0.07, 0.07, 0.07, 0.47 }, -- MenuBarBg

		-- Content text colors
		content_text       = { 0.86, 0.79, 0.68, 0.78 }, -- Text
		heading_text       = { 0.86, 0.79, 0.68, 0.78 }, -- reuse Text
		subheading_text    = { 0.86, 0.79, 0.68, 0.63 }, -- PlotLines as subtler text
		note_text          = { 0.86, 0.79, 0.68, 0.63 }, -- PlotHistogram similar subtle emphasis
		callout_text       = { 0.86, 0.79, 0.68, 1.00 }, -- PlotLinesHovered (fully opaque)
		code_text          = { 0.95, 0.82, 0.60, 0.14 }, -- SliderGrab (faint accent)
		bullet_text        = { .86, 0.79, 0.68, 0.78 }, -- TableBorderStrong as accent bullets
		separator_text     = { 0.86, 0.79, 0.68, 0.78 }
	}
}
