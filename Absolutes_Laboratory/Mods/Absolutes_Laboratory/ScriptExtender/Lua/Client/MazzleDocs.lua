-- MazzleDocs Content Representation System
-- IDE Helper File with Lua Annotations for Documentation Creation
-- Provides autocomplete, validation, and documentation for MazzleDocs content structures

---@class MazzleDocs
MazzleDocs = Mods["Mazzle_Docs"]

---@param parent ExtuiTreeParent
---@param buttonSize number[]?
---@return ExtuiImageButton
function MazzleDocs:addDocButton(parent, buttonSize)
	local button = Styler:ImageButton(parent:AddImageButton("Docs", "Item_BOOK_GEN_Books_Row_Multiple_D", buttonSize or { 32, 32 }))
	button.UserData = "EnableForMods"
	button.OnClick = function()
		local document = {}
		for _, slide in TableUtils:CombinedPairs(MutationProfileManager:generateDocs(), MonsterLab:generateDocs()) do
			table.insert(document, slide)
		end

		local config = TableUtils:DeeplyCopyTable(Absolutes_Lab_Doc_Config)

		local currentVer = ""
		for i, ver in ipairs(Ext.Mod.GetMod(ModuleUUID).Info.PublishVersion) do
			if i < 4 then
				currentVer = currentVer .. tostring(ver)
				if i < 3 then
					currentVer = currentVer .. "."
				end
			end
		end

		---@param componentName string
		---@param changelogs ({ [string]: MazzleDocsContentItem }|{ [string]: { [string]: MazzleDocsContentItem } })
		---@param subTopic string
		local function buildChangelogForMaster(componentName, changelogs, subTopic)
			local masterChangelogEntry = {
				Topic = "Master Changelog",
				SubTopic = subTopic,
				content = {
					{
						type = "Heading",
						text = componentName
					}
				}
			} --[[@as MazzleDocsSlide]]

			for version, changelog in TableUtils:OrderedPairs(changelogs, function(key)
				-- To Sort Descending Order
				local M, m, p = key:match("^(%d+)%.(%d+)%.(%d+)$")
				return -1 * tonumber(M .. m .. p)
			end) do
				if version == currentVer then
					version = version .. " (Current)"
				end

				table.insert(masterChangelogEntry.content, {
					type = "Heading",
					text = version,
					spacing_after = 0
				} --[[@as MazzleDocsContentItem]])

				if componentName == "Mutators" then
					for subcomponentName, changelogEntry in TableUtils:OrderedPairs(changelog) do
						table.insert(masterChangelogEntry.content, {
							type = "SubHeading",
							text = subcomponentName
						} --[[@as MazzleDocsContentItem]])

						table.insert(masterChangelogEntry.content, changelogEntry)
					end
				else
					table.insert(masterChangelogEntry.content, changelog)
				end
			end

			table.insert(document, masterChangelogEntry)
		end

		buildChangelogForMaster("General", MutationProfileManager:generateChangelog(), "Mutations")
		buildChangelogForMaster("Mutators", MutatorInterface:generateChangelog(), "Mutations")
		buildChangelogForMaster("Selectors", SelectorInterface:generateChangelog(), "Mutations")
		buildChangelogForMaster("General", MonsterLab:generateChangelog(), "Monster Lab")
		buildChangelogForMaster("Encounter Designer", EncounterDesigner:generateChangelog(), "Monster Lab")

		self.Create_Mazzle_Docs(document, config)
	end

	return button
end

---@class MazzleDocsSlide
---@field Topic string The main topic/chapter this slide belongs to
---@field SubTopic? string Optional subtopic for grouping related slides under the same topic
---@field content MazzleDocsContentItem[] Array of content widgets that make up this slide
---@field Init_Action? MazzleDocsAction Optional action to run when slide is shown
---@field CleanUp_Action? MazzleDocsAction Optional action to run when slide is hidden/closed

---@class MazzleDocsDocumentation
---@field [integer] MazzleDocsSlide Array of slides that make up the documentation

---@class MazzleDocsConfig Configuration for documentation window (used with Create_Lua API)
-- Required Fields
---@field window_title string Display name for the documentation window
---@field type "documentation"|"tutorial" Type of window: "documentation" has combo/content views, "tutorial" has stepper controls
---@field mod_name string Internal identifier for the mod (used for state storage and lookup)
---@field documentation_name string Unique identifier for this documentation set (used for state storage and lookup)
-- Window Sizing
---@field window_height? integer Initial window height in pixels (default: 980)
---@field window_width? integer Initial window width in pixels - for documentation: combo view width; for tutorial: content width (default: 1200)
-- Visibility Controls
---@field ToC_Starts_Hidden? boolean Whether Table of Contents panel starts hidden (default: false)
---@field Hide_Search? boolean Hide the search bar and label in ToC panel (default: false)
---@field Hide_Toc_Navigation? boolean Hide the prev/next navigation buttons in ToC panel (default: false)
---@field Hide_Content_Topic? boolean Hide the Topic header text in content-only view (default: false)
---@field Hide_Content_Subtopic? boolean Hide the SubTopic header text in content-only view (default: false)
---@field Hide_Content_Navigation? boolean Hide the prev/next navigation buttons in content area (default: false)
-- Theming
---@field theme_preset? "c64"|"stone"|"undead"|"pastel"|"parchment"|"leather" Built-in theme preset name (optional)
---@field theme_override? MazzleDocsThemeOverride Per-window theme customizations applied on top of preset (optional)
-- Image Configuration
---@field image_config? MazzleDocsImageConfig Image atlas configuration for Image widgets (optional)

---@class MazzleDocsJsonConfig JSON format configuration with Lua references
---@field SchemaVersion integer Schema version (usually 1)
---@field Windows MazzleDocsJsonWindow[] Array of window configurations

---@class MazzleDocsJsonWindow JSON window configuration
---@field ModName string The mod name identifier
---@field DocumentationName string The documentation name identifier
---@field WindowTitle? string Optional window title override
---@field LuaContent string Global variable name containing the documentation content table
---@field LuaConfig string Global variable name containing the configuration table

---@class MazzleDocsLuaEntry Lua documentation registration entry
---@field mod_name string The mod name identifier
---@field documentation_name string The documentation name identifier
---@field window_title string The window title to display
---@field mod_path string The path to the mod folder
---@field modtable_name string The name of the mod table (e.g., "Mods.MyMod")
---@field lua_content_var string The global variable name containing content (e.g., "Mods.MyMod.MyDocs_Content")
---@field lua_config_var string The global variable name containing config (e.g., "Mods.MyMod.MyDocs_Config")

---@class MazzleDocsImageConfig
---@field atlas_key string Name of the image atlas
---@field columns integer Number of images in each row
---@field rows integer Number of images in each column
---@field image_width integer Width of each individual image
---@field image_height integer Height of each individual image

---@class MazzleDocsThemeOverride Complete theme system with color properties and font/size properties
---@field background? [number, number, number, number] Main window background color {r, g, b, a}
---@field title_bg? [number, number, number, number] Window title bar background {r, g, b, a}
---@field title_bg_active? [number, number, number, number] Active window title bar background {r, g, b, a}
---@field title_bg_collapsed? [number, number, number, number] Collapsed window title bar background {r, g, b, a}
---@field text? [number, number, number, number] General UI text color {r, g, b, a}
---@field border? [number, number, number, number] Window and element border color {r, g, b, a}
---@field border_shadow? [number, number, number, number] Shadow/depth border color {r, g, b, a}
---@field nav_button_hovered? [number, number, number, number] Navigation buttons hover state color {r, g, b, a}
---@field nav_button_active? [number, number, number, number] Navigation buttons active state color {r, g, b, a}
---@field nav_area_bg? [number, number, number, number] Navigation area background color {r, g, b, a}
---@field nav_header_text? [number, number, number, number] Navigation section header text color {r, g, b, a}
---@field nav_topic_text? [number, number, number, number] Top-level topic tree node text color {r, g, b, a}
---@field nav_subtopic_text? [number, number, number, number] Subtopic tree node text color {r, g, b, a}
---@field nav_slide_text? [number, number, number, number] Individual slide button text color {r, g, b, a}
---@field slide_index_text? [number, number, number, number] Slide index number text color {r, g, b, a}
---@field nav_button_text? [number, number, number, number] Expand/collapse button text color {r, g, b, a}
---@field content_text? [number, number, number, number] Standard content paragraph text {r, g, b, a}
---@field heading_text? [number, number, number, number] Heading text color {r, g, b, a}
---@field subheading_text? [number, number, number, number] Subheading text color {r, g, b, a}
---@field section_text? [number, number, number, number] Section header text color {r, g, b, a}
---@field note_text? [number, number, number, number] Note text color {r, g, b, a}
---@field callout_text? [number, number, number, number] CallOut content text color {r, g, b, a}
---@field code_text? [number, number, number, number] Code block text color {r, g, b, a}
---@field code_bg? [number, number, number, number] Code block background color {r, g, b, a}
---@field bullet_text? [number, number, number, number] Bullet point text color {r, g, b, a}
---@field separator_color? [number, number, number, number] Horizontal separator line color {r, g, b, a}
---@field button_bg? [number, number, number, number] Button background color {r, g, b, a}
---@field button_text? [number, number, number, number] Button text color {r, g, b, a}
---@field button_hover? [number, number, number, number] Button hover state color {r, g, b, a}
---@field button_active? [number, number, number, number] Button active state color {r, g, b, a}
---@field scrollbar_bg? [number, number, number, number] Scrollbar background color {r, g, b, a}
---@field scrollbar_grab? [number, number, number, number] Scrollbar grab handle color {r, g, b, a}
---@field scrollbar_grab_hovered? [number, number, number, number] Scrollbar grab handle hover color {r, g, b, a}
---@field scrollbar_grab_active? [number, number, number, number] Scrollbar grab handle active color {r, g, b, a}
---@field keyword_text? [number, number, number, number] Keyword/important text color {r, g, b, a}
---@field highlight_text? [number, number, number, number] Highlighted text color {r, g, b, a}
---@field warning_text? [number, number, number, number] Warning text color {r, g, b, a}
---@field action_color? [number, number, number, number] Action point color (green) {r, g, b, a}
---@field bonus_action_color? [number, number, number, number] Bonus action point color (orange) {r, g, b, a}
-- Input Widget Theme Properties (2.0.3)
---@field input_text? [number, number, number, number] Input text color {r, g, b, a}
---@field input_bg? [number, number, number, number] Input background color {r, g, b, a}
---@field input_bg_hover? [number, number, number, number] Input background hover color {r, g, b, a}
---@field input_bg_active? [number, number, number, number] Input background active color {r, g, b, a}
---@field slider_grab? [number, number, number, number] Slider grab handle color {r, g, b, a}
---@field slider_grab_active? [number, number, number, number] Slider grab handle active color {r, g, b, a}
---@field checkbox_bg? [number, number, number, number] Checkbox background color {r, g, b, a}
---@field checkbox_bg_hover? [number, number, number, number] Checkbox background hover color {r, g, b, a}
---@field checkbox_bg_active? [number, number, number, number] Checkbox background active color {r, g, b, a}
---@field checkbox_check? [number, number, number, number] Checkbox checkmark color {r, g, b, a}
---@field progress_bar? [number, number, number, number] Progress bar fill color {r, g, b, a}
---@field progress_bar_bg? [number, number, number, number] Progress bar background color {r, g, b, a}
---@field callout_prefix? [number, number, number, number] CallOut prefix text color {r, g, b, a}
-- Background Image Properties (2.0.3+)
---@field bg_image? string Background texture image name: "parchment_bg", "evil_parchment_bg", "leather_bg", "stone_bg", "monitor_bg"
---@field bg_alpha? number Background alpha for other UI elements (0.0 = fully transparent, allows bg_image to show through). Normally set to 0.0
-- Window Dimension Constraints (2.0.3+)
---@field min_window_width? integer Override minimum window width in pixels (default: calculated based on view mode)
---@field min_window_height? integer Override minimum window height in pixels (default: 400)
---@field max_window_width? integer Set maximum window width in pixels (default: nil = no maximum)
---@field max_window_height? integer Set maximum window height in pixels (default: nil = no maximum)
-- Font/Size Theme Properties - Separate fields for family and size (e.g., heading_font_family, heading_font_size)
---@field heading_font_family? MazzleDocsFontFamily Font family for Heading widgets (default: "default")
---@field heading_font_size? MazzleDocsFontSize Font size for Heading widgets (default: "Large")
---@field subheading_font_family? MazzleDocsFontFamily Font family for SubHeading widgets (default: "default")
---@field subheading_font_size? MazzleDocsFontSize Font size for SubHeading widgets (default: "Medium")
---@field content_font_family? MazzleDocsFontFamily Font family for Content text widgets (default: "default")
---@field content_font_size? MazzleDocsFontSize Font size for Content text widgets (default: "Small")
---@field note_font_family? MazzleDocsFontFamily Font family for Note widgets (default: "default")
---@field note_font_size? MazzleDocsFontSize Font size for Note widgets (default: "Small")
---@field section_font_family? MazzleDocsFontFamily Font family for Section widgets (default: "default")
---@field section_font_size? MazzleDocsFontSize Font size for Section widgets (default: "Small")
---@field bullet_font_family? MazzleDocsFontFamily Font family for Bullet list items (default: "default")
---@field bullet_font_size? MazzleDocsFontSize Font size for Bullet list items (default: "Small")
---@field code_font_family? MazzleDocsFontFamily Font family for Code blocks (default: "default")
---@field code_font_size? MazzleDocsFontSize Font size for Code blocks (default: "Small")
---@field callout_prefix_font_family? MazzleDocsFontFamily Font family for CallOut prefix text (default: "default")
---@field callout_prefix_font_size? MazzleDocsFontSize Font size for CallOut prefix text (default: "Small")
---@field callout_text_font_family? MazzleDocsFontFamily Font family for CallOut main content (default: "default")
---@field callout_text_font_size? MazzleDocsFontSize Font size for CallOut main content (default: "Small")
---@field input_text_font_family? MazzleDocsFontFamily Font family for InputText widgets (default: "default")
---@field input_text_font_size? MazzleDocsFontSize Font size for InputText widgets (default: "Small")
---@field input_int_font_family? MazzleDocsFontFamily Font family for InputInt widgets (default: "default")
---@field input_int_font_size? MazzleDocsFontSize Font size for InputInt widgets (default: "Small")
---@field input_float_font_family? MazzleDocsFontFamily Font family for InputFloat widgets (default: "default")
---@field input_float_font_size? MazzleDocsFontSize Font size for InputFloat widgets (default: "Small")
---@field drag_int_font_family? MazzleDocsFontFamily Font family for DragInt widgets (default: "default")
---@field drag_int_font_size? MazzleDocsFontSize Font size for DragInt widgets (default: "Small")
---@field drag_float_font_family? MazzleDocsFontFamily Font family for DragFloat widgets (default: "default")
---@field drag_float_font_size? MazzleDocsFontSize Font size for DragFloat widgets (default: "Small")
---@field slider_int_font_family? MazzleDocsFontFamily Font family for SliderInt widgets (default: "default")
---@field slider_int_font_size? MazzleDocsFontSize Font size for SliderInt widgets (default: "Small")
---@field slider_float_font_family? MazzleDocsFontFamily Font family for SliderFloat widgets (default: "default")
---@field slider_float_font_size? MazzleDocsFontSize Font size for SliderFloat widgets (default: "Small")
---@field checkbox_font_family? MazzleDocsFontFamily Font family for Checkbox widgets (default: "default")
---@field checkbox_font_size? MazzleDocsFontSize Font size for Checkbox widgets (default: "Small")
---@field listchooser_font_family? MazzleDocsFontFamily Font family for ListChooser widgets (default: "default")
---@field listchooser_font_size? MazzleDocsFontSize Font size for ListChooser widgets (default: "Small")
---@field button_font_family? MazzleDocsFontFamily Font family for DynamicButton widgets (default: "default")
---@field button_font_size? MazzleDocsFontSize Font size for DynamicButton widgets (default: "Small")
---@field progressbar_font_family? MazzleDocsFontFamily Font family for ProgressBar overlay text (default: "default")
---@field progressbar_font_size? MazzleDocsFontSize Font size for ProgressBar overlay text (default: "Small")
---@field separator_font_family? MazzleDocsFontFamily Font family for SeparatorText widgets (default: "default")
---@field separator_font_size? MazzleDocsFontSize Font size for SeparatorText widgets (default: "Small")
---@field nav_topic_font_family? MazzleDocsFontFamily Font family for ToC topic tree nodes (default: "default")
---@field nav_topic_font_size? MazzleDocsFontSize Font size for ToC topic tree nodes (default: "Small")
---@field nav_subtopic_font_family? MazzleDocsFontFamily Font family for ToC subtopic tree nodes (default: "default")
---@field nav_subtopic_font_size? MazzleDocsFontSize Font size for ToC subtopic tree nodes (default: "Small")
---@field nav_slide_font_family? MazzleDocsFontFamily Font family for ToC slide buttons (default: "default")
---@field nav_slide_font_size? MazzleDocsFontSize Font size for ToC slide buttons (default: "Tiny")
---@field global_font_family? MazzleDocsFontFamily Global font family override (priority 2 - after widget-specific, before theme fonts)
---@field global_font_size? MazzleDocsFontSize Global font size override (priority 2 - after widget-specific, before theme fonts)

---@alias MazzleDocsFontFamily
---| "default"        # IMGUI built-in font
---| "Inconsolata"    # Monospace programming font
---| "CaveatBrush"    # Handwritten brush font
---| "CaveatCyrillic" # Handwritten brush font with Cyrillic characters
---| "DancingScript"  # Cursive script font
---| "Oswald"         # Bold condensed sans-serif font
---| "StoryScript"    # Decorative story font
---| "c64"            # Commodore 64 pixelated retro font
---| "Creepster"      # Spooky decorative horror font
---| "Parchment"      # Old-style decorative parchment font

---@alias MazzleDocsFontSize
---| "Tiny"
---| "Small"
---| "Normal"
---| "Medium"
---| "Large"

-- Base content item interface
---@class MazzleDocsContentItem
---@field type MazzleDocsContentType The type of content widget
---@field text? string|string[] The main text content (required for most types)
---@field font? MazzleDocsFontFamily Font family
---@field size? MazzleDocsFontSize Font size
---@field color? string|[number, number, number, number] Override default color (color name or RGBA array)
---@field centered? boolean Center the content horizontally
---@field left_indent? integer Left margin in pixels
---@field spacing_before? integer Vertical space before widget in pixels
---@field spacing_after? integer Vertical space after widget in pixels
---@field widget_id? string|string[] Optional widget ID for making content widgets addressable (used by some content widgets)

---@alias MazzleDocsContentType
---| "Heading"        # Large title text for major sections
---| "SubHeading"     # Medium title text for subsections
---| "Content"        # Regular paragraph text
---| "Section"        # Section headers with distinctive styling
---| "Note"           # Secondary text with muted appearance
---| "Bullet"         # Creates bulleted lists
---| "CallOut"        # Highlighted text box with custom prefix
---| "Code"           # Formatted code blocks with monospace font
---| "Separator"      # Visual separator line (can include text for SeparatorText variant)
---| "DynamicButton"  # Interactive buttons for commands
---| "Image"          # Static images
-- Interactive Input Widgets (2.0.3)
---| "Checkbox"       # Boolean toggle controls
---| "InputText"      # Text input fields (single-line and multiline)
---| "ListChooser"    # Dropdown/combo box selection
---| "InputInt"       # Integer input with validation
---| "InputFloat"     # Float input with validation
---| "SliderInt"      # Integer slider controls
---| "SliderFloat"    # Float slider controls
---| "DragInt"        # Integer drag controls
---| "DragFloat"      # Float drag controls
---| "ProgressBar"    # Progress display widget

-- Text Content Widgets

---@class MazzleDocsHeading : MazzleDocsContentItem
---@field type "Heading"
---@field text string|string[] The heading text content (string or array)
---@field highlighted? boolean Display on dark red banner for tutorial goals

---@class MazzleDocsSubHeading : MazzleDocsContentItem
---@field type "SubHeading"
---@field text string|string[] The subheading text content (string or array)

---@class MazzleDocsContent : MazzleDocsContentItem
---@field type "Content"
---@field text string|string[] Regular paragraph text (string or array for multiple paragraphs)

---@class MazzleDocsSection : MazzleDocsContentItem
---@field type "Section"
---@field text string|string[] Section header text with distinctive styling (string or array)

---@class MazzleDocsNote : MazzleDocsContentItem
---@field type "Note"
---@field text string|string[] Note text with muted appearance (string or array)

-- List Widgets

---@class MazzleDoctsBullet : MazzleDocsContentItem
---@field type "Bullet"
---@field text string[] Array of bullet point strings
---@field bullet_image_key? string Custom bullet icon name
---@field bullet_image_size? [integer, integer] Icon size as {width, height}

-- Highlighted Widgets

---@class MazzleDocsCallOut : MazzleDocsContentItem
---@field type "CallOut"
---@field prefix string Prefix text (e.g., "Warning:", "Tip:", "Note:")
---@field text string|string[] The main callout text content (string or array for multiple lines)
---@field prefix_color? string Color name for the prefix text
---@field text_block_indent? integer Indentation for the text block in pixels
---@field right_padding_px? integer Right padding space (default: 40 for CallOut, 20 for render function)
---@field prefix_gap_px? integer Gap between prefix and text in pixels (default: 12)

-- Code Widgets

---@class MazzleDocsCode : MazzleDocsContentItem
---@field type "Code"
---@field text string|string[] Code content with preserved formatting (string or array for multiple lines)

-- Separator Widget

---@class MazzleDoctsSeparator : MazzleDocsContentItem
---@field type "Separator"
---@field text? string Optional text to display on separator (creates SeparatorText variant)
---@field text_align? number Horizontal text alignment from 0.0 (left) to 1.0 (right), default: 0.5 (center)
---@field padding? integer Vertical spacing before/after separator in pixels

-- ProgressBar Widget

---@class MazzleDocsProgressBar : MazzleDocsContentItem
---@field type "ProgressBar"
---@field value number Required progress value from 0.0 to 1.0
---@field overlay? string Display text overlaid on progress bar
---@field text? string Alternative to overlay - display text overlaid on progress bar
---@field width? integer Widget width in pixels
---@field height? integer Widget height in pixels

-- Action System for Dynamic Buttons and Slide Actions

---@class MazzleDocsAction
---@field button_type MazzleDocsDynamicButtonType Type of action to perform
---@field button_parameters? table Parameters passed to the action handler (varies by button_type)

-- Slide Lifecycle Actions
-- Init_Action: Executes when a slide is displayed (on slide navigation or window open)
-- CleanUp_Action: Executes when a slide is hidden (on slide navigation away or window close)
-- Both use the same MazzleDocsAction structure as DynamicButton
-- Common uses:
--   - broadcast_client/broadcast_server: Notify other systems of slide/window state
--   - open_docs: Open related documentation
--   - add_status/remove_status: Apply temporary effects during tutorials
-- Example:
--   Init_Action = { button_type = "broadcast_client", button_parameters = { message = "Tutorial_Start", payload = "" }}
--   CleanUp_Action = { button_type = "broadcast_client", button_parameters = { message = "Tutorial_End", payload = "" }}

-- Interactive Widgets

-- Single button format
---@class MazzleDoctsDynamicButton : MazzleDocsContentItem
---@field type "DynamicButton"
---@field label string Text displayed on the button
---@field button_type MazzleDocsDynamicButtonType Type of button action
---@field button_parameters? table Parameters passed to the action handler (varies by button_type)
---@field icon? string Optional icon name for ImageButton (renders as image instead of text button)
---@field width? integer Width in pixels for image buttons (default: 32)
---@field height? integer Height in pixels for image buttons (default: 32)
---@field centered? boolean Center the button horizontally
---@field left_indent? integer Left margin in pixels (ignored if centered)
---@field spacing_before? integer Vertical space before button in pixels
---@field spacing_after? integer Vertical space after button in pixels

-- Multiple buttons format (displays buttons side-by-side)
---@class MazzleDoctsDynamicButtonMultiple : MazzleDocsContentItem
---@field type "DynamicButton"
---@field buttons MazzleDocsButtonSpec[] Array of button specifications for side-by-side display
---@field centered? boolean Center the button array horizontally
---@field left_indent? integer Left margin in pixels (ignored if centered)
---@field cell_spacing? integer Horizontal spacing between buttons in pixels (default: 8)
---@field spacing_before? integer Vertical space before button array in pixels
---@field spacing_after? integer Vertical space after button array in pixels

---@class MazzleDocsButtonSpec
---@field label string Text displayed on the button
---@field button_type MazzleDocsDynamicButtonType Type of button action
---@field button_parameters? table Parameters passed to the action handler (varies by button_type)
---@field icon? string Optional icon name for ImageButton (renders as image instead of text button)
---@field width? integer Width in pixels for image buttons (default: 32)
---@field height? integer Height in pixels for image buttons (default: 32)

---@alias MazzleDocsDynamicButtonType
---| "go"                 # Movement command - requires x,y,z coordinates, optional level
---| "go_party"           # Party movement command - requires x,y,z coordinates, optional level
---| "go_party_separate"  # Separate party movement command - requires x1,y1,z1,x2,y2,z2 coordinates, optional level
---| "add_spell"          # Add spell to character - requires value (spell ID)
---| "remove_spell"       # Remove spell from character - requires value (spell ID)
---| "add_passive"        # Add passive to character - requires value (passive ID)
---| "remove_passive"     # Remove passive from character - requires value (passive ID)
---| "add_status"         # Add status effect to character - requires value (status ID), optional duration
---| "remove_status"      # Remove status effect from character - requires value (status ID)
---| "spawn_npc"          # Spawn an NPC - requires name, spawn_type, mapkey; optional displayname
---| "add_item"		   	  # Add item to character - requires uuid; optional count
---| "open_docs"          # Open documentation window - requires mod_name, documentation_name
---| "open_mcm"           # Open Mod Configuration Menu - no parameters required
---| "broadcast_server"   # Send server broadcast - requires message; optional payload
---| "broadcast_client"   # Send client broadcast - requires message; optional payload

-- Button Parameter Type Definitions
-- Each button_type requires specific parameters in button_parameters

---@class MazzleDocsButtonParams_Go Movement parameters
---@field x number Required X coordinate
---@field y number Required Y coordinate
---@field z number Required Z coordinate
---@field level? string Optional level name (e.g., "WLD_Main_A")

---@class MazzleDocsButtonParams_GoPartySeparate Separate party movement parameters
---@field x1 number Required X coordinate for active character
---@field y1 number Required Y coordinate for active character
---@field z1 number Required Z coordinate for active character
---@field x2 number Required X coordinate for rest of party
---@field y2 number Required Y coordinate for rest of party
---@field z2 number Required Z coordinate for rest of party
---@field level? string Optional level name

---@class MazzleDocsButtonParams_Value Simple value parameter (spells, passives, statuses)
---@field value string Required ID (spell_id, passive_id, or status_id)

---@class MazzleDocsButtonParams_Status Status effect parameters
---@field value string Required status ID
---@field duration? number Optional duration in seconds (-1 for infinite, default: -1)

---@class MazzleDocsButtonParams_AddItem Item addition parameters
---@field uuid string Required item template UUID
---@field count? integer Optional item count (default: 1)

---@class MazzleDocsButtonParams_SpawnNPC NPC spawning parameters
---@field name string Required internal name
---@field spawn_type "enemy"|"NPC" Required spawn type
---@field mapkey string Required template UUID
---@field displayname? string Optional display name (default: "Unknown")

---@class MazzleDocsButtonParams_OpenDocs Documentation opening parameters
---@field mod_name string Required mod identifier
---@field documentation_name string Required documentation name

---@class MazzleDocsButtonParams_Broadcast Network broadcast parameters
---@field message string Required channel name to broadcast on
---@field payload? table|string|number Optional data to send (tables are auto-JSON encoded). Widget references (@widget:id) work at any nesting depth.

-- Note: open_mcm requires no parameters (empty table or nil)

-- Image Widgets

---@class MazzleDocsImage : MazzleDocsContentItem
---@field type "Image"
---@field image_index integer Index of the image to display (starts at 1)
---@field image_width? integer Width override in pixels

-- Interactive Input Widgets (2.0.3)
-- All input widgets require widget_id for state tracking and support array layouts

---@class MazzleDocsCheckbox : MazzleDocsContentItem
---@field type "Checkbox"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field text? string|string[] Display text for the checkbox (appears next to checkbox)
---@field default? boolean|boolean[] Default boolean value (default: false)
---@field label? string|string[] Label text that appears before the checkbox
---@field label_position? "left"|"top" Position of label (default: left)

---@class MazzleDocsInputText : MazzleDocsContentItem
---@field type "InputText"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field default? string|string[] Default text value (default: empty string)
---@field hint? string|string[] Placeholder text shown when field is empty
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels (-1 fills available space)
---@field height? integer Widget height in pixels (enables multiline if > 0)
---@field readonly? boolean Make field read-only (true/false, default: false)

---@class MazzleDocsListChooser : MazzleDocsContentItem
---@field type "ListChooser"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field options string[]|string[][] Array of options (single array for shared, array of arrays for per-widget)
---@field default? integer|string|table Default selected option (0-based index or string value matching an option)
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels

---@class MazzleDocsInputInt : MazzleDocsContentItem
---@field type "InputInt"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field default? integer|integer[] Default integer value (default: 0)
---@field min? integer|integer[] Minimum allowed value
---@field max? integer|integer[] Maximum allowed value
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels

---@class MazzleDocsInputFloat : MazzleDocsContentItem
---@field type "InputFloat"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field default? number|number[] Default float value (default: 0.0)
---@field min? number|number[] Minimum allowed value
---@field max? number|number[] Maximum allowed value
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels

---@class MazzleDocsSliderInt : MazzleDocsContentItem
---@field type "SliderInt"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field min integer|integer[] Required minimum value
---@field max integer|integer[] Required maximum value
---@field default? integer|integer[] Default integer value (default: min)
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels

---@class MazzleDocsSliderFloat : MazzleDocsContentItem
---@field type "SliderFloat"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field min number|number[] Required minimum value
---@field max number|number[] Required maximum value
---@field default? number|number[] Default float value (default: min)
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels

---@class MazzleDoctsDragInt : MazzleDocsContentItem
---@field type "DragInt"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field default? integer|integer[] Default integer value (default: 0)
---@field min? integer|integer[] Minimum allowed value
---@field max? integer|integer[] Maximum allowed value
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels

---@class MazzleDoctsDragFloat : MazzleDocsContentItem
---@field type "DragFloat"
---@field widget_id string|string[] Required unique identifier for state tracking
---@field default? number|number[] Default float value (default: 0.0)
---@field min? number|number[] Minimum allowed value
---@field max? number|number[] Maximum allowed value
---@field label? string|string[] Display label for the widget
---@field label_position? "left"|"top" Position of label (default: left)
---@field width? integer|integer[] Widget width in pixels

-- Widget Callback System (2.0.3)

---@class MazzleDocsWidgetEvent
---@field mod_name string The mod that owns the widget
---@field documentation_name string The documentation set that contains the widget
---@field widget_id string The widget identifier that changed
---@field value any The new value of the widget
---@field widget_type string The type of widget that changed

---@alias MazzleDocsWidgetCallback fun(event: MazzleDocsWidgetEvent): nil

-- MazzleDocs 2.0.3 API System

---@class MazzleDocsAPI
local MazzleDocsAPI = {}

-- Document Management Functions

---Create documentation from Lua tables
---@param doc_data MazzleDocsDocumentation The documentation content as Lua table
---@param config MazzleDocsConfig The configuration for the documentation
---@return nil
function MazzleDocsAPI.Create_Lua(doc_data, config) end

---Create documentation from JSON files
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@return nil
function MazzleDocsAPI.Create_JSON(mod_name, documentation_name) end

---Close a documentation window
---@param window_title string The title of the window to close
---@return nil
function MazzleDocsAPI.Close(window_title) end

---Rebuild documentation with fresh content
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@return nil
function MazzleDocsAPI.Rebuild(mod_name, documentation_name) end

---Rebuild documentation by window title with optional new content/config
---@param window_title string The window title to refresh
---@param content_data? MazzleDocsDocumentation Optional new content data
---@param config? MazzleDocsConfig Optional new configuration
---@return boolean success True if window was successfully refreshed
function MazzleDocsAPI.RebuildByTitle(window_title, content_data, config) end

---Navigate to a specific slide in a documentation window
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param slide_index integer The slide number to navigate to (1-based)
---@return boolean success True if navigation was successful
function MazzleDocsAPI.GoToSlide(mod_name, documentation_name, slide_index) end

---Export documentation to JSON files
---@param config_data MazzleDocsConfig Configuration data including mod_name, documentation_name, etc.
---@param content_table MazzleDocsDocumentation The content table to export
---@param output_folder? string Optional output folder path (default: mod folder)
---@param overwrite? boolean Optional overwrite flag (default: false - prompts user)
---@return boolean success True if export was successful
function MazzleDocsAPI.Export_To_JSON(config_data, content_table, output_folder, overwrite) end

---Export documentation to JSON files in MazzleDocs folder (overwrites existing)
---@param config_data MazzleDocsConfig Configuration data including mod_name, documentation_name, etc.
---@param content_table MazzleDocsDocumentation The content table to export
---@return boolean success True if export was successful
function MazzleDocsAPI.ExportToMazzleDocsFolder(config_data, content_table) end

---Get content and config from an open documentation window
---@param window_title string The title of the documentation window
---@return MazzleDocsDocumentation|nil content_table The content table from the window
---@return MazzleDocsConfig|nil config_table The config table from the window
function MazzleDocsAPI.GetWindowContent(window_title) end

---Register Lua-based documentation with the browser
---@param entry MazzleDocsLuaEntry Documentation entry with metadata
---@return boolean success True if registration was successful
---@return string|nil error Error message if failed
function MazzleDocsAPI.RegisterLuaDocs(entry) end

---Unregister documentation from the browser (removes from list, does not close open windows)
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@return boolean success True if unregistration was successful
---@return string|nil error Error message if failed
function MazzleDocsAPI.UnregisterDocs(mod_name, documentation_name) end

-- Widget State Management Functions

---Get the current value of a widget
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param widget_id string The widget identifier
---@return any|nil The current widget value, or nil if widget not found
function MazzleDocsAPI.Get(mod_name, documentation_name, widget_id) end

---Set the value of a widget (updates display immediately)
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param widget_id string The widget identifier
---@param value any The new value to set
---@return nil
function MazzleDocsAPI.Set(mod_name, documentation_name, widget_id, value) end

---Reset a widget to its default value
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param widget_id string The widget identifier
---@return nil
function MazzleDocsAPI.Reset(mod_name, documentation_name, widget_id) end

---Remove a widget from the content store
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param widget_id string The widget identifier
---@return boolean success True if widget was removed, false if it didn't exist
function MazzleDocsAPI.RemoveWidget(mod_name, documentation_name, widget_id) end

---Focus a specific widget by setting keyboard focus on it
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param widget_id string The widget identifier
---@return boolean success True if widget was found and focused
function MazzleDocsAPI.FocusWidget(mod_name, documentation_name, widget_id) end

-- Widget Callback Management Functions

---Register a callback function to be called when a widget value changes
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param widget_id string The widget identifier
---@param callback MazzleDocsWidgetCallback The function to call when widget changes
---@return nil
function MazzleDocsAPI.RegisterCallback(mod_name, documentation_name, widget_id, callback) end

---Unregister a callback for a widget
---@param mod_name string The mod name identifier
---@param documentation_name string The documentation name identifier
---@param widget_id string The widget identifier
---@return nil
function MazzleDocsAPI.UnregisterCallback(mod_name, documentation_name, widget_id) end

-- Window Callbacks

---@alias MazzleDocsWindowResizeCallback fun(window: table, newWidth: integer, newHeight: integer, oldWidth: integer, oldHeight: integer)

---Register a callback to be notified when an IMGUI window's size changes
---Supports multiple callbacks per window using unique callback_id strings
---@param window table The IMGUI window object to monitor
---@param callback_id string Unique identifier for this callback (allows multiple callbacks per window)
---@param callback? MazzleDocsWindowResizeCallback|nil The function to call on resize, or nil to unregister
---@return boolean success True if callback was registered/unregistered successfully
function MazzleDocsAPI.OnWindowResize(window, callback_id, callback) end

-- External Rendering

---@class MazzleDocsRenderOptions Options for external content rendering
---@field theme_name? string Optional theme preset name
---@field content_width? integer Optional content area width in pixels
---@field image_config? MazzleDocsImageConfig Optional image configuration

---Render MazzleDocs content inside an external IMGUI container (without state persistence)
---@param container table IMGUI container element (Cell, ChildWindow, etc.)
---@param content_table MazzleDocsContentItem[] Array of content items to render
---@param options? MazzleDocsRenderOptions Optional rendering options
---@return table widgets Table of created widgets keyed by widget_id (for widgets that have IDs)
function MazzleDocsAPI.RenderContent(container, content_table, options) end
