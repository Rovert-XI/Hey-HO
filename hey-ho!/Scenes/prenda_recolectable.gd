extends Area3D
class_name PrendaRecolectable

@export var municion_manager_path: NodePath
@export var cantidad_que_otorga := 1
@export var estado_prenda: PrendaProyectil.EstadoPrenda = PrendaProyectil.EstadoPrenda.SUCIA

var _jugador_cerca: bool = false
var _municion: MunicionManager = null


func _ready() -> void:
	_municion = get_node_or_null(municion_manager_path) as MunicionManager
	_actualizar_visual_por_estado()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func configurar_estado(nuevo_estado: PrendaProyectil.EstadoPrenda) -> void:
	estado_prenda = nuevo_estado
	_actualizar_visual_por_estado()


func _unhandled_input(event: InputEvent) -> void:
	if not _jugador_cerca:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_recoger()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("jugador"):
		_jugador_cerca = true


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("jugador"):
		_jugador_cerca = false


func _recoger() -> void:
	if _municion != null:
		_municion.agregar_prendas(cantidad_que_otorga, estado_prenda)
	queue_free()


func _actualizar_visual_por_estado() -> void:
	var material := StandardMaterial3D.new()
	match estado_prenda:
		PrendaProyectil.EstadoPrenda.SUCIA:
			material.albedo_color = Color(0.55, 0.42, 0.28) # Café (sucia)
		PrendaProyectil.EstadoPrenda.LAVADA:
			material.albedo_color = Color(0.35, 0.72, 0.95) # Azul húmedo (lavada)
		PrendaProyectil.EstadoPrenda.SECA:
			material.albedo_color = Color(0.96, 0.96, 0.92) # Blanco limpio (seca)

	for nodo in find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		if malla != null:
			malla.material_override = material
