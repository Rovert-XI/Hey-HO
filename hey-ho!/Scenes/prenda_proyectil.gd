extends RigidBody3D
class_name PrendaProyectil

enum EstadoPrenda {
	SUCIA,   # 0: Recién salida del canasto de clientes.
	LAVADA,  # 1: Procesada en la lavadora, lista para tender.
	SECA     # 2: Procesada en el tendedero, lista para despachar.
}

@export var estado: EstadoPrenda = EstadoPrenda.SUCIA
@export var tiempo_vida_segundos := 18.0
@export var escena_prenda_recolectable: PackedScene

var es_retorno_de_maquina: bool = false
var _convertida: bool = false


func _ready() -> void:
	add_to_group("prendas_proyectil")

	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	_actualizar_visual_por_estado()

	if tiempo_vida_segundos > 0.0:
		var temporizador := get_tree().create_timer(tiempo_vida_segundos)
		temporizador.timeout.connect(queue_free)


func configurar_estado(nuevo_estado: EstadoPrenda) -> void:
	estado = nuevo_estado
	_actualizar_visual_por_estado()


func lanzar(velocidad_inicial: Vector3) -> void:
	linear_velocity = velocidad_inicial


func _on_body_entered(body: Node) -> void:
	if _convertida:
		return

	# 1. Impacto contra estaciones o despacho (disparo del jugador)
	if not es_retorno_de_maquina:
		if _pertenece_a_grupo(body, "estacion_lavadora"):
			var estaciones := _obtener_estaciones_ropa()
			if estaciones != null:
				_convertida = true
				estaciones.recibir_en_lavadora(int(estado))
				queue_free()
			return

		if _pertenece_a_grupo(body, "estacion_tendedero"):
			var estaciones := _obtener_estaciones_ropa()
			if estaciones != null:
				_convertida = true
				estaciones.recibir_en_tendedero(int(estado))
				queue_free()
			return

		var padre_despacho: Node = body.get_parent()
		if body.name == "PlataformaDespacho" or (padre_despacho != null and padre_despacho.name == "PlataformaDespacho"):
			var estaciones := _obtener_estaciones_ropa()
			if estaciones != null and estado == EstadoPrenda.SECA:
				_convertida = true
				var entregadas := estaciones.entregar(1)
				print("¡Prenda SECA entregada en PlataformaDespacho! (", entregadas, ")")
				queue_free()
			return

	# 2. Retorno hacia PlataformaCentral
	if es_retorno_de_maquina:
		var padre: Node = body.get_parent()
		if body.name == "PlataformaCentral" or (padre != null and padre.name == "PlataformaCentral"):
			_convertir_en_recolectable()


func _pertenece_a_grupo(nodo: Node, grupo: String) -> bool:
	if nodo == null:
		return false
	if nodo.is_in_group(grupo):
		return true
	var padre := nodo.get_parent()
	return padre != null and padre.is_in_group(grupo)


func _obtener_estaciones_ropa() -> EstacionesRopa:
	var nodo := get_tree().get_first_node_in_group("estaciones_ropa") as EstacionesRopa
	if nodo != null:
		return nodo
	if get_tree().current_scene != null:
		return get_tree().current_scene.find_child("EstacionesRopa", true, false) as EstacionesRopa
	return null


func _convertir_en_recolectable() -> void:
	if escena_prenda_recolectable == null:
		return

	_convertida = true
	var recolectable := escena_prenda_recolectable.instantiate()
	var padre_mundo := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	padre_mundo.add_child(recolectable)

	if recolectable is Node3D:
		(recolectable as Node3D).global_position = global_position + Vector3.UP * 0.25
	if recolectable.has_method("configurar_estado"):
		recolectable.configurar_estado(estado)

	queue_free()


func _actualizar_visual_por_estado() -> void:
	var material := StandardMaterial3D.new()
	match estado:
		EstadoPrenda.SUCIA:
			material.albedo_color = Color(0.468, 0.334, 0.127, 1.0)
		EstadoPrenda.LAVADA:
			material.albedo_color = Color(0.35, 0.72, 0.95)
		EstadoPrenda.SECA:
			material.albedo_color = Color(0.96, 0.96, 0.92)

	for nodo in find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		if malla != null:
			malla.material_override = material
