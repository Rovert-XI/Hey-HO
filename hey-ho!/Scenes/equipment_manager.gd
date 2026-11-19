extends Node
class_name EquipmentManager

# Se emite cuando el jugador suelta el clic tras tensar con la resortera.
# Quien instancie prendas, rocas o proyectiles puede conectarse a esta señal.
signal disparo_soltado(velocidad: Vector3, tipo_item: TipoItem)

# Slots disponibles del equipo. Mantener un enum centralizado evita "números mágicos" sueltos.
enum TipoItem {
	NINGUNO,
	RESORTERA,
	PRENDA,
	ROCA
}

@export_group("Referencias de Escena")
# Escena 3D de la resortera que aparece en la mano cuando está equipada.
@export var escena_resortera_3d: PackedScene
# Nodo 3D donde se monta la resortera y desde donde nace el tiro.
@export var punto_mano_path: NodePath
# Nodo TrayectoriaResorte encargado de mostrar/ocultar los puntos de la parábola.
@export var trayectoria_path: NodePath
# Gestor de munición para validar si hay prendas disponibles antes de apuntar/disparar.
@export var municion_manager_path: NodePath

@export_group("Dinamica Tipo Angry Birds")
# Máximo de píxeles que se puede arrastrar el cursor/toque desde el punto inicial.
@export var distancia_max_arrastre := 220.0
# Velocidad máxima (en unidades 3D/seg) al alcanzar el jalón máximo.
@export var velocidad_maxima := 18.0
# Qué tanto afecta la dirección vertical del jalón a la altura/caída de la parábola.
@export var factor_angulo_vertical := 1.0
# Qué tanto gira la parábola a izquierda o derecha según el jalón horizontal.
@export var factor_giro_lateral := 1.0
# Invierte el giro lateral si al arrastrar a la derecha el arco se va al lado contrario.
@export var invertir_giro_lateral := false

var item_actual: TipoItem = TipoItem.NINGUNO
var instancia_resortera: Node3D = null
var esta_tensando: bool = false

var _inicio_arrastre: Vector2 = Vector2.ZERO
var _velocidad_tiro: Vector3 = Vector3.ZERO

@onready var _punto_mano: Node3D = get_node_or_null(punto_mano_path)
@onready var _trayectoria: Node3D = get_node_or_null(trayectoria_path)
@onready var _municion: MunicionManager = get_node_or_null(municion_manager_path) as MunicionManager


func _ready() -> void:
	# Inicia sin ítem equipado y con la trayectoria oculta.
	seleccionar_item(0)


func _unhandled_input(event: InputEvent) -> void:
	# Primero revisa si se presionó una tecla numérica para cambiar de slot.
	if _procesar_cambio_slot_por_teclado(event):
		return

	# Si no tiene la resortera o no hay munición de prenda, oculta el arco y no apunta.
	if not _puede_disparar_item_actual():
		_cancelar_tension()
		return

	_procesar_entrada_resortera(event)


# Cambia el ítem activo (útil tanto para teclas como para señales de botones del hotbar).
func seleccionar_item(indice_slot: int) -> void:
	_cancelar_tension()
	item_actual = _convertir_slot_a_item(indice_slot)
	_actualizar_modelo_en_mano()


# --- Validación de estado y munición ---

func _puede_disparar_item_actual() -> bool:
	if item_actual != TipoItem.RESORTERA:
		return false

	# Si existe MunicionManager, exige tener al menos 1 prenda disponible.
	if _municion != null:
		return _municion.tiene_prendas()

	return true


# --- Manejo de entradas (teclado y mouse/táctil) ---

func _procesar_cambio_slot_por_teclado(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false

	match event.keycode:
		KEY_1:
			seleccionar_item(1) # RESORTERA
			return true
		KEY_2:
			seleccionar_item(2) # PRENDA
			return true
		KEY_3:
			seleccionar_item(3) # ROCA
			return true
		_:
			return false


func _procesar_entrada_resortera(event: InputEvent) -> void:
	# Clic izquierdo: empieza a tensar al presionar; dispara y limpia al soltar.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_iniciar_tension(get_viewport().get_mouse_position())
		elif esta_tensando:
			_soltar_y_disparar()
		return

	# Movimiento del cursor mientras se mantiene tensado: recalcula y actualiza el arco.
	if event is InputEventMouseMotion and esta_tensando:
		_actualizar_arco_desde_cursor(event.position)


# --- Ciclo de tensión, trayectoria y disparo ---

func _iniciar_tension(posicion_pantalla: Vector2) -> void:
	esta_tensando = true
	_inicio_arrastre = posicion_pantalla
	_velocidad_tiro = Vector3.ZERO


func _actualizar_arco_desde_cursor(posicion_actual: Vector2) -> void:
	var limite: float = maxf(distancia_max_arrastre, 1.0)
	# Vector real desde donde empezó el jalón hasta la posición actual, limitado al máximo.
	var jalon: Vector2 = (posicion_actual - _inicio_arrastre).limit_length(limite)

	_velocidad_tiro = _calcular_velocidad_angry_birds(jalon, limite)

	if _trayectoria != null and _trayectoria.has_method("mostrar_trayectoria"):
		_trayectoria.mostrar_trayectoria(_obtener_origen_disparo(), _velocidad_tiro)


func _soltar_y_disparar() -> void:
	var velocidad_final: Vector3 = _velocidad_tiro

	_cancelar_tension()

	# Solo dispara si hubo un jalón real y aún queda munición de prenda.
	if velocidad_final.length_squared() > 0.01 and (_municion == null or _municion.tiene_prendas()):
		disparo_soltado.emit(velocidad_final, TipoItem.PRENDA)


func _cancelar_tension() -> void:
	esta_tensando = false
	_velocidad_tiro = Vector3.ZERO
	if _trayectoria != null and _trayectoria.has_method("ocultar_trayectoria"):
		_trayectoria.ocultar_trayectoria()


# --- Cálculo matemático de la parábola tipo Angry Birds ---

func _calcular_velocidad_angry_birds(jalon: Vector2, limite: float) -> Vector3:
	# Si casi no se ha movido el cursor, no hay dirección definida.
	if jalon.length_squared() < 1.0:
		return Vector3.ZERO

	# En Angry Birds se apunta en dirección opuesta al jalón.
	var direccion_jalon_opuesta: Vector2 = (-jalon).normalized()

	# La fuerza depende de qué tan lejos del punto inicial se jaló (0.0 a 1.0).
	var potencia: float = clampf(jalon.length() / limite, 0.0, 1.0)
	var rapidez: float = potencia * velocidad_maxima

	var adelante: Vector3 = _obtener_eje_adelante()
	var derecha: Vector3 = _obtener_eje_derecha(adelante)

	# Si jalas hacia abajo (jalon.y > 0), direccion_jalon_opuesta.y es positivo -> sube más.
	# Si jalas hacia arriba (jalon.y < 0), direccion_jalon_opuesta.y es negativo -> apunta más bajo.
	var componente_vertical: float = direccion_jalon_opuesta.y * factor_angulo_vertical

	# Si jalas a la izquierda/derecha (jalon.x), gira el vector de tiro hacia los lados.
	var signo_lateral: float = -1.0 if invertir_giro_lateral else 1.0
	var componente_lateral: float = direccion_jalon_opuesta.x * factor_giro_lateral * signo_lateral

	# Mantiene un avance base para que el arco se proyecte hacia adelante en el espacio 3D.
	var componente_adelante: float = maxf(0.35 + direccion_jalon_opuesta.y * 0.4, 0.15)

	var direccion_3d: Vector3 = (
		adelante * componente_adelante
		+ derecha * componente_lateral
		+ Vector3.UP * componente_vertical
	).normalized()

	return direccion_3d * rapidez


# --- Helpers de orientación, slots y modelo 3D ---

func _obtener_eje_adelante() -> Vector3:
	var referencia: Node3D = _punto_mano if _punto_mano != null else _trayectoria
	if referencia == null:
		return Vector3.FORWARD

	# Proyecta el frente local (-Z) al plano horizontal (XZ) para evitar inclinaciones raras.
	var forward: Vector3 = -referencia.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func _obtener_eje_derecha(adelante: Vector3) -> Vector3:
	var right: Vector3 = adelante.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		return Vector3.RIGHT
	return right.normalized()


func _obtener_origen_disparo() -> Vector3:
	if _punto_mano != null:
		return _punto_mano.global_position
	if _trayectoria != null:
		return _trayectoria.global_position
	return Vector3.ZERO


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


func _actualizar_modelo_en_mano() -> void:
	# Limpia la resortera anterior antes de crear una nueva para evitar duplicados.
	if is_instance_valid(instancia_resortera):
		instancia_resortera.queue_free()
		instancia_resortera = null

	if item_actual == TipoItem.RESORTERA and escena_resortera_3d != null and _punto_mano != null:
		instancia_resortera = escena_resortera_3d.instantiate()
		_punto_mano.add_child(instancia_resortera)
