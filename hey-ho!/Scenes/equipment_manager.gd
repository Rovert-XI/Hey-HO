# 'extends' indica que este script hereda de 'Node' (un nodo lógico sin posición propia en 3D).
extends Node
# 'class_name' registra esta clase globalmente para poder tipar variables como ': EquipmentManager'.
class_name EquipmentManager

# 'signal' declara un evento personalizado que otros nodos (como LanzadorPrenda) pueden escuchar sin acoplarse.
signal disparo_soltado(velocidad: Vector3, tipo_item: TipoItem)

# 'enum' crea un conjunto de constantes enteras con nombre para identificar qué tiene equipado el jugador.
enum TipoItem {
	NINGUNO,    # 0: Manos vacías.
	RESORTERA,  # 1: Resortera equipada para apuntar y lanzar.
	PRENDA,     # 2: Tipo de proyectil correspondiente a ropa.
	ROCA        # 3: Tipo de proyectil futuro para rocas.
}

# '@export_group' organiza las propiedades siguientes bajo una cabecera desplegable en el Inspector.
@export_group("Referencias de Escena")
# 'PackedScene' guarda una referencia a una escena (.tscn) lista para instanciar.
@export var escena_resortera_3d: PackedScene
# 'NodePath' almacena la ruta hacia otro nodo dentro del árbol de escena.
@export var punto_mano_path: NodePath
@export var trayectoria_path: NodePath
@export var municion_manager_path: NodePath

@export_group("Dinamica Tipo Angry Birds")
# Máximo de píxeles en pantalla que se puede arrastrar el ratón desde el clic inicial.
@export var distancia_max_arrastre := 200.0
# Rapidez horizontal mínima y máxima (en m/s) según qué tanto jales el cursor.
@export var velocidad_horizontal_min := 2.0
@export var velocidad_horizontal_max := 11.5
# Impulso vertical mínimo y máximo (en m/s) calibrado para formar un arco limpio sin salirse de cámara.
@export var impulso_vertical_min := 3.2
@export var impulso_vertical_max := 6.4
# Si es 'true', jalas hacia atrás para disparar hacia adelante (estilo resortera / Angry Birds).
@export var modo_resortera_inverso := true

# Variables de estado público para consultar qué ítem está activo y si el jugador está tensando.
var item_actual: TipoItem = TipoItem.NINGUNO
var instancia_resortera: Node3D = null
var esta_tensando: bool = false

# Variables privadas ('_' inicial) que guardan el punto de inicio del clic y el vector de velocidad calculado.
var _inicio_arrastre: Vector2 = Vector2.ZERO
var _velocidad_tiro: Vector3 = Vector3.ZERO

# '@onready' busca y asigna las referencias de nodos justo antes de que se ejecute '_ready()'.
@onready var _punto_mano: Node3D = get_node_or_null(punto_mano_path)
@onready var _trayectoria: Node = get_node_or_null(trayectoria_path)
# 'as' convierte el nodo genérico obtenido al tipo 'MunicionManager' (o 'null' si no coincide).
@onready var _municion: MunicionManager = get_node_or_null(municion_manager_path) as MunicionManager


# Callback que ejecuta Godot una sola vez cuando el nodo entra en el árbol de escena.
# '-> void' indica que no devuelve ningún valor.
func _ready() -> void:
	seleccionar_item(0)


# Callback que recibe los eventos de teclado o ratón que no fueron consumidos antes por la interfaz (UI).
# Recibe: 'event' (InputEvent con los datos de la tecla o clic). Devuelve: void.
func _unhandled_input(event: InputEvent) -> void:
	if _procesar_cambio_slot_por_teclado(event):
		return

	# Si no tiene la resortera equipada o se quedó sin prendas, cancela cualquier tensión activa.
	if not _puede_disparar_item_actual():
		_cancelar_tension()
		return

	_procesar_entrada_resortera(event)


# Cambia el ítem equipado según el número de slot elegido y actualiza el modelo 3D en la mano.
# Recibe: 'indice_slot' (int: 0 vacío, 1 resortera, 2 prenda, 3 roca). Devuelve: void.
func seleccionar_item(indice_slot: int) -> void:
	_cancelar_tension()
	item_actual = _convertir_slot_a_item(indice_slot)
	_actualizar_modelo_en_mano()


# --- Validación de estado y munición ---

# Comprueba si el jugador cumple las condiciones para apuntar y disparar.
# No recibe parámetros. Devuelve: 'bool' (true si tiene resortera y al menos 1 prenda disponible).
func _puede_disparar_item_actual() -> bool:
	if item_actual != TipoItem.RESORTERA:
		return false

	if _municion != null:
		return _municion.tiene_prendas()

	return true


# --- Manejo de entradas ---

# Detecta las teclas 1, 2 o 3 para equipar el slot correspondiente.
# Recibe: 'event' (InputEvent). Devuelve: 'bool' (true si procesó una tecla de slot, false en caso contrario).
func _procesar_cambio_slot_por_teclado(event: InputEvent) -> bool:
	# Verifica que sea una pulsación de tecla nueva (no mantenida/echo).
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false

	# 'match' evalúa el código de la tecla presionada.
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


# Gestiona el clic izquierdo (tensar y soltar), clic derecho (cancelar) y movimiento del ratón.
# Recibe: 'event' (InputEvent). Devuelve: void.
func _procesar_entrada_resortera(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_iniciar_tension(get_viewport().get_mouse_position())
			elif esta_tensando:
				_soltar_y_disparar()
			return
		# Clic derecho mientras tensas aborta el disparo sin gastar prendas.
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and esta_tensando:
			_cancelar_tension()
			return

	if event is InputEventMouseMotion and esta_tensando:
		_actualizar_arco_desde_cursor(event.position)


# --- Ciclo de tensión, trayectoria y disparo ---

# Activa el modo de apuntado y guarda las coordenadas en pantalla donde empezó el clic.
# Recibe: 'posicion_pantalla' (Vector2 en píxeles). Devuelve: void.
func _iniciar_tension(posicion_pantalla: Vector2) -> void:
	esta_tensando = true
	_inicio_arrastre = posicion_pantalla
	_velocidad_tiro = Vector3.ZERO


# Recalcula el vector de velocidad según cuánto arrastró el ratón y actualiza los puntos blancos.
# Recibe: 'posicion_actual' (Vector2 en píxeles). Devuelve: void.
func _actualizar_arco_desde_cursor(posicion_actual: Vector2) -> void:
	# 'maxf' devuelve el mayor entre dos decimales, evitando una división por cero.
	var limite: float = maxf(distancia_max_arrastre, 1.0)
	# 'limit_length' recorta la longitud del vector 2D para que no supere el radio máximo de arrastre.
	var jalon: Vector2 = (posicion_actual - _inicio_arrastre).limit_length(limite)

	_velocidad_tiro = _calcular_velocidad_360(jalon, limite)

	# 'has_method' comprueba si el nodo trayectoria posee esa función antes de llamarla.
	if _trayectoria != null and _trayectoria.has_method("mostrar_trayectoria"):
		_trayectoria.mostrar_trayectoria(_obtener_origen_disparo(), _velocidad_tiro)


# Finaliza la tensión y emite la señal 'disparo_soltado' si el tiro tiene suficiente fuerza.
# No recibe parámetros. Devuelve: void.
func _soltar_y_disparar() -> void:
	var velocidad_final: Vector3 = _velocidad_tiro
	_cancelar_tension()

	if velocidad_final.length_squared() > 0.01 and (_municion == null or _municion.tiene_prendas()):
		# '.emit()' dispara la señal para que LanzadorPrenda instancie y lance el proyectil.
		disparo_soltado.emit(velocidad_final, TipoItem.PRENDA)


# Apaga el estado de tensión, reinicia la velocidad y oculta la parábola visual.
# No recibe parámetros. Devuelve: void.
func _cancelar_tension() -> void:
	esta_tensando = false
	_velocidad_tiro = Vector3.ZERO
	if _trayectoria != null and _trayectoria.has_method("ocultar_trayectoria"):
		_trayectoria.ocultar_trayectoria()


# --- Cálculo 360° relativo a la cámara ---

# Convierte el arrastre 2D del ratón en una velocidad 3D alineada con la vista de la cámara.
# Recibe: 'jalon' (Vector2 del arrastre) y 'limite' (float máximo de arrastre). Devuelve: 'Vector3' (velocidad inicial).
func _calcular_velocidad_360(jalon: Vector2, limite: float) -> Vector3:
	# Zona muerta de 8 píxeles para evitar disparos accidentales al hacer clic sin arrastrar.
	if jalon.length() < 8.0:
		return Vector3.ZERO

	# Si el modo resortera está activo, invierte el vector para apuntar al lado opuesto del jalón.
	var vector_apuntado: Vector2 = -jalon if modo_resortera_inverso else jalon
	# 'clampf' restringe la potencia normalizada estrictamente al rango [0.0, 1.0].
	var potencia: float = clampf(jalon.length() / limite, 0.0, 1.0)

	var ejes_camara: Array[Vector3] = _obtener_ejes_horizontales_camara()
	var adelante_camara: Vector3 = ejes_camara[0] # Dirección hacia arriba en pantalla (-Z).
	var derecha_camara: Vector3 = ejes_camara[1]  # Dirección hacia la derecha en pantalla (+X).

	# En coordenadas de pantalla, Y crece hacia abajo; invertir 'vector_apuntado.y' proyecta hacia adelante en 3D.
	var direccion_horizontal: Vector3 = (
		derecha_camara * vector_apuntado.x
		+ adelante_camara * (-vector_apuntado.y)
	)

	if direccion_horizontal.length_squared() < 0.0001:
		return Vector3.ZERO

	# '.normalized()' convierte el vector en dirección pura de longitud 1.
	direccion_horizontal = direccion_horizontal.normalized()
	_rotar_jugador_hacia(direccion_horizontal)

	# 'lerpf' interpola linealmente entre el valor mínimo y máximo según 'potencia' (0.0 a 1.0).
	var rapidez_horizontal: float = lerpf(velocidad_horizontal_min, velocidad_horizontal_max, potencia)
	var rapidez_vertical: float = lerpf(impulso_vertical_min, impulso_vertical_max, potencia)

	return direccion_horizontal * rapidez_horizontal + Vector3.UP * rapidez_vertical


# Obtiene los vectores unitarios adelante y derecha de la cámara proyectados sobre el plano horizontal (XZ).
# No recibe parámetros. Devuelve: 'Array[Vector3]' con dos elementos: [adelante, derecha].
func _obtener_ejes_horizontales_camara() -> Array[Vector3]:
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null:
		return [Vector3.FORWARD, Vector3.RIGHT]

	# En Godot, el eje '-basis.z' apunta hacia donde mira la cámara. Se anula 'y' para mantenerlo paralelo al suelo.
	var forward: Vector3 = -camara.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD

	var right: Vector3 = camara.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT

	return [forward, right]


# Orienta el cuerpo del personaje hacia la dirección horizontal en la que está apuntando.
# Recibe: 'direccion_horizontal' (Vector3 normalizado en el plano XZ). Devuelve: void.
func _rotar_jugador_hacia(direccion_horizontal: Vector3) -> void:
	if _punto_mano == null:
		return

	# Recorre los nodos padres hacia arriba hasta encontrar el 'CharacterBody3D' del jugador.
	var nodo_actual: Node = _punto_mano.get_parent()
	while nodo_actual != null:
		if nodo_actual is CharacterBody3D:
			var cuerpo := nodo_actual as CharacterBody3D
			var objetivo: Vector3 = cuerpo.global_position + direccion_horizontal
			# 'look_at' gira el nodo para que su frente (-Z) mire hacia el punto 'objetivo'.
			cuerpo.look_at(objetivo, Vector3.UP)
			return
		nodo_actual = nodo_actual.get_parent()


# --- Helpers de origen, slots y modelo 3D ---

# Devuelve el punto global desde donde parte tanto la trayectoria visual como el proyectil físico.
# No recibe parámetros. Devuelve: 'Vector3'.
func _obtener_origen_disparo() -> Vector3:
	if _punto_mano != null:
		return _punto_mano.global_position
	if _trayectoria is Node3D:
		return (_trayectoria as Node3D).global_position
	return Vector3.ZERO


# Traduce un índice numérico de tecla/botón a su constante correspondiente del enum 'TipoItem'.
# Recibe: 'indice_slot' (int). Devuelve: 'TipoItem'.
func _convertir_slot_a_item(indice_slot: int) -> TipoItem:
	match indice_slot:
		1:
			return TipoItem.RESORTERA
		2:
			return TipoItem.PRENDA
		3:
			return TipoItem.ROCA
		_:
			return TipoItem.NINGUNO


# Instancia o destruye el modelo 3D de la resortera en el nodo 'PuntoMano' según si está equipada.
# No recibe parámetros. Devuelve: void.
func _actualizar_modelo_en_mano() -> void:
	# 'is_instance_valid' verifica que el objeto exista en memoria y no haya sido liberado antes.
	if is_instance_valid(instancia_resortera):
		instancia_resortera.queue_free()
		instancia_resortera = null

	if item_actual == TipoItem.RESORTERA and escena_resortera_3d != null and _punto_mano != null:
		instancia_resortera = escena_resortera_3d.instantiate()
		_punto_mano.add_child(instancia_resortera)
