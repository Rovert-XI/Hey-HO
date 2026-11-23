class_name SistemaSol
extends Node
## SISTEMA DEL SOL (Carlos, Tarea A).
## Mueve la luz principal del nivel según la hora del día (CicloDia) y reacciona al peligro de las sogas.
## Cómo se usa: el nivel llama poner_nivel(n) al empezar, las sogas llaman poner_peligro() cuando una
## está floja, y anunciar_derrota() apaga el sol cuando se pierde el nivel.

## Avisa cuando el sol se pone (true) o sale (false). Sirve para sonidos o efectos.
signal cambio_noche(es_noche: bool)

# ---------------------------------------------------------------- Piezas que se asignan en el Inspector
@export var sol: DirectionalLight3D
@export var entorno: WorldEnvironment
@export var cielo: CieloAtardecer          # cielo 2D con el sol al fondo (opcional)

# ---------------------------------------------------------------- Ajustes de la luz
@export var energia_sol := 1.0
@export var azimut := -30.0                # hacia dónde mira la luz (giro horizontal)
@export var ambiente_dia := 1.0            # luz ambiente con el sol alto
@export var ambiente_noche := 0.2          # luz ambiente cuando ya no hay sol
@export var rojo_peligro := Color("#D63A3A")
## Hora del día (en horas decimales) con la que arranca cada nivel: 14:00, 14:40, 15:20, 16:00, 16:40.
@export var horas_por_nivel: Array[float] = [14.0, 14.6667, 15.3333, 16.0, 16.6667]
@export var duracion_transicion := 2.0     # segundos que tarda el sol en pasar a la hora del nivel

@onready var ciclo: CicloDia = $CicloDia   # el reloj; este nodo hijo lleva la hora

# ---------------------------------------------------------------- Estado
var era_noche := false
var peligro := 0.0                         # 0 = todo bien, 1 = soga a punto de soltarse
var apagado := 1.0                         # 1 = sol encendido, 0 = apagado (derrota)
var _tween_derrota: Tween
var _tween_nivel: Tween


func _ready() -> void:
	aplicar_hora()
	era_noche = CicloDia.factor_sol(ciclo.hora) <= 0.0


## Cada fotograma: avanza el reloj, recalcula la luz y avisa si cambió de día a noche.
func _process(delta: float) -> void:
	ciclo.avanzar(delta)
	aplicar_hora()
	var es_noche := CicloDia.factor_sol(ciclo.hora) <= 0.0
	if es_noche != era_noche:
		era_noche = es_noche
		cambio_noche.emit(es_noche)


# ---------------------------------------------------------------- Luz según la hora
## Pone la luz como corresponde a la hora actual: ángulo, fuerza, color y luz ambiente.
func aplicar_hora() -> void:
	var h := ciclo.hora
	var f := CicloDia.factor_sol(h)        # 0 (noche) a 1 (sol alto)
	sol.rotation_degrees = Vector3(-CicloDia.elevacion(h), azimut, 0.0)
	# La fuerza baja hasta un 30 % con el peligro y a 0 cuando se apaga por derrota.
	sol.light_energy = energia_sol * f * (1.0 - 0.3 * peligro) * apagado
	# El color va de naranja a blanco con la hora, y se tiñe de rojo con el peligro.
	sol.light_color = CicloDia.color_sol(h).lerp(rojo_peligro, 0.4 * peligro)
	entorno.environment.ambient_light_energy = lerpf(ambiente_noche, ambiente_dia, f)
	if cielo:
		cielo.poner_hora(h, apagado)       # el sol del fondo sigue a la misma hora


# ---------------------------------------------------------------- Peligro de las sogas
## Convierte la resistencia de una soga en peligro: 30 o más = 0, y sube hasta 1 cuando llega a 0.
static func peligro_soga(resistencia: float) -> float:
	return clampf((30.0 - resistencia) / 30.0, 0.0, 1.0)


## Las sogas llaman esto con la resistencia de la soga más débil.
func poner_peligro(resistencia_min: float) -> void:
	peligro = peligro_soga(resistencia_min)


# ---------------------------------------------------------------- Derrota y niveles
## Nivel perdido: el sol se apaga en 2 s. Cancela un apagado anterior para no apilar tweens.
func anunciar_derrota() -> void:
	if _tween_derrota and _tween_derrota.is_valid():
		_tween_derrota.kill()
	_tween_derrota = create_tween()
	_tween_derrota.tween_property(self, "apagado", 0.0, 2.0)
	cambio_noche.emit(true)


## Lleva el sol a la hora del nivel `n` con una transición suave.
func poner_nivel(n: int, suave := true) -> void:
	var i := clampi(n - 1, 0, horas_por_nivel.size() - 1)
	var destino := horas_por_nivel[i]
	reiniciar_luz()
	if suave:
		_tween_nivel = create_tween()
		_tween_nivel.tween_property(ciclo, "hora", destino, duracion_transicion)
	else:
		ciclo.hora = destino               # sin animación: salta directo a la hora


## Deja la luz como nueva: sin peligro, sol encendido y sin animaciones pendientes.
func reiniciar_luz() -> void:
	if _tween_derrota and _tween_derrota.is_valid():
		_tween_derrota.kill()
	if _tween_nivel and _tween_nivel.is_valid():
		_tween_nivel.kill()
	peligro = 0.0
	apagado = 1.0


# ---------------------------------------------------------------- Matemática (funciones static: se prueban sin escena)
static func _normalizar(v: Vector3) -> Vector3:
	var largo := sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	if largo == 0.0:
		return Vector3.ZERO
	return v / largo


## Cuánta luz recibe una superficie: 1 si mira de frente al sol, 0 si le da de lado o por detrás.
static func lambert(normal: Vector3, hacia_luz: Vector3) -> float:
	var n := _normalizar(normal)
	var l := _normalizar(hacia_luz)
	return maxf(0.0, n.dot(l))


## Qué tan iluminado queda el piso con la luz actual (para comprobar que el sol alumbra bien).
func prediccion_piso() -> float:
	var hacia_luz := sol.global_transform.basis.z
	return sol.light_energy * sol.light_color.r * lambert(Vector3.UP, hacia_luz)
