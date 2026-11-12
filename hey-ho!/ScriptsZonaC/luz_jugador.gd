class_name LuzJugador
extends OmniLight3D # o SpotLight3D si es una linterna
@export var rango := 5.0 # m: hasta dónde alumbra
@export var altura := 1.2 # m sobre los pies del jugador
func _ready() -> void:
	position = Vector3(0.0, altura, 0.0)
	omni_range = rango # en un SpotLight3D es spot_range
	omni_attenuation = 2.0 # la que se parece a 1/d²
	print("atenuación: ",atenuacion(1.0), " ", atenuacion(2.0), " ", atenuacion(4.0))
	
static func atenuacion(d: float, exponente: float = 2.0) -> float:
	return 1.0 / pow(maxf(d, 0.0001), exponente)
	
static func blinn_phong(normal: Vector3, hacia_luz: Vector3,
	hacia_ojo: Vector3, brillo: float) -> float:
	# TODO 1: normalizar los tres vectores (Vectores.normalizar)
	var n = Vectores.normalizar(normal)
	var l = Vectores.normalizar(hacia_luz)
	var v = Vectores.normalizar(hacia_ojo)
	# TODO 2: el vector medio h = normalizar(hacia_luz + hacia_ojo)
	var h = Vectores.normalizar(l + v)
	# TODO 3: max(0, n · h) elevado a brillo (pow)
	var n_dot_h = maxf(0.0, n.dot(h))
	return pow(n_dot_h, brillo)
