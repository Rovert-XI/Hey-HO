class_name HudHeyHo
extends CanvasLayer

const ESCENA_FILA_SOGA: PackedScene = preload("res://componentes/fila_soga.tscn")
const ESCENA_BARRA_PACIENCIA: PackedScene = preload("res://componentes/barra_paciencia.tscn")
const CARGA_MAX := 1.0

const PLATAFORMAS := {
	"lavadora": "Lavadora",
	"tendedero": "Tendedero",
	"despacho": "Despacho",
}

@export var segundos_inactividad: float = 3.0
@export_range(0.0, 1.0, 0.05) var opacidad_reposo: float = 0.5
@export var duracion_fade: float = 0.35

@onready var _inferior: Control = %Inferior
@onready var _oro: Label = %Oro
@onready var _barra_oro: ProgressBar = %BarraOro
@onready var _marca_minimo: ColorRect = %MarcaMinimo
@onready var _texto_minimo: Label = %TextoMinimo
@onready var _tiempo: Label = %Tiempo
@onready var _dia: Label = %Dia
@onready var _barra_reparacion: ProgressBar = %BarraReparacion
@onready var _texto_reparacion: Label = %TextoReparacion
@onready var _panel_carga: PanelContainer = $Raiz/Inferior/ColumnaInferior/ContenedorCarga/PanelCarga
@onready var _lista_sogas: VBoxContainer = %ListaSogas
@onready var _lista_pedidos: VBoxContainer = %ListaPedidos
@onready var _franja: ColorRect = %Franja
@onready var _relleno: ColorRect = %Relleno
@onready var _aviso: Label = %AvisoTexto
@onready var _flotantes: Control = %Flotantes
@onready var _borde_alerta: Panel = %BordeAlerta
@onready var _slot_resortera: Control = %SlotResortera
@onready var _slot_piedra: Control = %SlotPiedra
@onready var _slot_cana: Control = %SlotCana
@onready var _extra_piedra: Label = %ExtraPiedra

var _filas_sogas: Dictionary = {}
var _pedidos: Dictionary = {}
var _oro_actual := 0
var _oro_minimo := 0
var _oro_maximo := 90
var _tiempo_inactividad := 0.0
var _carga_mostrada := false
var _en_reposo := false
var _tween_reposo: Tween
var _tween_aviso: Tween
var _tween_alerta: Tween
var _item_actual := ""


func _ready() -> void:
	_aviso.modulate.a = 0.0
	_borde_alerta.hide()
	_franja.visible = false
	set_piedras(3)
	_actualizar_pistas()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		_tiempo_inactividad = 0.0
		if _en_reposo:
			_en_reposo = false
			_fundir(1.0)


func _process(delta: float) -> void:
	if _en_reposo:
		return
	_tiempo_inactividad += delta
	if _tiempo_inactividad >= segundos_inactividad:
		_en_reposo = true
		_fundir(opacidad_reposo)


func iniciar_nivel(numero: int) -> void:
	var datos := EstadoJuego.datos_nivel(numero)
	_dia.text = "Día %d" % numero
	_oro_actual = 0
	_oro_minimo = int(datos.minimo)
	_oro_maximo = maxi(int(datos.oro_max), 1)
	_barra_oro.max_value = _oro_maximo
	_barra_reparacion.max_value = EstadoJuego.COSTO_REPARACION
	_barra_reparacion.value = EstadoJuego.oro_total
	_texto_reparacion.text = "Barco %d / %d" % [EstadoJuego.oro_total, EstadoJuego.COSTO_REPARACION]
	_texto_minimo.text = "Mínimo %d oro" % _oro_minimo
	var fraccion_minima := clampf(float(_oro_minimo) / float(_oro_maximo), 0.0, 1.0)
	_marca_minimo.anchor_left = fraccion_minima
	_marca_minimo.anchor_right = fraccion_minima
	set_oro(0)
	set_tiempo(float(datos.duracion))
	equipar("resortera")
	mostrar_carga(false)
	set_carga(0.0)
	_actualizar_pistas()
	_asegurar_filas_sogas()


func conectar_sogas(sistema: SistemaSogas) -> void:
	_asegurar_filas_sogas()
	for plataforma: String in PLATAFORMAS:
		var fila := _filas_sogas[plataforma] as FilaSoga
		fila.poner_resistencia(0, float(sistema.sogas[plataforma][0]))
		fila.poner_resistencia(1, float(sistema.sogas[plataforma][1]))
		fila.poner_inestable(bool(sistema.desestab[plataforma]))
		_filas_sogas[plataforma] = fila

	if not sistema.soga_cambio.is_connected(_al_cambiar_soga):
		sistema.soga_cambio.connect(_al_cambiar_soga)
	if not sistema.plataforma_desestabilizada.is_connected(_al_cambiar_estabilidad):
		sistema.plataforma_desestabilizada.connect(_al_cambiar_estabilidad)
	if not sistema.reparacion_progreso.is_connected(_al_cambiar_reparacion):
		sistema.reparacion_progreso.connect(_al_cambiar_reparacion)


func conectar_loro(loro: Loro) -> void:
	if not loro.aviso_graznido.is_connected(_al_aviso_loro):
		loro.aviso_graznido.connect(_al_aviso_loro)
	if not loro.loro_huyo.is_connected(_al_loro_huyo):
		loro.loro_huyo.connect(_al_loro_huyo)


func set_tiempo(segundos: float) -> void:
	_tiempo.text = EstadoJuego.formato_tiempo(segundos)
	_tiempo.add_theme_color_override("font_color", Color("#f3d9a1") if segundos > 15.0 else Color("#ff6b5e"))


func set_oro(cantidad: int) -> void:
	_oro_actual = maxi(cantidad, 0)
	_oro.text = str(_oro_actual)
	_barra_oro.value = _oro_actual


func set_piedras(cantidad: int) -> void:
	_extra_piedra.text = "x%d" % maxi(cantidad, 0)


func set_carga(fraccion: float) -> void:
	var carga := clampf(fraccion, 0.0, 1.0)
	_relleno.anchor_right = carga
	_franja.visible = carga > 0.0
	_panel_carga.visible = carga > 0.0 or _carga_mostrada


func mostrar_carga(visible: bool) -> void:
	_carga_mostrada = visible
	if not visible:
		set_carga(0.0)
	else:
		_panel_carga.show()


func poner_soga(plataforma: String, indice: int, resistencia: float) -> void:
	_asegurar_filas_sogas()
	var fila := _filas_sogas.get(plataforma) as FilaSoga
	if is_instance_valid(fila):
		fila.poner_resistencia(indice, resistencia)


func poner_inestable(plataforma: String, inestable: bool) -> void:
	_asegurar_filas_sogas()
	var fila := _filas_sogas.get(plataforma) as FilaSoga
	if is_instance_valid(fila):
		fila.poner_inestable(inestable)


func poner_reparacion(plataforma: String, fraccion: float) -> void:
	_asegurar_filas_sogas()
	var fila := _filas_sogas.get(plataforma) as FilaSoga
	if is_instance_valid(fila):
		fila.poner_reparacion(fraccion)


func alerta_borde(segundos: float) -> void:
	if _tween_alerta and _tween_alerta.is_valid():
		_tween_alerta.kill()
	_borde_alerta.show()
	_tween_alerta = create_tween()
	_tween_alerta.tween_interval(maxf(segundos, 0.0))
	_tween_alerta.tween_callback(_borde_alerta.hide)


func equipar(item: String) -> void:
	_item_actual = item
	_slot_resortera.modulate = Color("#ffe4a3") if item == "resortera" else Color.WHITE
	_slot_piedra.modulate = Color("#ffe4a3") if item == "piedra" else Color.WHITE
	_slot_cana.modulate = Color("#ffe4a3") if item == "cana" else Color.WHITE


func agregar_pedido(id: int, titulo: String, paciencia: float, prendas: int) -> void:
	if _pedidos.has(id):
		return
	var barra := ESCENA_BARRA_PACIENCIA.instantiate() as BarraPaciencia
	_lista_pedidos.add_child(barra)
	barra.configurar(titulo, paciencia, prendas)
	_pedidos[id] = barra


func actualizar_pedido(id: int, restante: float) -> void:
	var barra := _pedidos.get(id) as BarraPaciencia
	if is_instance_valid(barra):
		barra.actualizar(restante)


func quitar_pedido(id: int, entregado: bool) -> void:
	var barra := _pedidos.get(id) as BarraPaciencia
	_pedidos.erase(id)
	if is_instance_valid(barra):
		barra.cerrar(entregado)


func mostrar_pago(cantidad: int) -> void:
	var texto := "+%d oro" % cantidad if cantidad > 0 else "Pedido perdido"
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 22)
	etiqueta.add_theme_color_override("font_color", Color("#f5d992") if cantidad > 0 else Color("#ff6b5e"))
	etiqueta.add_theme_color_override("font_outline_color", Color("#101a29"))
	etiqueta.add_theme_constant_override("outline_size", 5)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.55) - Vector2(90.0, 16.0)
	etiqueta.custom_minimum_size = Vector2(180.0, 32.0)
	_flotantes.add_child(etiqueta)
	var tween := create_tween()
	tween.tween_property(etiqueta, "position:y", etiqueta.position.y - 36.0, 0.8)
	tween.parallel().tween_property(etiqueta, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(etiqueta.queue_free)


func mostrar_aviso(texto: String, tipo := "info") -> void:
	if _tween_aviso and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_aviso.text = texto
	_aviso.add_theme_color_override("font_color", _color_aviso(tipo))
	_aviso.modulate.a = 1.0
	_borde_alerta.visible = tipo == "peligro"
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(2.2)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.35)
	_tween_aviso.tween_callback(func() -> void: _borde_alerta.hide())


func _fundir(alfa: float) -> void:
	if _tween_reposo and _tween_reposo.is_valid():
		_tween_reposo.kill()
	_tween_reposo = create_tween()
	_tween_reposo.tween_property(_inferior, "modulate:a", alfa, duracion_fade)


func _actualizar_pistas() -> void:
	for nodo in get_tree().get_nodes_in_group("pista_tecla"):
		if nodo is Control:
			(nodo as Control).visible = EstadoJuego.pistas_teclas


func _asegurar_filas_sogas() -> void:
	if not _filas_sogas.is_empty():
		return
	for plataforma: String in PLATAFORMAS:
		var fila := ESCENA_FILA_SOGA.instantiate() as FilaSoga
		_lista_sogas.add_child(fila)
		fila.configurar(plataforma, PLATAFORMAS[plataforma])
		_filas_sogas[plataforma] = fila


func _al_cambiar_soga(plataforma: String, indice: int, resistencia: float) -> void:
	var fila := _filas_sogas.get(plataforma) as FilaSoga
	if is_instance_valid(fila):
		fila.poner_resistencia(indice, resistencia)


func _al_cambiar_estabilidad(plataforma: String, inestable: bool) -> void:
	var fila := _filas_sogas.get(plataforma) as FilaSoga
	if is_instance_valid(fila):
		fila.poner_inestable(inestable)


func _al_cambiar_reparacion(plataforma: String, fraccion: float) -> void:
	var fila := _filas_sogas.get(plataforma) as FilaSoga
	if is_instance_valid(fila):
		fila.poner_reparacion(fraccion)


func _al_aviso_loro(_gancho: int) -> void:
	mostrar_aviso("¡Se acerca el loro! Selecciona la piedra (2) y haz clic sobre él", "peligro")


func _al_loro_huyo(_gancho: int) -> void:
	mostrar_aviso("¡El loro salió volando!", "exito")


func _color_aviso(tipo: String) -> Color:
	match tipo:
		"exito":
			return Color("#9fe0a2")
		"peligro":
			return Color("#ff8b76")
		_:
			return Color("#f3d9a1")
