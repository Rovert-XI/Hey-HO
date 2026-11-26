extends RigidBody3D
class_name RocaProyectil

signal loro_golpeado(loro: Node)

@export var tiempo_vida_segundos := 5.0

var _impacto_procesado: bool = false


func _ready() -> void:
	add_to_group("proyectiles_piedra")

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Giro visual en el aire
	angular_velocity = Vector3(
		randf_range(-10.0, 10.0),
		randf_range(-10.0, 10.0),
		randf_range(-10.0, 10.0)
	)

	if tiempo_vida_segundos > 0.0:
		get_tree().create_timer(tiempo_vida_segundos).timeout.connect(queue_free)


func lanzar_hacia_punto(origen: Vector3, destino: Vector3) -> void:
	global_position = origen
	var distancia := origen.distance_to(destino)
	var tiempo_vuelo := clampf(distancia / 24.0, 0.16, 0.48)
	var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * gravity_scale

	var desplazamiento := destino - origen
	var vx := desplazamiento.x / tiempo_vuelo
	var vz := desplazamiento.z / tiempo_vuelo
	var vy := (desplazamiento.y + 0.5 * gravedad * tiempo_vuelo * tiempo_vuelo) / tiempo_vuelo

	linear_velocity = Vector3(vx, vy, vz)


func _on_body_entered(body: Node) -> void:
	if _impacto_procesado or body == null:
		return

	if _es_loro(body):
		_impacto_procesado = true
		var nodo_loro := _obtener_raiz_loro(body)
		if nodo_loro.has_method("espantar"):
			nodo_loro.espantar()
		elif nodo_loro.has_method("recibir_golpe"):
			nodo_loro.recibir_golpe()
		loro_golpeado.emit(nodo_loro)
		get_tree().call_group("controlador_estaciones", "_on_loro_golpeado", nodo_loro)
		print("Piedra: impacto directo contra el loro.")
		queue_free()
		return

	if body.name.to_lower().contains("agua"):
		_impacto_procesado = true
		queue_free()


func _es_loro(nodo: Node) -> bool:
	var actual := nodo
	while actual != null:
		if actual.is_in_group("loro") or actual.is_in_group("enemigo_loro"):
			return true
		if actual.name.to_lower().contains("loro"):
			return true
		actual = actual.get_parent()
	return false


func _obtener_raiz_loro(nodo: Node) -> Node:
	var actual := nodo
	while actual != null:
		if actual.is_in_group("loro") or actual.is_in_group("enemigo_loro") or actual.name.to_lower().contains("loro"):
			return actual
		actual = actual.get_parent()
	return nodo
