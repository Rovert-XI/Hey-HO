class_name ElementoPlayground
extends Area3D

func _ready() -> void:
	collision_layer = 4 # capa 3 (elementos): ¿qué valor tiene?
	collision_mask = 2 # que detecte solo las pelotas (capa 2)
	body_entered.connect(_on_body_entered)
	
func _physics_process(delta: float) -> void:
	for cuerpo in get_overlapping_bodies(): # los cuerpos que están adentro del área
		if cuerpo is RigidBody3D:
			realizar(cuerpo, delta) # que cada hija haga lo suyo, cada frame

func _on_body_entered(cuerpo: Node3D) -> void:
	if cuerpo is RigidBody3D:
		al_entrar(cuerpo) # lo que la hija hace una vez, al entrar

func realizar(_cuerpo: RigidBody3D, _delta: float) -> void:
	pass # la base no hace nada: la redefine cada hija

func al_entrar(_cuerpo: RigidBody3D) -> void:
	pass # la base no hace nada: la redefine cada hija
