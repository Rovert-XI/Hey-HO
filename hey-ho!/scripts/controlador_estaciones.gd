extends Node
class_name ControladorEstaciones

@export var alinear_visuales_con_modelos := true
@export var radio_rescate_agua := 2.2

var _estaciones: EstacionesRopa
var _municion: MunicionManager
var _equipment: EquipmentManager
var _lavadora_1: Node3D
var _lavadora_2: Node3D
var _tendedero: Node3D
var _cana_conectada: CanaPescar = null
var _acumulador_log: float = 0.0
var _ultimo_frame_enganche: int = -1


func _ready() -> void:
	add_to_group("controlador_estaciones")

	var raiz := get_tree().current_scene
	if raiz == null:
		return

	_estaciones = raiz.find_child("EstacionesRopa", true, false) as EstacionesRopa
	_municion = raiz.find_child("MunicionManager", true, false) as MunicionManager
	_equipment = raiz.find_child("EquipmentManager", true, false) as EquipmentManager
	_lavadora_1 = raiz.find_child("LavadoraPirata", true, false) as Node3D
	_lavadora_2 = raiz.find_child("LavadoraPirata2", true, false) as Node3D
	_tendedero = raiz.find_child("TendederoPirata", true, false) as Node3D

	if _estaciones != null:
		_estaciones.add_to_group("estaciones_ropa")
		_conectar_senales_estaciones()
		if alinear_visuales_con_modelos:
			_sincronizar_posiciones_visuales()
	else:
		push_warning("ControladorEstaciones: no se encontró el nodo EstacionesRopa.")


func _process(delta: float) -> void:
	# Conecta automáticamente la caña apenas la equipas en el Slot 3
	if _equipment != null and _equipment.instancia_cana != _cana_conectada:
		_cana_conectada = _equipment.instancia_cana
		if is_instance_valid(_cana_conectada):
			var cb := Callable(self, "_on_senal_cana_enganchada").bind(_cana_conectada)
			if not _cana_conectada.objetivo_enganchado.is_connected(cb):
				_cana_conectada.objetivo_enganchado.connect(cb)

	if _estaciones == null:
		return

	# Muestra cada segundo cuánto falta para que termine el lavado o secado
	_acumulador_log += delta
	if _acumulador_log >= 1.0:
		_acumulador_log = 0.0
		_imprimir_tiempos_activos()


func _conectar_senales_estaciones() -> void:
	if not _estaciones.prenda_lavando.is_connected(_on_prenda_lavando):
		_estaciones.prenda_lavando.connect(_on_prenda_lavando)
	if not _estaciones.prenda_lavada.is_connected(_on_prenda_lavada):
		_estaciones.prenda_lavada.connect(_on_prenda_lavada)
	if not _estaciones.prenda_tendida.is_connected(_on_prenda_tendida):
		_estaciones.prenda_tendida.connect(_on_prenda_tendida)
	if not _estaciones.prenda_seca.is_connected(_on_prenda_seca):
		_estaciones.prenda_seca.connect(_on_prenda_seca)
	if not _estaciones.prenda_al_agua.is_connected(_on_prenda_al_agua):
		_estaciones.prenda_al_agua.connect(_on_prenda_al_agua)
	if not _estaciones.prenda_rescatada.is_connected(_on_prenda_rescatada):
		_estaciones.prenda_rescatada.connect(_on_prenda_rescatada)
	if not _estaciones.prenda_perdida.is_connected(_on_prenda_perdida):
		_estaciones.prenda_perdida.connect(_on_prenda_perdida)


func _imprimir_tiempos_activos() -> void:
	for i in EstacionesRopa.CAPACIDAD_LAVADORA:
		var s = _estaciones.lavadora[i]
		if s != null and not s.listo:
			var falta := maxf(0.0, EstacionesRopa.T_LAVADO - s.t)
			print("⏳ Lavadora ", i + 1, " lavando... falta ", String.num(falta, 1), " s")

	for g in EstacionesRopa.GANCHOS:
		var s = _estaciones.tendedero[g]
		if s != null and not s.seca:
			var falta := maxf(0.0, EstacionesRopa.T_SECADO - s.t)
			print("⏳ Tendedero (gancho ", g + 1, ") secando... falta ", String.num(falta, 1), " s")


func _on_prenda_lavando(slot: int) -> void:
	print("✅ ¡Prenda entró en Lavadora ", slot + 1, "! Lavando (", EstacionesRopa.T_LAVADO, " s)...")


func _on_prenda_lavada(slot: int) -> void:
	print("🟢 ¡LISTA! La prenda de Lavadora ", slot + 1, " ya se lavó (verde). Ya la puedes sacar con la caña (Slot 3).")


func _on_prenda_tendida(gancho: int) -> void:
	print("✅ ¡Prenda colgada en Tendedero (gancho ", gancho + 1, ")! Secando (", EstacionesRopa.T_SECADO, " s)...")


func _on_prenda_seca(gancho: int) -> void:
	print("⚪ ¡LISTA! La prenda del gancho ", gancho + 1, " ya está SECA (crema). Ya la puedes sacar con la caña (Slot 3).")


func _on_prenda_al_agua(_estado: int) -> void:
	print("💦 ¡La prenda cayó al agua! Tienes ", EstacionesRopa.T_RESCATE, " s para hacer clic en el aro amarillo con la caña.")


func _on_prenda_perdida(_estado: int) -> void:
	print("❌ Se perdió una prenda en el agua (se acabaron los 8 s).")


func _on_senal_cana_enganchada(objeto: Object, posicion_impacto: Vector3, cana: CanaPescar) -> void:
	_procesar_impacto_cana(cana, objeto, posicion_impacto)


func _on_cana_objetivo_enganchado(cana: CanaPescar, objeto: Object, posicion_impacto: Vector3) -> void:
	_procesar_impacto_cana(cana, objeto, posicion_impacto)


func _procesar_impacto_cana(cana: CanaPescar, objeto: Object, posicion_impacto: Vector3) -> void:
	if _estaciones == null:
		return

	var frame_actual := Engine.get_process_frames()
	if frame_actual == _ultimo_frame_enganche:
		return
	_ultimo_frame_enganche = frame_actual

	var nodo_tocado := objeto as Node

	# 1. Clic en Lavadora -> recoge prenda LAVADA (verde)
	if _pertenece_a_grupo(nodo_tocado, "estacion_lavadora"):
		if _recoger_de_lavadora(nodo_tocado):
			if _municion != null:
				_municion.agregar_prendas(1, PrendaProyectil.EstadoPrenda.LAVADA)
			print("🎣 Caña: ¡Prenda LAVADA recogida y cargada en la resortera!")
		else:
			print("🎣 Caña: todavía no hay prendas listas (verdes) en la lavadora.")
		_retraer_cana_tras_pausa(cana)
		return

	# 2. Clic en Tendedero -> recoge prenda SECA (crema)
	if _pertenece_a_grupo(nodo_tocado, "estacion_tendedero"):
		if _estaciones.hay_para_jalar("tendedero"):
			if _estaciones.jalar("tendedero", _estaciones.HOLD_JALAR + 0.1):
				_estaciones.soltar_jalar()
				if _municion != null:
					_municion.agregar_prendas(1, PrendaProyectil.EstadoPrenda.SECA)
				print("🎣 Caña: ¡Prenda SECA recogida! Dispara hacia PlataformaDespacho para entregar.")
		else:
			print("🎣 Caña: todavía no hay prendas secas (crema) en el tendedero.")
		_retraer_cana_tras_pausa(cana)
		return

	# 3. Clic en aro amarillo del agua -> rescata prenda caída
	if _intentar_rescatar_en_agua(posicion_impacto):
		_retraer_cana_tras_pausa(cana)
		return

	print("🎣 Caña: boya tocó '", nodo_tocado.name if nodo_tocado != null else "agua", "' (sin prenda lista ahí).")


func _recoger_de_lavadora(nodo_tocado: Node) -> bool:
	var slot_especifico := _obtener_slot_lavadora(nodo_tocado)
	if slot_especifico != -1 and _estaciones.lavadora[slot_especifico] != null and _estaciones.lavadora[slot_especifico].listo:
		_estaciones._liberar(_estaciones.lavadora, slot_especifico)
		_estaciones._avisar_mano()
		return true

	if _estaciones.hay_para_jalar("lavadora"):
		var ok := _estaciones.jalar("lavadora", _estaciones.HOLD_JALAR + 0.1)
		_estaciones.soltar_jalar()
		return ok

	return false


func _obtener_slot_lavadora(nodo: Node) -> int:
	var actual := nodo
	while actual != null:
		if actual == _lavadora_1 or actual.name == "LavadoraPirata":
			return 0
		if actual == _lavadora_2 or actual.name == "LavadoraPirata2":
			return 1
		actual = actual.get_parent()
	return -1


func _intentar_rescatar_en_agua(posicion_impacto: Vector3) -> bool:
	if _estaciones.charcos.is_empty():
		return false

	var camara := get_viewport().get_camera_3d()
	var pos_mouse := get_viewport().get_mouse_position()
	var impacto_xz := Vector2(posicion_impacto.x, posicion_impacto.z)

	for c in _estaciones.charcos:
		if not is_instance_valid(c.nodo):
			continue
		var charco_pos: Vector3 = c.nodo.global_position
		var charco_xz := Vector2(charco_pos.x, charco_pos.z)

		var cerca_impacto := impacto_xz.distance_to(charco_xz) <= radio_rescate_agua
		var cerca_cursor := false

		if camara != null:
			var plano_agua := Plane(Vector3.UP, charco_pos.y)
			var punto_en_agua: Variant = plano_agua.intersects_ray(
				camara.project_ray_origin(pos_mouse),
				camara.project_ray_normal(pos_mouse)
			)
			if punto_en_agua != null:
				var p := punto_en_agua as Vector3
				cerca_cursor = Vector2(p.x, p.z).distance_to(charco_xz) <= 1.5

		if cerca_impacto or cerca_cursor:
			var ok := _estaciones.rescatar(_estaciones.HOLD_RESCATE + 0.1)
			_estaciones.soltar_rescate()
			return ok

	return false


func _retraer_cana_tras_pausa(cana: CanaPescar) -> void:
	if not is_instance_valid(cana):
		return
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(cana) and cana.linea_lanzada:
		cana.stop_fishing()


func _on_prenda_rescatada(estado: int) -> void:
	if _municion != null:
		_municion.agregar_prendas(1, estado as PrendaProyectil.EstadoPrenda)
		print("🎣 Caña: ¡Prenda rescatada del agua y devuelta al inventario!")


func _pertenece_a_grupo(nodo: Node, grupo: String) -> bool:
	if nodo == null:
		return false
	if nodo.is_in_group(grupo):
		return true
	var padre := nodo.get_parent()
	return padre != null and padre.is_in_group(grupo)


func _sincronizar_posiciones_visuales() -> void:
	if _lavadora_1 != null and _lavadora_2 != null:
		_estaciones.pos_lavadora = [
			_estaciones.to_local(_lavadora_1.to_global(Vector3(0.0, 0.56, 0.36))),
			_estaciones.to_local(_lavadora_2.to_global(Vector3(0.0, 0.56, 0.36)))
		]

	if _tendedero != null:
		_estaciones.pos_ganchos = [
			_estaciones.to_local(_tendedero.to_global(Vector3(-0.85, 0.12, 0.0))),
			_estaciones.to_local(_tendedero.to_global(Vector3(0.0, 0.12, 0.0))),
			_estaciones.to_local(_tendedero.to_global(Vector3(0.85, 0.12, 0.0)))
		]
