extends Node
class_name EquipmentManager

signal disparo_soltado(velocidad: Vector3, tipo_item: TipoItem)

enum TipoItem {
	NINGUNO,
	RESORTERA,
	ROCA,
	CANA_PESCAR,
	PRENDA # Solo se usa como tipo de proyectil al disparar la resortera
}

@export_group("Referencias de Escena")
@export var escena_resortera_3d: PackedScene
@export var escena_cana_pescar_3d: PackedScene
@export var punto_mano_path: NodePath
@export var trayectoria_path: NodePath
@export var municion_manager_path: NodePath

@export_group("Dinamica Resortera")
@export var distancia_max_arrastre := 110.0
@export var velocidad_horizontal_min := 2.5
@export var velocidad_horizontal_max := 13.5
@export var impulso_vertical_min := 3.5
@export var impulso_vertical_max := 6.8
@export var modo_resortera_inverso := true

@export_group("Dinamica Cana de Pescar")
@export var alcance_maximo_cana := 14.0

var item_actual: TipoItem = TipoItem.NINGUNO
var instancia_resortera: Node3D = null
var instancia_cana: CanaPescar = null
var esta_tensando: bool = false

var _inicio_arrastre: Vector2 = Vector2.ZERO
var _velocidad_tiro: Vector3 = Vector3.ZERO

@onready var _punto_mano: Node3D = get_node_or_null(punto_mano_path)
@onready var _trayectoria: Node = get_node_or_null(trayectoria_path)
@onready var _municion: MunicionManager = get_node_or_null(municion_manager_path) as MunicionManager


func _ready() -> void:
	add_to_group("equipment_manager")
	seleccionar_item(0)


func _process(_delta: float) -> void:
	if not esta_tensando:
		return

	if item_actual != TipoItem.RESORTERA or not _puede_usar_resortera():
		_cancelar_tension()
		return

	_actualizar_arco_desde_cursor(get_viewport().get_mouse_position())


func _input(event: InputEvent) -> void:
	if not esta_tensando:
		return

	if item_actual != TipoItem.RESORTERA or not _puede_usar_resortera():
		_cancelar_tension()
		return

	_procesar_entrada_apuntado(event)


func _unhandled_input(event: InputEvent) -> void:
	if _procesar_cambio_slot_por_teclado(event):
		return

	if esta_tensando:
		return

	if event is InputEventMouseButton and event.pressed:
		# Lógica directa por clic para la caña de pescar (Slot 3).
		if item_actual == TipoItem.CANA_PESCAR and instancia_cana != null:
			if instancia_cana.linea_lanzada:
				if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
					instancia_cana.stop_fishing()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_intentar_lanzar_cana_al_cursor(event.position)
			return

		# Lógica de tensado para la resortera (Slot 1).
		if event.button_index == MOUSE_BUTTON_LEFT and item_actual == TipoItem.RESORTERA and _puede_usar_resortera():
			_iniciar_tension(get_viewport().get_mouse_position())


func seleccionar_item(indice_slot: int) -> void:
	_cancelar_tension()
	item_actual = _convertir_slot_a_item(indice_slot)
	_actualizar_modelo_en_mano()


func _puede_usar_resortera() -> bool:
	if _municion != null:
		return _municion.tiene_prendas()
	return true


func _intentar_lanzar_cana_al_cursor(posicion_pantalla: Vector2) -> void:
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null or _punto_mano == null or instancia_cana == null:
		return

	var origen_rayo: Vector3 = camara.project_ray_origin(posicion_pantalla)
	var direccion_rayo: Vector3 = camara.project_ray_normal(posicion_pantalla)
	var destino_rayo: Vector3 = origen_rayo + direccion_rayo * 1000.0

	var query := PhysicsRayQueryParameters3D.create(origen_rayo, destino_rayo)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = _obtener_rids_ignorados()

	var resultado: Dictionary = camara.get_world_3d().direct_space_state.intersect_ray(query)
	var punto_impacto: Vector3
	var objeto_tocado: Object = null

	if not resultado.is_empty():
		punto_impacto = resultado["position"]
		objeto_tocado = resultado["collider"]
	else:
		# Si se hace clic sobre el agua o una zona sin colisión, proyecta sobre el plano del jugador.
		var plano_nivel := Plane(Vector3.UP, _punto_mano.global_position.y)
		var interseccion: Variant = plano_nivel.intersects_ray(origen_rayo, direccion_rayo)
		if interseccion == null:
			return
		punto_impacto = interseccion as Vector3

	var vector_hacia_objetivo: Vector3 = punto_impacto - _punto_mano.global_position
	if vector_hacia_objetivo.length() > alcance_maximo_cana:
		vector_hacia_objetivo = vector_hacia_objetivo.limit_length(alcance_maximo_cana)
		punto_impacto = _punto_mano.global_position + vector_hacia_objetivo

	var direccion_plana := Vector3(vector_hacia_objetivo.x, 0.0, vector_hacia_objetivo.z)
	if direccion_plana.length_squared() > 0.0001:
		_rotar_mano_hacia(direccion_plana.normalized())

	instancia_cana.lanzar_hacia_punto(punto_impacto, objeto_tocado)


func _obtener_rids_ignorados() -> Array[RID]:
	var rids: Array[RID] = []
	for nodo in get_tree().get_nodes_in_group("ignorar_trayectoria"):
		if nodo is CollisionObject3D:
			rids.append((nodo as CollisionObject3D).get_rid())

	var padre: Node = get_parent()
	if padre != null:
		for hijo in padre.find_children("*", "CollisionObject3D", true, false):
			rids.append((hijo as CollisionObject3D).get_rid())

	return rids


func _procesar_cambio_slot_por_teclado(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false

	match event.keycode:
		KEY_1:
			seleccionar_item(1)
			return true
		KEY_2:
			seleccionar_item(2)
			return true
		KEY_3:
			seleccionar_item(3)
			return true
		_:
			return false


func _procesar_entrada_apuntado(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_soltar_y_disparar()
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancelar_tension()
			return

	if event is InputEventMouseMotion:
		_actualizar_arco_desde_cursor(event.position)


func _iniciar_tension(posicion_pantalla: Vector2) -> void:
	esta_tensando = true
	_inicio_arrastre = posicion_pantalla
	_velocidad_tiro = Vector3.ZERO


func _actualizar_arco_desde_cursor(posicion_actual: Vector2) -> void:
	var limite: float = maxf(distancia_max_arrastre, 1.0)
	var jalon: Vector2 = (posicion_actual - _inicio_arrastre).limit_length(limite)

	_velocidad_tiro = _calcular_velocidad_360(jalon, limite)

	if _trayectoria != null and _trayectoria.has_method("mostrar_trayectoria"):
		_trayectoria.mostrar_trayectoria(_obtener_origen_disparo(), _velocidad_tiro)


func _soltar_y_disparar() -> void:
	var velocidad_final: Vector3 = _velocidad_tiro
	_cancelar_tension()

	if velocidad_final.length_squared() <= 0.01:
		return

	if item_actual == TipoItem.RESORTERA and _puede_usar_resortera():
		disparo_soltado.emit(velocidad_final, TipoItem.PRENDA)


func _cancelar_tension() -> void:
	esta_tensando = false
	_velocidad_tiro = Vector3.ZERO
	if _trayectoria != null and _trayectoria.has_method("ocultar_trayectoria"):
		_trayectoria.ocultar_trayectoria()


func _calcular_velocidad_360(jalon: Vector2, limite: float) -> Vector3:
	if jalon.length() < 6.0:
		return Vector3.ZERO

	var vector_apuntado: Vector2 = -jalon if modo_resortera_inverso else jalon
	var potencia: float = clampf(jalon.length() / limite, 0.0, 1.0)

	var ejes_camara: Array[Vector3] = _obtener_ejes_horizontales_camara()
	var adelante_camara: Vector3 = ejes_camara[0]
	var derecha_camara: Vector3 = ejes_camara[1]

	var direccion_horizontal: Vector3 = (
		derecha_camara * vector_apuntado.x
		+ adelante_camara * (-vector_apuntado.y)
	)

	if direccion_horizontal.length_squared() < 0.0001:
		return Vector3.ZERO

	direccion_horizontal = direccion_horizontal.normalized()
	_rotar_mano_hacia(direccion_horizontal)

	var rapidez_horizontal: float = lerpf(velocidad_horizontal_min, velocidad_horizontal_max, potencia)
	var rapidez_vertical: float = lerpf(impulso_vertical_min, impulso_vertical_max, potencia)

	return direccion_horizontal * rapidez_horizontal + Vector3.UP * rapidez_vertical


func _obtener_ejes_horizontales_camara() -> Array[Vector3]:
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null:
		return [Vector3.FORWARD, Vector3.RIGHT]

	var forward: Vector3 = -camara.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD

	var right: Vector3 = camara.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT

	return [forward, right]


func _rotar_mano_hacia(direccion_horizontal: Vector3) -> void:
	if _punto_mano == null:
		return

	if absf(direccion_horizontal.x) > 0.05:
		var distancia_mano: float = absf(_punto_mano.position.x)
		if distancia_mano < 0.01:
			distancia_mano = 0.35
		_punto_mano.position.x = distancia_mano * signf(direccion_horizontal.x)

	var objetivo: Vector3 = _punto_mano.global_position + direccion_horizontal
	if not _punto_mano.global_position.is_equal_approx(objetivo):
		_punto_mano.look_at(objetivo, Vector3.UP)


func _obtener_origen_disparo() -> Vector3:
	if _punto_mano != null:
		return _punto_mano.global_position
	if _trayectoria is Node3D:
		return (_trayectoria as Node3D).global_position
	return Vector3.ZERO


func _convertir_slot_a_item(indice_slot: int) -> TipoItem:
	match indice_slot:
		1:
			return TipoItem.RESORTERA
		2:
			return TipoItem.ROCA
		3:
			return TipoItem.CANA_PESCAR
		_:
			return TipoItem.NINGUNO


func _actualizar_modelo_en_mano() -> void:
	if is_instance_valid(instancia_resortera):
		instancia_resortera.queue_free()
		instancia_resortera = null

	if is_instance_valid(instancia_cana):
		instancia_cana.queue_free()
		instancia_cana = null

	if _punto_mano == null:
		return

	if item_actual == TipoItem.RESORTERA and escena_resortera_3d != null:
		instancia_resortera = escena_resortera_3d.instantiate()
		_punto_mano.add_child(instancia_resortera)
		_registrar_en_grupo_ignorar(instancia_resortera)

	elif item_actual == TipoItem.CANA_PESCAR and escena_cana_pescar_3d != null:
		instancia_cana = escena_cana_pescar_3d.instantiate() as CanaPescar
		_punto_mano.add_child(instancia_cana)
		_registrar_en_grupo_ignorar(instancia_cana)


func _registrar_en_grupo_ignorar(raiz: Node) -> void:
	raiz.add_to_group("ignorar_trayectoria")
	for hijo in raiz.find_children("*", "CollisionObject3D", true, false):
		hijo.add_to_group("ignorar_trayectoria")
