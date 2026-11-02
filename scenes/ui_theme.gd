class_name UiTheme
## Visual system: ink-blue rack panels, chamfered corners, cable yellow for the one main action.

const INK := Color("16233a")
const PANEL := Color("1e2f4d")
const PANEL_RAISED := Color("2a3f63")
const LINE := Color("3f5678")
const TEXT := Color("f2f6fb")
const MUTED := Color("a3b3c9")
const CABLE := Color("ffc533")
const CABLE_DARK := Color("e0a400")
const GOOD := Color("3ccf8e")
const WARN := Color("ffb02e")
const BAD := Color("ff5a4f")
const CHAMFER := 7

static var _body: FontVariation
static var _bold: FontVariation
static var _data: FontVariation


static func body_font() -> Font:
	if _body == null:
		_body = _variation("res://art/fonts/SpaceGrotesk.ttf", 500)
	return _body


static func bold_font() -> Font:
	if _bold == null:
		_bold = _variation("res://art/fonts/SpaceGrotesk.ttf", 700)
	return _bold


static func data_font() -> Font:
	if _data == null:
		_data = _variation("res://art/fonts/JetBrainsMono.ttf", 700)
	return _data


static func integrity_color(integrity: float) -> Color:
	if integrity >= 60.0:
		return GOOD
	if integrity >= 30.0:
		return WARN
	return BAD


static func box(fill: Color, border := Color.TRANSPARENT, border_width := 0, margin := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(CHAMFER)
	style.corner_detail = 1  # one segment per corner makes a chamfer, not a curve
	style.set_content_margin_all(margin)
	return style


## For panels that meet the window edge, where a chamfer would leave a notch in the screen corner.
static func flush(fill: Color, margin := 10) -> StyleBoxFlat:
	var style := box(fill, Color.TRANSPARENT, 0, margin)
	style.set_corner_radius_all(0)
	return style


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = 15
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 12))
	theme.set_color("font_color", "Label", TEXT)
	_style_button(theme, "Button", PANEL_RAISED, TEXT)
	_style_button(theme, "PrimaryButton", CABLE, INK)
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_font("font", "PrimaryButton", bold_font())
	theme.set_font_size("font_size", "PrimaryButton", 17)
	theme.set_stylebox("hover", "PrimaryButton", box(Color("ffd566"), CABLE_DARK, 2))
	theme.set_stylebox("pressed", "PrimaryButton", box(CABLE_DARK, CABLE_DARK, 2))
	theme.set_color("font_hover_color", "PrimaryButton", INK)
	theme.set_color("font_pressed_color", "PrimaryButton", INK)
	theme.set_color("font_focus_color", "PrimaryButton", INK)
	theme.set_stylebox("disabled", "PrimaryButton", box(PANEL_RAISED, LINE, 1))
	theme.set_color("font_disabled_color", "PrimaryButton", MUTED)
	_style_button(theme, "RackCard", PANEL_RAISED, TEXT)
	theme.set_type_variation("RackCard", "Button")
	theme.set_stylebox("normal", "RackCard", box(PANEL_RAISED, LINE, 1))
	theme.set_stylebox("hover", "RackCard", box(Color("35507c"), MUTED, 1))
	theme.set_stylebox("pressed", "RackCard", box(Color("35507c"), CABLE, 3))
	theme.set_stylebox("hover_pressed", "RackCard", box(Color("35507c"), CABLE, 3))
	theme.set_stylebox("Normal", "RichTextLabel", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	theme.set_font("normal_font", "RichTextLabel", body_font())
	theme.set_font("bold_font", "RichTextLabel", bold_font())
	theme.set_font_size("normal_font_size", "RichTextLabel", 16)
	theme.set_font_size("bold_font_size", "RichTextLabel", 16)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_stylebox("panel", "TooltipPanel", box(INK, CABLE, 1, 10))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font("font", "TooltipLabel", body_font())
	theme.set_stylebox("background", "ProgressBar", box(INK, LINE, 1, 0))
	theme.set_stylebox("fill", "ProgressBar", box(GOOD, Color.TRANSPARENT, 0, 0))
	return theme


static func _style_button(theme: Theme, type: String, fill: Color, text: Color) -> void:
	theme.set_stylebox("normal", type, box(fill, Color.TRANSPARENT, 0))
	theme.set_stylebox("hover", type, box(fill.lightened(0.1), MUTED, 1))
	theme.set_stylebox("pressed", type, box(CABLE, CABLE, 1))
	theme.set_stylebox("hover_pressed", type, box(CABLE, CABLE, 1))
	theme.set_stylebox("disabled", type, box(fill.darkened(0.2), Color.TRANSPARENT, 0))
	theme.set_stylebox("focus", type, box(Color.TRANSPARENT, TEXT, 2))
	theme.set_color("font_color", type, text)
	theme.set_color("font_hover_color", type, text)
	theme.set_color("font_pressed_color", type, INK)
	theme.set_color("font_hover_pressed_color", type, INK)
	theme.set_color("font_focus_color", type, text)
	theme.set_color("font_disabled_color", type, MUTED)


static func _variation(path: String, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font
