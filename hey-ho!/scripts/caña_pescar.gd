class_name CanaPescar
extends Node3D

signal objetivo_enganchado(objeto: Object, posicion_impacto: Vector3)
signal linea_recogida

@onready var bobber: CharacterBody3D = %Boya
@onready var fishing_line_starter_marker: Marker3D = %Punta
@onready var bobber_start_marker: Marker3D = %InicioBoya
@onready var fishing_line: MeshInstance3D = %LineaPesca

@export var velocidad_lanzamiento := 22.0
@export var velocidad_recogida := 24.0

var linea_lanzada: bool = false
var _tween_movimiento: Tween = null


func _ready() -> void:
	_ignorar_colision_con_jugador()
	bobber.set_physics_process(false)
	bobber.global_position = bobber_start_marker.global_position
	fishing_line.hide()


func _physics_process(_delta: float) -> void:
	if not fishing_line.visible:
		return
	_refresh_line()


func _ignorar_colision_con_jugador() -> void:
	var nodo_actual: Node = get_parent()
	while nodo_actual != null:
		if nodo_actual is PhysicsBody3D:
			bobber.add_collision_exception_with(nodo_actual as PhysicsBody3D)
			return
		nodo_actual = nodo_actual.get_parent()


func _refresh_line() -> void:
	var origen: Vector3 = fishing_line_starter_marker.global_position
	var destino: Vector3 = bobber.global_position
	var distancia: float = origen.distance_to(destino)

	if distancia <= 0.001:
		return

	fishing_line.global_position = (origen + destino) * 0.5

	if fishing_line.mesh is CylinderMesh:
		(fishing_line.mesh as CylinderMesh).height = distancia

	fishing_line.look_at(origen, Vector3.UP)
	fishing_line.rotation_degrees.x -= 90.0


func lanzar_hacia_punto(destino_global: Vector3, objeto_tocado: Object = null) -> void:
	if is_instance_valid(_tween_movimiento):
		_tween_movimiento.kill()

	linea_lanzada = true
	bobber.set_physics_process(false)
	bobber.global_position = bobber_start_marker.global_position
	bobber.top_level = true

	fishing_line.show()
	_refresh_line()

	var distancia: float = bobber.global_position.distance_to(destino_global)
	var duracion: float = clampf(distancia / maxf(velocidad_lanzamiento, 1.0), 0.08, 0.45)

	_tween_movimiento = create_tween()
	_tween_movimiento.tween_property(bobber, "global_position", destino_global, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _tween_movimiento.finished

	if not linea_lanzada:
		return

	objetivo_enganchado.emit(objeto_tocado, destino_global)
	get_tree().call_group("controlador_estaciones", "_on_cana_objetivo_enganchado", self, objeto_tocado, destino_global)


func stop_fishing() -> void:
	if not linea_lanzada:
		return

	linea_lanzada = false
	bobber.set_physics_process(false)

	if is_instance_valid(_tween_movimiento):
		_tween_movimiento.kill()

	var distancia: float = bobber.global_position.distance_to(bobber_start_marker.global_position)
	var duracion: float = clampf(distancia / maxf(velocidad_recogida, 1.0), 0.1, 0.4)

	_tween_movimiento = create_tween()
	_tween_movimiento.tween_property(bobber, "global_position", bobber_start_marker.global_position, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tween_movimiento.finished

	bobber.top_level = false
	bobber.position = bobber_start_marker.position
	fishing_line.hide()
	linea_recogida.emit()
