class_name GestorNivel1
extends Node

const TOTAL_CLIENTES := 3
const PRIMER_BARCO_SEG := 3.0
const PRENDAS_POR_CLIENTE := 2
const ORO_POR_PEDIDO := 30
const ORO_MAXIMO := 90
const ORO_MINIMO_APROBAR := 54
const ESCENA_PAUSA: PackedScene = preload("res://juego/pausa.tscn")

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
var _equipo: EquipmentManager
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

var _hud: HudHeyHo
var _menu_pausa: MenuPausa
var _pausa_abierta := false
var _interfaz_lista := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("gestor_nivel")
	EstadoJuego.asegurar_carga()
	_tiempo_restante = duracion_nivel

	var raiz := get_tree().current_scene
	if raiz == null:
		return

	_hud = raiz.find_child("Hud", true, false) as HudHeyHo
	if _hud == null:
		push_error("GestorNivel1: no se encontró el HUD HudHeyHo en la escena activa.")
		return

	_estaciones = raiz.find_child("EstacionesRopa", true, false) as EstacionesRopa
	_despacho = raiz.find_child("PlataformaDespacho", true, false) as Node3D
	_municion = raiz.find_child("MunicionManager", true, false) as MunicionManager
	_equipo = raiz.find_child("EquipmentManager", true, false) as EquipmentManager
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
	_inicializar_interfaz.call_deferred()


func _inicializar_interfaz() -> void:
	_hud.configurar_jornada(duracion_nivel, TOTAL_CLIENTES, ORO_MAXIMO, ORO_MINIMO_APROBAR)
	_hud.pausa_solicitada.connect(_abrir_pausa)
	if _equipo != null:
		_equipo.item_cambiado.connect(_al_cambiar_item)
		_equipo.tension_cambiada.connect(_hud.set_carga)
		_equipo.piedras_cambiadas.connect(_hud.set_piedras)
		_al_cambiar_item(_equipo.item_actual)
		_hud.set_piedras(_equipo.piedras_disponibles)
	_montar_menu_pausa(get_tree().current_scene)
	_interfaz_lista = true
	_actualizar_hud()
	_mostrar_aviso("Atiende los 3 barcos antes de que termine el turno.")


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
	if not _interfaz_lista or _nivel_terminado or get_tree().paused:
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


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if _nivel_terminado:
		return

	if _pausa_abierta:
		_reanudar_desde_pausa()
	else:
		_abrir_pausa()
	get_viewport().set_input_as_handled()


func _montar_menu_pausa(raiz: Node) -> void:
	var capa := CanvasLayer.new()
	capa.name = "CapaPausaNivel1"
	capa.layer = 20
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	raiz.add_child(capa)

	_menu_pausa = ESCENA_PAUSA.instantiate() as MenuPausa
	_menu_pausa.hide()
	capa.add_child(_menu_pausa)
	_menu_pausa.continuar.connect(_reanudar_desde_pausa)
	_menu_pausa.reiniciar.connect(_reiniciar_desde_pausa)
	_menu_pausa.volver_al_menu.connect(_volver_al_menu_desde_pausa)


func _abrir_pausa() -> void:
	if _nivel_terminado or _pausa_abierta:
		return
	_pausa_abierta = true
	_menu_pausa.mostrar_menu()
	get_tree().paused = true


func _reanudar_desde_pausa() -> void:
	_pausa_abierta = false
	get_tree().paused = false
	_menu_pausa.hide()


func _reiniciar_desde_pausa() -> void:
	_pausa_abierta = false
	get_tree().paused = false
	Navegador.ir_a(self, EstadoJuego.RUTA_NIVEL)


func _volver_al_menu_desde_pausa() -> void:
	_pausa_abierta = false
	get_tree().paused = false
	Navegador.ir_a(self, Navegador.MENU)


func _al_cambiar_item(item: int) -> void:
	match item:
		EquipmentManager.TipoItem.RESORTERA:
			_hud.equipar("resortera")
		EquipmentManager.TipoItem.ROCA:
			_hud.equipar("piedra")
		EquipmentManager.TipoItem.CANA_PESCAR:
			_hud.equipar("cana")
		_:
			_hud.equipar("")


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
	_hud.mostrar_pago(oro_ganado)
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
	EstadoJuego.nivel_actual = 1
	EstadoJuego.terminar_nivel(1, _oro_actual, _clientes_atendidos, TOTAL_CLIENTES)
	Navegador.ir_a(self, Navegador.RESULTADO)


func _actualizar_hud() -> void:
	_hud.set_tiempo(_tiempo_restante)
	_hud.set_oro(_oro_actual)
	_hud.set_barcos(_clientes_atendidos, TOTAL_CLIENTES)


func _mostrar_aviso(texto: String) -> void:
	if is_instance_valid(_hud):
		_hud.mostrar_aviso(texto)
