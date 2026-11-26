# 'extends' indica la clase base de Godot de la que hereda este nodo (un nodo con posición/rotación en 3D).
extends Node3D
# 'class_name' registra esta clase de forma global para poder referenciarla por su nombre en otros scripts.
class_name LanzadorPrenda

# '@export_group' agrupa visualmente las siguientes variables exportadas bajo una sección en el Inspector.
@export_group("Dependencias")
# 'NodePath' guarda la ruta relativa hacia otro nodo dentro del árbol de escena.
@export var equipment_manager_path: NodePath
@export var municion_manager_path: NodePath
# 'PackedScene' almacena una escena empaquetada (.tscn) lista para ser instanciada en memoria.
@export var escena_prenda_proyectil: PackedScene

@export_group("Configuracion de Spawn")
# Desplazamiento extra desde el origen. En 0.0 la prenda nace en el punto exacto donde inicia la parábola blanca.
@export var offset_salida := 0.0

# '@onready' retrasa la asignación de la variable hasta justo antes de ejecutar '_ready()', cuando los nodos hijos ya existen.
# 'as' convierte (castea) el nodo genérico obtenido al tipo específico; si no coincide, devuelve 'null'.
@onready var _equipment: EquipmentManager = get_node_or_null(equipment_manager_path) as EquipmentManager
@onready var _municion: MunicionManager = get_node_or_null(municion_manager_path) as MunicionManager


# Callback del ciclo de vida de Godot que se ejecuta una sola vez al entrar el nodo en escena.
# No recibe parámetros y '-> void' indica que no devuelve ningún valor.
func _ready() -> void:
	# Conecta la señal 'disparo_soltado' de EquipmentManager al método local '_on_disparo_soltado' (desacoplamiento por eventos).
	if _equipment != null and not _equipment.disparo_soltado.is_connected(_on_disparo_soltado):
		_equipment.disparo_soltado.connect(_on_disparo_soltado)


# Callback que responde cada vez que el jugador suelta el clic tras tensar la resortera.
# Recibe: 'velocidad' (Vector3 con dirección y rapidez inicial) y 'tipo_item' (int del enum TipoItem). Devuelve: void.
func _on_disparo_soltado(velocidad: Vector3, tipo_item: int) -> void:
	# Ignora el evento si el ítem disparado no corresponde a una prenda de ropa.
	if tipo_item != EquipmentManager.TipoItem.PRENDA:
		return

	if not _puede_instanciar_proyectil():
		return

	# Consume la siguiente prenda de la cola FIFO y recupera su estado (SUCIA, LAVADA o SECA).
	var estado_prenda: int = _obtener_y_consumir_estado_prenda()
	if estado_prenda < 0:
		return

	_instanciar_y_lanzar(velocidad, estado_prenda as PrendaProyectil.EstadoPrenda)


# Verifica que la escena del proyectil esté asignada en el Inspector antes de intentar crearla.
# No recibe parámetros. Devuelve: 'bool' (true si existe la escena, false si falta asignarla).
func _puede_instanciar_proyectil() -> bool:
	if escena_prenda_proyectil == null:
		push_warning("LanzadorPrenda: falta asignar escena_prenda_proyectil en el Inspector.")
		return false
	return true


# Solicita al MunicionManager descontar la primera prenda disponible en cola.
# No recibe parámetros. Devuelve: 'int' (el valor numérico de EstadoPrenda, o -1 si no hay munición).
func _obtener_y_consumir_estado_prenda() -> int:
	if _municion == null:
		return PrendaProyectil.EstadoPrenda.SUCIA

	var estado_consumido: int = _municion.consumir_siguiente_prenda()
	if estado_consumido < 0:
		print("No tienes prendas en el inventario para disparar.")
		return -1

	return estado_consumido


# Instancia el RigidBody3D en la escena principal, evita que choque con el jugador y lo impulsa.
# Recibe: 'velocidad' (Vector3 del lanzamiento) y 'estado_prenda' (PrendaProyectil.EstadoPrenda). Devuelve: void.
func _instanciar_y_lanzar(velocidad: Vector3, estado_prenda: PrendaProyectil.EstadoPrenda) -> void:
	var origen: Vector3 = _obtener_origen_disparo()
	var direccion: Vector3 = velocidad.normalized() if velocidad.length_squared() > 0.0001 else Vector3.FORWARD
	var instancia: Node = escena_prenda_proyectil.instantiate()

	# Se agrega a la escena raíz del nivel y no a PuntoMano para que el proyectil vuele independiente del jugador.
	var padre_mundo: Node = get_tree().current_scene if get_tree().current_scene != null else self
	padre_mundo.add_child(instancia)

	# 'is' verifica el tipo en tiempo de ejecución. Evita que el cuerpo del pirata frene el proyectil al salir.
	if instancia is RigidBody3D:
		var jugador: PhysicsBody3D = _obtener_cuerpo_jugador()
		if jugador != null:
			(instancia as RigidBody3D).add_collision_exception_with(jugador)

	var posicion_spawn: Vector3 = origen + direccion * offset_salida
	if instancia is PrendaProyectil:
		var proyectil := instancia as PrendaProyectil
		proyectil.global_position = posicion_spawn
		proyectil.configurar_estado(estado_prenda)
		proyectil.lanzar(velocidad)
	elif instancia is Node3D:
		(instancia as Node3D).global_position = posicion_spawn


# Sube por la jerarquía de nodos desde PuntoMano hasta encontrar el cuerpo físico del jugador (CharacterBody3D).
# No recibe parámetros. Devuelve: 'PhysicsBody3D' (el cuerpo del jugador o 'null' si no lo encuentra).
func _obtener_cuerpo_jugador() -> PhysicsBody3D:
	if _equipment != null and _equipment._punto_mano != null:
		var nodo_actual: Node = _equipment._punto_mano.get_parent()
		# 'while' recorre los nodos ancestros hacia arriba hasta llegar a la raíz o hallar el PhysicsBody3D.
		while nodo_actual != null:
			if nodo_actual is PhysicsBody3D:
				return nodo_actual as PhysicsBody3D
			nodo_actual = nodo_actual.get_parent()
	return null


# Calcula el punto exacto en coordenadas globales desde donde debe nacer el proyectil.
# No recibe parámetros. Devuelve: 'Vector3' (posición global de PuntoMano o de este nodo como respaldo).
func _obtener_origen_disparo() -> Vector3:
	if _equipment != null and _equipment._punto_mano != null:
		return _equipment._punto_mano.global_position
	return global_position
