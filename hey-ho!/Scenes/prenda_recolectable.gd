extends Area3D

@export var municion_manager_path: NodePath
@export var cantidad_que_otorga := 1

var _jugador_cerca: bool = false
var _municion: MunicionManager = null


func _ready() -> void:
	_municion = get_node_or_null(municion_manager_path) as MunicionManager
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _jugador_cerca:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_recoger()


func _on_body_entered(body: Node3D) -> void:
	# Ajusta si tu jugador tiene grupo "jugador" o es CharacterBody3D
	if body is CharacterBody3D or body.is_in_group("jugador"):
		_jugador_cerca = true


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("jugador"):
		_jugador_cerca = false


func _recoger() -> void:
	if _municion != null:
		_municion.agregar_prendas(cantidad_que_otorga)
	queue_free()
