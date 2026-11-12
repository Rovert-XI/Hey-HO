class_name UITema
extends RefCounted
## Paleta y tema visual de ¡Hey HO!
##
## Dos paletas, dos usos:
##  - ESTUDIO (Rovert XI, del logo): menús y pantallas. Es la "identidad" de la interfaz.
##  - JUEGO (Documento de concepto, sección 9): HUD. Cada color conserva su función:
##      AZUL MAR = agua / pérdida · MADERA = lo que se usa o falta lavar · CREMA = lo que vale
##      VERDE = acierto · ROJO = peligro (y solo peligro).
## Regla de oro: el NARANJA del estudio nunca aparece en el HUD, para no confundirlo con el ROJO de peligro.

# --- Estudio (logo Rovert XI) ---
const NARANJA := Color("#FF5722")
const CELESTE := Color("#CBE2FE")
const NOCHE := Color("#0D1B2A")
const AZUL := Color("#10288C")

# --- Juego (Documento de concepto) ---
const MAR := Color("#1F4E79")
const MADERA := Color("#8B5A2B")
const CREMA := Color("#F6E7B0")
const VERDE := Color("#4CAF50")
const ROJO := Color("#D63A3A")

const RUTA_TEMA := "res://ui/tema/heyho_tema.tres"


## Crea un StyleBoxFlat con los parámetros que más usamos.
static func caja(fondo: Color, borde := Color(0, 0, 0, 0), grosor := 0, radio := 10,
		margen_h := 16.0, margen_v := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(radio)
	s.content_margin_left = margen_h
	s.content_margin_right = margen_h
	s.content_margin_top = margen_v
	s.content_margin_bottom = margen_v
	s.anti_aliasing = true
	s.corner_detail = 12
	return s


## Construye el Theme completo. Se guarda en res://ui/tema/heyho_tema.tres
static func crear() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22

	# ---------- Label ----------
	t.set_color("font_color", "Label", CELESTE)
	_etiqueta(t, "LabelTitulo", 56, CREMA, 10)
	_etiqueta(t, "LabelSubtitulo", 26, CELESTE, 0)
	_etiqueta(t, "LabelOro", 30, CREMA, 6)
	_etiqueta(t, "LabelTiempo", 40, CREMA, 8)
	_etiqueta(t, "LabelTiempoPeligro", 40, ROJO, 8)
	_etiqueta(t, "LabelPeque", 16, Color(CELESTE, 0.85), 0)
	_etiqueta(t, "LabelPeligro", 18, ROJO, 5)
	_etiqueta(t, "LabelExito", 22, VERDE, 5)
	_etiqueta(t, "LabelAviso", 32, CREMA, 8)
	_etiqueta(t, "LabelTecla", 22, CREMA, 5)
	_etiqueta(t, "LabelPerla", 40, NOCHE, 0)

	# ---------- Button ----------
	_boton(t, "Button",
		caja(Color(NOCHE, 0.92), Color(CELESTE, 0.45), 3, 12, 28, 12),
		caja(AZUL, CELESTE, 3, 12, 28, 12),
		caja(Color("#081019"), NARANJA, 3, 12, 28, 12),
		caja(Color(NOCHE, 0.5), Color(CELESTE, 0.15), 3, 12, 28, 12),
		caja(Color(0, 0, 0, 0), NARANJA, 4, 12, 28, 12),
		CELESTE, CREMA)
	t.set_type_variation("BotonPrimario", "Button")
	_boton(t, "BotonPrimario",
		caja(NARANJA, CREMA, 3, 12, 28, 12),
		caja(Color("#FF7043"), CREMA, 3, 12, 28, 12),
		caja(Color("#E64A19"), CREMA, 3, 12, 28, 12),
		caja(Color(NARANJA, 0.35), Color(CREMA, 0.2), 3, 12, 28, 12),
		caja(Color(0, 0, 0, 0), CREMA, 4, 12, 28, 12),
		NOCHE, NOCHE)
	t.set_type_variation("BotonPequeno", "Button")
	t.set_font_size("font_size", "BotonPequeno", 16)
	t.set_stylebox("normal", "BotonPequeno", caja(Color(NOCHE, 0.92), Color(CELESTE, 0.45), 2, 8, 12, 6))
	t.set_stylebox("hover", "BotonPequeno", caja(AZUL, CELESTE, 2, 8, 12, 6))
	t.set_stylebox("pressed", "BotonPequeno", caja(Color("#081019"), NARANJA, 2, 8, 12, 6))
	t.set_stylebox("disabled", "BotonPequeno", caja(Color(NOCHE, 0.5), Color(CELESTE, 0.15), 2, 8, 12, 6))
	t.set_stylebox("focus", "BotonPequeno", caja(Color(0, 0, 0, 0), NARANJA, 3, 8, 12, 6))

	# ---------- Paneles ----------
	var panel := caja(Color(NOCHE, 0.9), Color(CELESTE, 0.35), 3, 16, 24, 20)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_type_variation("PanelHUD", "PanelContainer")
	t.set_stylebox("panel", "PanelHUD", caja(Color(NOCHE, 0.78), MADERA, 3, 10, 12, 8))
	t.set_type_variation("PanelSlot", "PanelContainer")
	t.set_stylebox("panel", "PanelSlot", caja(Color(NOCHE, 0.6), MADERA, 2, 8, 10, 6))
	t.set_type_variation("PanelSlotActivo", "PanelContainer")
	t.set_stylebox("panel", "PanelSlotActivo", caja(Color(MADERA, 0.35), CREMA, 3, 8, 10, 6))
	t.set_type_variation("PanelLogo", "PanelContainer")
	t.set_stylebox("panel", "PanelLogo", caja(AZUL, Color(CELESTE, 0.5), 3, 14, 8, 8))
	t.set_type_variation("PanelTarjeta", "PanelContainer")
	t.set_stylebox("panel", "PanelTarjeta", caja(Color(NOCHE, 0.96), Color(CELESTE, 0.35), 3, 16, 14, 14))

	# ---------- ProgressBar ----------
	t.set_stylebox("background", "ProgressBar", caja(Color(NOCHE, 0.9), Color(CELESTE, 0.35), 2, 6, 0, 0))
	t.set_stylebox("fill", "ProgressBar", caja(CELESTE, Color(0, 0, 0, 0), 0, 6, 0, 0))
	_barra(t, "BarraVerde", VERDE)
	_barra(t, "BarraCrema", CREMA)
	_barra(t, "BarraMadera", MADERA)
	_barra(t, "BarraRoja", ROJO)

	# ---------- HSlider / HSeparator ----------
	var pista := caja(Color(NOCHE, 0.9), Color(CELESTE, 0.35), 2, 6, 0, 6)
	t.set_stylebox("slider", "HSlider", pista)
	t.set_stylebox("grabber_area", "HSlider", caja(NARANJA, Color(0, 0, 0, 0), 0, 6, 0, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", caja(Color("#FF7043"), Color(0, 0, 0, 0), 0, 6, 0, 6))
	var linea := StyleBoxLine.new()
	linea.color = Color(CELESTE, 0.3)
	linea.thickness = 2
	t.set_stylebox("separator", "HSeparator", linea)
	t.set_constant("separation", "HSeparator", 16)

	# ---------- CheckButton / contenedores ----------
	t.set_color("font_color", "CheckButton", CELESTE)
	t.set_color("font_hover_color", "CheckButton", CREMA)
	t.set_color("font_focus_color", "CheckButton", CREMA)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	return t


static func _etiqueta(t: Theme, nombre: String, tam: int, color: Color, contorno: int) -> void:
	t.set_type_variation(nombre, "Label")
	t.set_font_size("font_size", nombre, tam)
	t.set_color("font_color", nombre, color)
	if contorno > 0:
		t.set_constant("outline_size", nombre, contorno)
		t.set_color("font_outline_color", nombre, NOCHE)


static func _boton(t: Theme, tipo: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox,
		disabled: StyleBox, focus: StyleBox, color: Color, color_resaltado: Color) -> void:
	t.set_stylebox("normal", tipo, normal)
	t.set_stylebox("hover", tipo, hover)
	t.set_stylebox("pressed", tipo, pressed)
	t.set_stylebox("hover_pressed", tipo, pressed)
	t.set_stylebox("disabled", tipo, disabled)
	t.set_stylebox("focus", tipo, focus)
	t.set_color("font_color", tipo, color)
	t.set_color("font_hover_color", tipo, color_resaltado)
	t.set_color("font_focus_color", tipo, color_resaltado)
	t.set_color("font_pressed_color", tipo, color_resaltado)
	t.set_color("font_hover_pressed_color", tipo, color_resaltado)
	t.set_color("font_disabled_color", tipo, Color(color, 0.65))
	t.set_font_size("font_size", tipo, 24)


static func _barra(t: Theme, nombre: String, color: Color) -> void:
	t.set_type_variation(nombre, "ProgressBar")
	t.set_stylebox("fill", nombre, caja(color, Color(0, 0, 0, 0), 0, 6, 0, 0))
