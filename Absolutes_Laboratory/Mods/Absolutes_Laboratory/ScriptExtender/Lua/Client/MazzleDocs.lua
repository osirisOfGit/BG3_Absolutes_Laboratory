-- MazzleDocs Content Representation System
-- IDE Helper File with Lua Annotations for Documentation Creation
-- Provides autocomplete, validation, and documentation for MazzleDocs content structures

---@class MazzleDocs
MazzleDocs = Mods["Mazzle_Docs"]

---@param parent ExtuiTreeParent
---@param document MazzleDocsDocumentation
---@return ExtuiImageButton
function MazzleDocs:addDocButton(parent, document)
	local button = Styler:ImageButton(parent:AddImageButton("Docs", "Item_BOOK_GEN_Books_Row_Multiple_D", Styler:ScaleFactor({ 32, 32 })))
	button.OnClick = function()
		self.Create_Mazzle_Docs(document, Absolutes_Lab_Doc_Config)
	end

	return button
end

---@class MazzleDocsSlide
---@field Topic string The main topic/chapter this slide belongs to
---@field SubTopic? string Optional subtopic for grouping related slides under the same topic
---@field content MazzleDocsContentItem[] Array of content widgets that make up this slide

---@class MazzleDocsDocumentation
---@field [integer] MazzleDocsSlide Array of slides that make up the documentation

---@class MazzleDocsConfig
---@field window_name string Display name for the documentation window
---@field type "documentation"|"tutorial" Type of window to create
---@field window_height? integer Height of the window in pixels (default: 980)
---@field window_width? integer Width of the window in pixels (default: 1200)
---@field ToC_Starts_Hidden? boolean Whether Table of Contents starts hidden (default: false)
---@field mod_name string Internal name used for the mod
---@field documentation_name string Variable name for the documentation table
---@field theme_override? MazzleDocsThemeOverride Optional theme customizations

---@class MazzleDocsThemeOverride
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
---@field nav_topic_text? [number, number, number, number] Top-level topic tree node text color {r, g, b, a}
---@field nav_subtopic_text? [number, number, number, number] Subtopic tree node text color {r, g, b, a}
---@field nav_slide_text? [number, number, number, number] Individual slide button text color {r, g, b, a}
---@field nav_button_text? [number, number, number, number] Expand/collapse button text color {r, g, b, a}
---@field content_text? [number, number, number, number] Standard content paragraph text {r, g, b, a}
---@field heading_text? [number, number, number, number] Heading text color {r, g, b, a}
---@field subheading_text? [number, number, number, number] Subheading text color {r, g, b, a}
---@field note_text? [number, number, number, number] Note text color {r, g, b, a}
---@field callout_text? [number, number, number, number] CallOut content text color {r, g, b, a}
---@field code_text? [number, number, number, number] Code block text color {r, g, b, a}
---@field bullet_text? [number, number, number, number] Bullet point text color {r, g, b, a}
---@field separator_color? [number, number, number, number] Horizontal separator line color {r, g, b, a}

-- Base content item interface
---@class MazzleDocsContentItem
---@field type MazzleDocsContentType The type of content widget
---@field text? string|string[] The main text content (required for most types)
---@field font? string Custom font name (exact font, takes precedence over fontsize)
---@field fontsize? MazzleDoctsFontSize Size-based font name
---@field size? MazzleDoctsFontSize Alternative way to specify font size (same as fontsize)
---@field color? string|[number, number, number, number] Override default color (color name or RGBA array)
---@field centered? boolean Center the content horizontally
---@field left_indent? integer Left margin in pixels

---@alias MazzleDocsContentType
---| "Heading"        # Large title text for major sections
---| "SubHeading"     # Medium title text for subsections
---| "Content"        # Regular paragraph text
---| "Section"        # Section headers with distinctive styling
---| "Note"           # Secondary text with muted appearance
---| "Bullet"         # Creates bulleted lists
---| "CallOut"        # Highlighted text box with custom prefix
---| "Code"           # Formatted code blocks with monospace font
---| "Separator"      # Visual separator line
---| "DynamicButton"  # Interactive buttons for commands
---| "Image"          # Static images

---@alias MazzleDoctsFontSize
---| "Tiny"
---| "Small"
---| "Normal"
---| "Medium"
---| "Large"

-- Text Content Widgets

---@class MazzleDocsHeading : MazzleDocsContentItem
---@field type "Heading"
---@field text string The heading text content
---@field highlighted? boolean Display on dark red banner for tutorial goals

---@class MazzleDocsSubHeading : MazzleDocsContentItem
---@field type "SubHeading"
---@field text string The subheading text content

---@class MazzleDocsContent : MazzleDocsContentItem
---@field type "Content"
---@field text string|string[] Regular paragraph text (string or array for multiple paragraphs)

---@class MazzleDocsSection : MazzleDocsContentItem
---@field type "Section"
---@field text string Section header text with distinctive styling

---@class MazzleDocsNote : MazzleDocsContentItem
---@field type "Note"
---@field text string Note text with muted appearance

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
---@field text string The main callout text content
---@field prefix_color? string Color name for the prefix text
---@field text_block_indent? integer Indentation for the text block in pixels
---@field right_padding_px? integer Right padding space (default: 40)

-- Code Widgets

---@class MazzleDocsCode : MazzleDocsContentItem
---@field type "Code"
---@field text string Code content with preserved formatting

-- Separator Widget

---@class MazzleDoctsSeparator : MazzleDocsContentItem
---@field type "Separator"

-- Interactive Widgets

---@class MazzleDoctsDynamicButton : MazzleDocsContentItem
---@field type "DynamicButton"
---@field label string Text displayed on the button
---@field button_type MazzleDocsDynamicButtonType Type of button action
---@field button_parameters? table Parameters passed to the action handler (varies by button_type)

---@alias MazzleDocsDynamicButtonType
---| "go"                 # Movement command
---| "go_party"           # Party movement command
---| "go_party_separate"  # Separate party movement command
---| "add_spell"          # Add spell to character
---| "remove_spell"       # Remove spell from character
---| "add_passive"        # Add passive to character
---| "remove_passive"     # Remove passive from character
---| "add_status"         # Add status effect to character
---| "remove_status"      # Remove status effect from character
---| "open_docs"          # Open documentation window
---| "open_mcm"           # Open Mod Configuration Menu
---| "broadcast_server"   # Send server broadcast
---| "broadcast_client"   # Send client broadcast

-- Image Widgets

---@class MazzleDocsImage : MazzleDocsContentItem
---@field type "Image"
---@field image_index integer Index of the image to display
---@field image_width? integer Width override in pixels
