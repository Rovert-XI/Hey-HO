class_name GestorNivel1
extends Node

const TOTAL_CLIENTES := 3
const PRIMER_BARCO_SEG := 3.0
const PRENDAS_POR_CLIENTE := 2
const ORO_POR_PEDIDO := 30
const ORO_MAXIMO := 90
const ORO_MINIMO_APROBAR := 54

@export var duracion_nivel := 150.0
@export var intervalo_barcos := 35.0
@export var paciencia_cliente := 65.0
@export var distancia_izquierda_muelle := 2.45
@export var separacion_z_barcos := 2.35
@export var ocultar_canasto_provisional := true
@export var escena_prenda_recolectable: PackedScene

var _estaciones: EstacionesRopa
var _despacho: Node3D
var _municion: MunicionManager
var _jugador: Node3D
var _loro: Node3D

var _tiempo_restante: float = 150.0
var _tiempo_transcurrido: float = 0.0
var _barcos_generados: int = 0
var _barcos_finalizados: int = 0
var _clientes_atendidos: int = 0
var _oro_actual: int = 0
var _nivel_terminado: bool = false
var _secas_previas: int = 0
var _barcos_activos: Array[BarcoCliente] = []
var _puntos_muelle: Array[Vector3] = []

var _hud_layer: CanvasLayer
var _label_tiempo: Label
var _label_oro: Label
var _label_clientes: Label
var _label_aviso: Label
var _panel_final: PanelContainer
var _label_resultado_titulo: Label
var _label_resultado_detalle: Label


func _ready() -> void:
	add_to_group("gestor_nivel")
	_tiempo_restante = duracion_nivel

	var raiz := get_tree().current_scene
	if raiz == null:
		return

	_estaciones = raiz.find_child("EstacionesRopa", true, false) as EstacionesRopa
	_despacho = raiz.find_child("PlataformaDespacho", true, false) as Node3D
	_municion = raiz.find_child("MunicionManager", true, false) as MunicionManager
	_jugador = raiz.find_child("CharacterBody3D2", true, false) as Node3D
	if _jugador == null:
		_jugador = raiz.find_child("PlayerPirata", true, false) as Node3D

	if ocultar_canasto_provisional:
		_desactivar_canasto(raiz)

	_resolver_escena_recolectable(raiz)
	_calcular_puntos_muelle(raiz)

	if _estaciones != null:
		_secas_previas = _estaciones.secas
		if not _estaciones.mano_cambio.is_connected(_on_mano_cambio):
			_estaciones.mano_cambio.connect(_on_mano_cambio)

	_conectar_loro_carlos(raiz)
	_construir_hud_jornada()
	_actualizar_hud()


func _conectar_loro_carlos(raiz: Node) -> void:
	_loro = raiz.find_child("Loro", true, false) as Node3D

	if _loro == null and ResourceLoader.exists("res://scripts/loro.gd"):
		var script_loro := load("res://scripts/loro.gd") as Script
		if script_loro != null:
			_loro = script_loro.new() as Node3D
			if _loro != null:
				_loro.name = "Loro"
				raiz.add_child.call_deferred(_loro)

	if _loro == null:
		return

	_alinear_ganchos_loro.call_deferred()

	if _estaciones != null:
		if _estaciones.has_signal("prenda_tendida") and _loro.has_method("prenda_tendida"):
			if not _estaciones.prenda_tendida.is_connected(_loro.prenda_tendida):
				_estaciones.prenda_tendida.connect(_loro.prenda_tendida)
		if _estaciones.has_signal("prenda_retirada") and _loro.has_method("prenda_retirada"):
			if not _estaciones.prenda_retirada.is_connected(_loro.prenda_retirada):
				_estaciones.prenda_retirada.connect(_loro.prenda_retirada)
		if _loro.has_signal("prenda_robada") and _estaciones.has_method("robar"):
			if not _loro.prenda_robada.is_connected(_estaciones.robar):
				_loro.prenda_robada.connect(_estaciones.robar)

	if _loro.has_signal("aviso_graznido"):
		_loro.aviso_graznido.connect(_on_loro_aviso)
	if _loro.has_signal("loro_llego"):
		_loro.loro_llego.connect(_on_loro_llego)
	if _loro.has_signal("loro_huyo"):
		_loro.loro_huyo.connect(_on_loro_espantado)
	if _loro.has_signal("prenda_robada"):
		_loro.prenda_robada.connect(_on_loro_robo)


func _alinear_ganchos_loro() -> void:
	if not is_instance_valid(_loro) or not _loro.is_inside_tree() or _estaciones == null:
		return
	if "posiciones_gancho" in _loro and "pos_ganchos" in _estaciones:
		var puntos_ganchos: Array[Vector3] = []
		for pos_local in _estaciones.pos_ganchos:
			var pos_mundo: Vector3 = _estaciones.to_global(pos_local + Vector3(0.0, 0.35, 0.0))
			puntos_ganchos.append(_loro.to_local(pos_mundo))
		_loro.posiciones_gancho = puntos_ganchos


func _desactivar_canasto(raiz: Node) -> void:
	for nombre in ["CanastoCliente", "CanastoClientes"]:
		var canasto := raiz.find_child(nombre, true, false)
		if canasto != null:
			if canasto is Node3D:
				(canasto as Node3D).visible = false
			canasto.process_mode = Node.PROCESS_MODE_DISABLED


func _resolver_escena_recolectable(raiz: Node) -> void:
	if escena_prenda_recolectable != null:
		return

	var muestra := raiz.find_child("PrendaRecolecta", true, false)
	if muestra != null and not muestra.scene_file_path.is_empty():
		escena_prenda_recolectable = load(muestra.scene_file_path) as PackedScene
		if escena_prenda_recolectable != null:
			return

	for ruta in [
		"res://Scenes/prenda_recolectable.tscn",
		"res://prenda_recolectable.tscn"
	]:
		if ResourceLoader.exists(ruta):
			escena_prenda_recolectable = load(ruta) as PackedScene
			if escena_prenda_recolectable != null:
				return


func _calcular_puntos_muelle(raiz: Node) -> void:
	_puntos_muelle.clear()

	for i in range(1, TOTAL_CLIENTES + 1):
		var marcador := raiz.find_child("MuelleBarco" + str(i), true, false) as Node3D
		if marcador != null:
			_puntos_muelle.append(marcador.global_position)

	if _puntos_muelle.size() == TOTAL_CLIENTES:
		return

	_puntos_muelle.clear()
	var base := Vector3(-1.5, -0.25, 0.0)
	if _despacho != null:
		base = Vector3(
			_despacho.global_position.x - distancia_izquierda_muelle,
			_despacho.global_position.y - 0.25,
			_despacho.global_position.z
		)

	for i in TOTAL_CLIENTES:
		var offset_z := (float(i) - 1.0) * separacion_z_barcos
		_puntos_muelle.append(Vector3(base.x, base.y, base.z + offset_z))


func _process(delta: float) -> void:
	if _nivel_terminado:
		return

	_tiempo_transcurrido += delta
	_tiempo_restante = maxf(0.0, duracion_nivel - _tiempo_transcurrido)

	if _barcos_generados < TOTAL_CLIENTES:
		var momento_llegada: float = PRIMER_BARCO_SEG + float(_barcos_generados) * intervalo_barcos
		if _tiempo_transcurrido >= momento_llegada:
			_generar_barco_cliente(_barcos_generados + 1)

	_actualizar_hud()

	if _tiempo_restante <= 0.0 or (_barcos_generados >= TOTAL_CLIENTES and _barcos_finalizados >= TOTAL_CLIENTES):
		_finalizar_nivel()


func _generar_barco_cliente(numero: int) -> void:
	_barcos_generados += 1

	var indice: int = clampi(numero - 1, 0, _puntos_muelle.size() - 1)
	var pos_muelle: Vector3 = _puntos_muelle[indice]
	var pos_inicio: Vector3 = pos_muelle + Vector3(-7.5, 0.0, 0.0)
	var pos_salida: Vector3 = pos_muelle + Vector3(-8.5, 0.0, 0.0)

	var barco := BarcoCliente.new()
	barco.name = "BarcoCliente_" + str(numero)
	barco.prendas_requeridas = PRENDAS_POR_CLIENTE
	barco.recompensa_oro = ORO_POR_PEDIDO
	barco.configurar(numero, pos_inicio, pos_muelle, pos_salida, paciencia_cliente)

	barco.pedido_aceptado.connect(_on_barco_pedido_aceptado)
	barco.pedido_completado.connect(_on_barco_pedido_completado)
	barco.pedido_perdido.connect(_on_barco_pedido_perdido)

	get_tree().current_scene.add_child(barco)
	_barcos_activos.append(barco)
	_mostrar_aviso("Llegó el Barco #" + str(numero) + ". Haz clic en él para recibir sus 2 prendas.")


func _on_barco_pedido_aceptado(barco: BarcoCliente, cantidad: int) -> void:
	_entregar_prendas_al_jugador(cantidad)
	_mostrar_aviso("Pedido #" + str(barco.numero_cliente) + " aceptado: +" + str(cantidad) + " prendas sucias en tu inventario.")


func _entregar_prendas_al_jugador(cantidad: int) -> void:
	var estado_sucia := int(PrendaProyectil.EstadoPrenda.SUCIA)

	if _municion != null:
		for metodo in ["agregar_prendas", "agregar_prenda", "sumar_prendas", "recibir_prenda"]:
			if _municion.has_method(metodo):
				var num_args := _obtener_num_args(_municion, metodo)
				if num_args == 2:
					_municion.call(metodo, cantidad, estado_sucia)
					return
				elif num_args == 1:
					for _i in cantidad:
						_municion.call(metodo, estado_sucia)
					return

	if escena_prenda_recolectable != null and _jugador != null:
		for _i in cantidad:
			var prenda := escena_prenda_recolectable.instantiate()
			get_tree().current_scene.add_child(prenda)
			if prenda is Node3D:
				(prenda as Node3D).global_position = _jugador.global_position + Vector3(0.0, 0.3, 0.0)
			if prenda.has_method("configurar_estado"):
				prenda.configurar_estado(PrendaProyectil.EstadoPrenda.SUCIA)


func _obtener_num_args(obj: Object, nombre_metodo: String) -> int:
	for metodo in obj.get_method_list():
		if metodo["name"] == nombre_metodo:
			return (metodo["args"] as Array).size()
	return -1


func _on_mano_cambio(nuevas_secas: int) -> void:
	if nuevas_secas < _secas_previas:
		var entregadas: int = _secas_previas - nuevas_secas
		for _i in entregadas:
			_asignar_entrega_a_barco()
	_secas_previas = nuevas_secas


func registrar_entrega_directa() -> void:
	_asignar_entrega_a_barco()


func _asignar_entrega_a_barco() -> void:
	for barco in _barcos_activos:
		if is_instance_valid(barco) and barco.esta_activo_para_entrega():
			barco.registrar_prenda_entregada()
			return


func _on_barco_pedido_completado(barco: BarcoCliente, oro_ganado: int) -> void:
	_oro_actual += oro_ganado
	_clientes_atendidos += 1
	_barcos_finalizados += 1
	_barcos_activos.erase(barco)
	_mostrar_aviso("Barco #" + str(barco.numero_cliente) + " completado: +" + str(oro_ganado) + " oro.")
	_actualizar_hud()


func _on_barco_pedido_perdido(barco: BarcoCliente) -> void:
	_barcos_finalizados += 1
	_barcos_activos.erase(barco)
	_mostrar_aviso("El Barco #" + str(barco.numero_cliente) + " se fue sin su ropa.")
	_actualizar_hud()


func _on_loro_aviso(gancho: int) -> void:
	_mostrar_aviso("Sombra en el tendedero: un loro viene por el gancho " + str(gancho + 1) + ".")


func _on_loro_llego(gancho: int) -> void:
	_mostrar_aviso("ALERTA: Un loro aterrizó en el gancho " + str(gancho + 1) + ". Usa la piedra (Slot 2).")


func _on_loro_espantado(_gancho: int) -> void:
	_mostrar_aviso("Loro espantado. Prenda a salvo.")


func _on_loro_robo(gancho: int) -> void:
	_mostrar_aviso("El loro se robó la prenda del gancho " + str(gancho + 1) + ".")


func _finalizar_nivel() -> void:
	if _nivel_terminado:
		return
	_nivel_terminado = true

	var aprobado: bool = _oro_actual >= ORO_MINIMO_APROBAR
	_label_resultado_titulo.text = "NIVEL 1 SUPERADO" if aprobado else "TURNO TERMINADO - ORO INSUFICIENTE"
	_label_resultado_detalle.text = (
		"Oro obtenido: " + str(_oro_actual) + " / " + str(ORO_MAXIMO) + " (Mínimo requerido: " + str(ORO_MINIMO_APROBAR) + ")\n" +
		"Pedidos completados: " + str(_clientes_atendidos) + " / " + str(TOTAL_CLIENTES)
	)
	_panel_final.visible = true


func _construir_hud_jornada() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 20
	add_child(_hud_layer)

	var barra_top := PanelContainer.new()
	barra_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra_top.offset_left = 16
	barra_top.offset_top = 12
	barra_top.offset_right = -16
	barra_top.offset_bottom = 56
	_hud_layer.add_child(barra_top)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 36)
	barra_top.add_child(hbox)

	_label_tiempo = Label.new()
	hbox.add_child(_label_tiempo)

	_label_oro = Label.new()
	hbox.add_child(_label_oro)

	_label_clientes = Label.new()
	hbox.add_child(_label_clientes)

	_label_aviso = Label.new()
	_label_aviso.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label_aviso.offset_top = -115
	_label_aviso.offset_bottom = -85
	_label_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_aviso.text = "Nivel 1: Atiende los 3 barcos antes de que termine el turno."
	_hud_layer.add_child(_label_aviso)

	_panel_final = PanelContainer.new()
	_panel_final.set_anchors_preset(Control.PRESET_CENTER)
	_panel_final.custom_minimum_size = Vector2(440, 210)
	_panel_final.offset_left = -220
	_panel_final.offset_top = -105
	_panel_final.offset_right = 220
	_panel_final.offset_bottom = 105
	_panel_final.visible = false
	_hud_layer.add_child(_panel_final)

	var vbox_final := VBoxContainer.new()
	vbox_final.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_final.add_theme_constant_override("separation", 14)
	_panel_final.add_child(vbox_final)

	_label_resultado_titulo = Label.new()
	_label_resultado_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_final.add_child(_label_resultado_titulo)

	_label_resultado_detalle = Label.new()
	_label_resultado_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox_final.add_child(_label_resultado_detalle)

	var btn_reintentar := Button.new()
	btn_reintentar.text = "Reintentar Nivel 1"
	btn_reintentar.pressed.connect(func() -> void: get_tree().reload_current_scene())
	vbox_final.add_child(btn_reintentar)


func _actualizar_hud() -> void:
	var mins: int = floori(_tiempo_restante / 60.0)
	var segs: int = int(_tiempo_restante) % 60
	_label_tiempo.text = "Tiempo: %02d:%02d" % [mins, segs]
	_label_oro.text = "Oro: " + str(_oro_actual) + " / " + str(ORO_MAXIMO) + " (Meta: " + str(ORO_MINIMO_APROBAR) + ")"
	_label_clientes.text = "Barcos: " + str(_clientes_atendidos) + " / " + str(TOTAL_CLIENTES)


func _mostrar_aviso(texto: String) -> void:
	if is_instance_valid(_label_aviso):
		_label_aviso.text = texto
