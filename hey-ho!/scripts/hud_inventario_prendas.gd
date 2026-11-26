extends CanvasLayer
class_name HudInventarioPrendas

signal tipo_seleccionado_cambiado(nuevo_estado: PrendaProyectil.EstadoPrenda)

const ESTADOS_ORDEN: Array[PrendaProyectil.EstadoPrenda] = [
	PrendaProyectil.EstadoPrenda.SUCIA,
	PrendaProyectil.EstadoPrenda.LAVADA,
	PrendaProyectil.EstadoPrenda.SECA
]

const INFO_ESTADOS := {
	PrendaProyectil.EstadoPrenda.SUCIA: {
		"nombre": "Sucia",
		"color": Color(0.468, 0.334, 0.127, 1.0)
	},
	PrendaProyectil.EstadoPrenda.LAVADA: {
		"nombre": "Lavada",
		"color": Color(0.35, 0.72, 0.95, 1.0)
	},
	PrendaProyectil.EstadoPrenda.SECA: {
		"nombre": "Seca",
		"color": Color(0.96, 0.96, 0.92, 1.0)
	}
}

var estado_activo: PrendaProyectil.EstadoPrenda = PrendaProyectil.EstadoPrenda.SUCIA
var _conteos := {
	PrendaProyectil.EstadoPrenda.SUCIA: 0,
	PrendaProyectil.EstadoPrenda.LAVADA: 0,
	PrendaProyectil.EstadoPrenda.SECA: 0
}

var _paneles := {}
var _labels_cantidad := {}
var _estilos_normal := {}
var _estilos_activo := {}


func _ready() -> void:
	layer = 10
	_construir_interfaz()
	_refrescar_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			rotar_seleccion(1)
			get_viewport().set_input_as_handled()


func actualizar_conteos(sucia: int, lavada: int, seca: int, activo: PrendaProyectil.EstadoPrenda) -> void:
	_conteos[PrendaProyectil.EstadoPrenda.SUCIA] = maxi(0, sucia)
	_conteos[PrendaProyectil.EstadoPrenda.LAVADA] = maxi(0, lavada)
	_conteos[PrendaProyectil.EstadoPrenda.SECA] = maxi(0, seca)
	estado_activo = activo
	_refrescar_visual()


func rotar_seleccion(paso: int = 1) -> void:
	var idx := ESTADOS_ORDEN.find(estado_activo)
	if idx == -1:
		idx = 0
	var siguiente_idx := posmod(idx + paso, ESTADOS_ORDEN.size())
	seleccionar_estado(ESTADOS_ORDEN[siguiente_idx])


func seleccionar_estado(nuevo_estado: PrendaProyectil.EstadoPrenda) -> void:
	if estado_activo == nuevo_estado:
		return
	estado_activo = nuevo_estado
	_refrescar_visual()
	tipo_seleccionado_cambiado.emit(estado_activo)


func _construir_interfaz() -> void:
	var contenedor_raiz := Control.new()
	contenedor_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenedor_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor_raiz)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	fila.anchor_left = 0.5
	fila.anchor_right = 0.5
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0
	fila.offset_left = -185.0
	fila.offset_right = 185.0
	fila.offset_top = -168.0
	fila.offset_bottom = -114.0
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor_raiz.add_child(fila)

	for estado in ESTADOS_ORDEN:
		var info: Dictionary = INFO_ESTADOS[estado]
		var color_prenda: Color = info["color"]

		var estilo_norm := StyleBoxFlat.new()
		estilo_norm.bg_color = Color(0.11, 0.13, 0.17, 0.84)
		estilo_norm.border_color = Color(0.32, 0.36, 0.44, 0.9)
		estilo_norm.set_border_width_all(2)
		estilo_norm.set_corner_radius_all(8)
		estilo_norm.content_margin_left = 10
		estilo_norm.content_margin_right = 10
		estilo_norm.content_margin_top = 6
		estilo_norm.content_margin_bottom = 6

		var estilo_act := estilo_norm.duplicate() as StyleBoxFlat
		estilo_act.bg_color = Color(0.18, 0.22, 0.29, 0.96)
		estilo_act.border_color = Color(1.0, 0.84, 0.28, 1.0)
		estilo_act.set_border_width_all(3)

		_estilos_normal[estado] = estilo_norm
		_estilos_activo[estado] = estilo_act

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(106, 48)
		panel.add_theme_stylebox_override("panel", estilo_norm)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_on_panel_gui_input.bind(estado))
		fila.add_child(panel)
		_paneles[estado] = panel

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(hbox)

		var muestra := ColorRect.new()
		muestra.custom_minimum_size = Vector2(16, 16)
		muestra.color = color_prenda
		muestra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		muestra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(muestra)

		var texto := Label.new()
		texto.text = "%s: 0" % info["nombre"]
		texto.add_theme_font_size_override("font_size", 14)
		texto.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(texto)
		_labels_cantidad[estado] = texto

	var etiqueta_tecla := Label.new()
	etiqueta_tecla.text = "[Q]"
	etiqueta_tecla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta_tecla.add_theme_font_size_override("font_size", 13)
	etiqueta_tecla.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94, 0.9))
	fila.add_child(etiqueta_tecla)


func _on_panel_gui_input(event: InputEvent, estado: PrendaProyectil.EstadoPrenda) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		seleccionar_estado(estado)


func _refrescar_visual() -> void:
	for estado in ESTADOS_ORDEN:
		if not _paneles.has(estado):
			continue
		var panel: PanelContainer = _paneles[estado]
		var lbl: Label = _labels_cantidad[estado]
		var info: Dictionary = INFO_ESTADOS[estado]
		var cantidad: int = _conteos[estado]

		lbl.text = "%s: %d" % [info["nombre"], cantidad]
		var es_activo: bool = (estado == estado_activo)
		panel.add_theme_stylebox_override("panel", _estilos_activo[estado] if es_activo else _estilos_normal[estado])
		panel.modulate.a = 1.0 if (es_activo or cantidad > 0) else 0.62
