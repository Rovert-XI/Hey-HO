class_name Iman
extends ElementoPlayground

@export var k := 20.0
@export var distancia_minima := 0.5

func _ready() -> void:
	super._ready() # Importante para mantener la configuración de capas de la clase base
	print(fuerza_a(2.0, 20.0), " ", fuerza_a(1.0, 20.0))

func realizar(cuerpo: RigidBody3D, _delta: float) -> void:
	var hacia := global_position - cuerpo.global_position # Vector del cuerpo hacia el imán
	var d := maxf(Vectores.longitud(hacia), distancia_minima)
	cuerpo.apply_central_force(Vectores.normalizar(hacia) * fuerza_a(d, k))

static func fuerza_a(d: float, k_: float) -> float:
	return k_ / (d * d) # F = k / d²
