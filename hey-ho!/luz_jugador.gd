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
