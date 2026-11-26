# 'extends' indica de qué nodo base hereda este script (un cuerpo rígido afectado por gravedad y colisiones).
extends RigidBody3D
# 'class_name' registra este script como un tipo global para poder referenciarlo desde otros scripts.
class_name PrendaProyectil

# 'enum' define un conjunto fijo de constantes nombradas para representar los estados posibles de la ropa.
enum EstadoPrenda {
	SUCIA,   # 0: Recién salida del canasto de clientes.
	LAVADA,  # 1: Procesada en la lavadora, lista para tender.
	SECA     # 2: Procesada en el tendedero, lista para despachar.
}

# '@export' expone la variable en el panel Inspector de Godot para editarla sin tocar código.
@export var estado: EstadoPrenda = EstadoPrenda.SUCIA
@export var tiempo_vida_segundos := 18.0
# 'PackedScene' guarda una referencia a una escena empaquetada (.tscn) lista para instanciar en tiempo de ejecución.
@export var escena_prenda_recolectable: PackedScene

# Indica si este proyectil fue disparado de vuelta por una lavadora o tendedero hacia PlataformaCentral.
var es_retorno_de_maquina: bool = false
# Bandera interna ('_' al inicio indica uso privado) para evitar instanciar dos recolectables en un mismo choque.
var _convertida: bool = false


# '_ready()' es un callback de Godot que se ejecuta una sola vez cuando el nodo entra al árbol de escena.
# '-> void' indica que la función no devuelve ningún valor.
func _ready() -> void:
	# Agrega este nodo a un grupo global para que el raycast de trayectoria lo ignore al apuntar.
	add_to_group("prendas_proyectil")

	# Desactiva la fricción del aire de Godot para que el vuelo coincida 100% con la parábola blanca.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0

	# Activa la detección de colisiones físicas en el RigidBody3D para disparar la señal 'body_entered'.
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	_actualizar_visual_por_estado()

	# Crea un temporizador descartable para eliminar la prenda si cae al agua o queda perdida.
	if tiempo_vida_segundos > 0.0:
		var temporizador := get_tree().create_timer(tiempo_vida_segundos)
		temporizador.timeout.connect(queue_free)


# Función pública para asignar el estado de la prenda al crearla.
# Recibe: 'nuevo_estado' (un valor del enum EstadoPrenda). Devuelve: nada (void).
func configurar_estado(nuevo_estado: EstadoPrenda) -> void:
	estado = nuevo_estado
	_actualizar_visual_por_estado()


# Impulsa el cuerpo físico en el espacio 3D.
# Recibe: 'velocidad_inicial' (Vector3 en metros/segundo calculado por la resortera o máquina). Devuelve: void.
func lanzar(velocidad_inicial: Vector3) -> void:
	linear_velocity = velocidad_inicial


# Callback conectado a la señal 'body_entered' del RigidBody3D.
# Recibe: 'body' (el nodo físico con el que acaba de chocar la prenda). Devuelve: void.
func _on_body_entered(body: Node) -> void:
	if _convertida or not es_retorno_de_maquina:
		return

	# Verifica si chocó directamente con PlataformaCentral o con su StaticBody3D hijo.
	var padre: Node = body.get_parent()
	if body.name == "PlataformaCentral" or (padre != null and padre.name == "PlataformaCentral"):
		_convertir_en_recolectable()


# Reemplaza este proyectil físico por una PrendaRecolectable (Area3D) en el suelo para poder recogerla con 'P'.
# No recibe parámetros y no devuelve valor (void).
func _convertir_en_recolectable() -> void:
	if escena_prenda_recolectable == null:
		return

	_convertida = true
	# 'instantiate()' crea una copia viva en memoria a partir del archivo .tscn asignado.
	var recolectable := escena_prenda_recolectable.instantiate()
	var padre_mundo := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	padre_mundo.add_child(recolectable)

	# 'is' comprueba en tiempo de ejecución si el nodo instanciado hereda de la clase indicada.
	if recolectable is Node3D:
		(recolectable as Node3D).global_position = global_position + Vector3.UP * 0.25
	if recolectable.has_method("configurar_estado"):
		recolectable.configurar_estado(estado)

	# 'queue_free()' marca este proyectil para eliminarse de forma segura al final del frame actual.
	queue_free()


# Crea un material dinámico según el estado actual y lo aplica a todas las mallas 3D hijas.
# No recibe parámetros y no devuelve valor (void).
func _actualizar_visual_por_estado() -> void:
	var material := StandardMaterial3D.new()
	# 'match' evalúa el valor de 'estado' (equivalente a switch en otros lenguajes).
	match estado:
		EstadoPrenda.SUCIA:
			material.albedo_color = Color(0.468, 0.334, 0.127, 1.0) # Café (sucia)
		EstadoPrenda.LAVADA:
			material.albedo_color = Color(0.35, 0.72, 0.95)          # Azul húmedo (lavada)
		EstadoPrenda.SECA:
			material.albedo_color = Color(0.96, 0.96, 0.92)          # Blanco limpio (seca)

	# Recorre todos los nodos hijos de tipo MeshInstance3D (recursivo) y sobrescribe su material.
	for nodo in find_children("*", "MeshInstance3D", true, false):
		var malla := nodo as MeshInstance3D
		if malla != null:
			malla.material_override = material
