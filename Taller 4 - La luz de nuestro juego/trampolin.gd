class_name Trampolin
extends ElementoPlayground

@export var altura := 3.0 # m

func al_entrar(cuerpo: RigidBody3D) -> void:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var vy := cuerpo.linear_velocity.y
	var j := impulso_para_altura(cuerpo.mass, altura, g, vy)
	print("impulso: ", j) #PUNTO 8, NIVEL 1
	cuerpo.apply_central_impulse(Vector3.UP * j)

static func impulso_para_altura(masa: float, h: float, g: float, 
		vy_actual: float) -> float:
	var v_salida := sqrt(2.0 * g * h) # la rapidez para subir h metro
	return masa * (v_salida - vy_actual) # impulso = m · Δv
