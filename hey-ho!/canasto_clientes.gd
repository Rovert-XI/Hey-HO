extends Area3D
class_name CanastoClientes

signal cantidad_canasto_cambiada(nueva_cantidad: int)

@export_group("Dependencias")
@export var municion_manager_path: NodePath
@export var visual_ropa_path: NodePath

@export_group("Configuracion de Clientes")
@export var intervalo_llegada_seg: float = 6.0
@export var capacidad_maxima: int = 3
@export var prendas_iniciales: int = 1

var prendas_disponibles: int = 0
var _jugador_cerca: bool = false
var _temporizador_llegada: float = 0.0

@onready var _municion: MunicionManager = get_node_or_null(municion_manager_path) as MunicionManager
@onready var _visual_ropa: Node3D = get_node_or_null(visual_ropa_path) as Node3D


func _ready() -> void:
	prendas_disponibles = clampi(prendas_iniciales, 0, capacidad_maxima)
	_actualizar_visual_canasto()
	cantidad_canasto_cambiada.emit(prendas_disponibles)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if prendas_disponibles >= capacidad_maxima:
		_temporizador_llegada = 0.0
		return

	_temporizador_llegada += delta
	if _temporizador_llegada >= intervalo_llegada_seg:
		_temporizador_llegada = 0.0
		_agregar_prenda_de_cliente()


func _unhandled_input(event: InputEvent) -> void:
	if not _jugador_cerca or prendas_disponibles <= 0:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_entregar_prenda_al_jugador()


func _agregar_prenda_de_cliente() -> void:
	prendas_disponibles += 1
	_actualizar_visual_canasto()
	cantidad_canasto_cambiada.emit(prendas_disponibles)
	print("Canasto: llegó prenda SUCIA (", prendas_disponibles, "/", capacidad_maxima, ")")


func _entregar_prenda_al_jugador() -> void:
	if _municion == null:
		push_warning("CanastoClientes: falta asignar municion_manager_path en el Inspector.")
		return

	prendas_disponibles -= 1
	_actualizar_visual_canasto()
	cantidad_canasto_cambiada.emit(prendas_disponibles)
	_municion.agregar_prendas(1, PrendaProyectil.EstadoPrenda.SUCIA)


func _actualizar_visual_canasto() -> void:
	if _visual_ropa != null:
		_visual_ropa.visible = prendas_disponibles > 0


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("jugador"):
		_jugador_cerca = true


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("jugador"):
		_jugador_cerca = false
