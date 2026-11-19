extends Node3D
class_name LanzadorPrenda

@export_group("Dependencias")
# Referencia al EquipmentManager que emite la señal al soltar el tiro.
@export var equipment_manager_path: NodePath
# Referencia al MunicionManager para validar y descontar prendas disponibles.
@export var municion_manager_path: NodePath
# Escena empaquetada del proyectil (prenda_proyectil.tscn).
@export var escena_prenda_proyectil: PackedScene

@export_group("Configuracion de Spawn")
# Separación hacia adelante desde el origen para no chocar de inmediato con el jugador.
@export var offset_salida := 0.8

@onready var _equipment: EquipmentManager = get_node_or_null(equipment_manager_path) as EquipmentManager
@onready var _municion: MunicionManager = get_node_or_null(municion_manager_path) as MunicionManager


func _ready() -> void:
	# Se suscribe al evento en vez de revisar inputs directamente (SRP y bajo acoplamiento).
	if _equipment != null and not _equipment.disparo_soltado.is_connected(_on_disparo_soltado):
		_equipment.disparo_soltado.connect(_on_disparo_soltado)


func _on_disparo_soltado(velocidad: Vector3, tipo_item: int) -> void:
	# Solo procesa lanzamientos cuando el ítem disparado corresponde a PRENDA.
	if tipo_item != EquipmentManager.TipoItem.PRENDA:
		return

	if not _puede_instanciar_proyectil():
		return

	if not _intentar_consumir_municion():
		return

	_instanciar_y_lanzar(velocidad)


# Valida que exista una escena configurada antes de instanciar.
func _puede_instanciar_proyectil() -> bool:
	if escena_prenda_proyectil == null:
		push_warning("LanzadorPrenda: falta asignar escena_prenda_proyectil en el Inspector.")
		return false
	return true


# Descuenta 1 prenda del inventario si hay MunicionManager asignado.
func _intentar_consumir_municion() -> bool:
	if _municion == null:
		return true

	if not _municion.consumir_prenda(1):
		print("No tienes prendas en el inventario para disparar.")
		return false

	return true


# Crea el RigidBody3D en la escena principal y le asigna la velocidad del tiro.
func _instanciar_y_lanzar(velocidad: Vector3) -> void:
	var origen := _obtener_origen_disparo()
	var direccion := velocidad.normalized() if velocidad.length_squared() > 0.0001 else Vector3.FORWARD
	var instancia := escena_prenda_proyectil.instantiate()

	# Se agrega a la escena principal (y no a PuntoMano) para que el cuerpo 3D vuele libre.
	var padre_mundo := get_tree().current_scene if get_tree().current_scene != null else self
	padre_mundo.add_child(instancia)

	var posicion_spawn := origen + direccion * offset_salida
	if instancia is PrendaProyectil:
		instancia.global_position = posicion_spawn
		instancia.lanzar(velocidad)
	elif instancia is Node3D:
		instancia.global_position = posicion_spawn


# Obtiene la posición base desde PuntoMano (o desde LanzadorPrenda como respaldo).
func _obtener_origen_disparo() -> Vector3:
	if _equipment != null and _equipment._punto_mano != null:
		return _equipment._punto_mano.global_position
	return global_position
