class_name Agarrador
extends Node3D

@export var modelo: Node3D
@export var mano: Node3D
@export var alcance := 3.0 # m
@export var impulso_lanzamiento := 8.0 # N·s

var cargada: RigidBody3D = null
var antes := false

func _physics_process(_delta: float) -> void:
	# TODO 1: E se acaba de presionar (ahora sí, en el frame anterior no)
	var ahora := Input.is_key_pressed(KEY_E)
	var presionado := ahora and not antes
	antes = ahora

	if presionado:
		# TODO 2: si no hay nada cargado, agarrar(); si hay, lanzar()
		if cargada == null:
			agarrar()
		else:
			lanzar()

	# Mantener la pelota pegada a la mano si está cargada
	if cargada != null and is_instance_valid(cargada):
		cargada.global_transform = mano.global_transform

func agarrar() -> void:
	# TODO 3: rayo desde global_position hacia adelante del modelo, de "alcance" metros, solo contra la capa de las pelotas
	var espacio := get_world_3d().direct_space_state
	var desde := global_position
	var adelante := -modelo.global_transform.basis.z
	var hacia := desde + adelante * alcance
	
	var query := PhysicsRayQueryParameters3D.create(desde, hacia)
	query.collision_mask = 2 # Capa de las pelotas
	var resultado := espacio.intersect_ray(query)
	
	# TODO 4: si tocó un RigidBody3D: guardarlo en cargada, que el jugador no choque con ella, congelarla y colgarla de la mano
	if resultado and resultado.collider is RigidBody3D:
		cargada = resultado.collider as RigidBody3D
		
		# Evitar colisión entre el jugador y la pelota cargada (asumiendo que el CharacterBody3D es el padre o dueño)
		var cuerpo_jugador = get_parent() as CollisionObject3D
		if cuerpo_jugador:
			cuerpo_jugador.add_collision_exception_with(cargada)
			
		cargada.freeze = true
		cargada.global_transform = mano.global_transform

func lanzar() -> void:
	# TODO 5: devolverla al mundo, que el jugador vuelva a chocar con ella, descongelarla y darle el impulso hacia adelante
	if cargada == null:
		return
		
	# Restaurar colisión con el jugador
	var cuerpo_jugador = get_parent() as CollisionObject3D
	if cuerpo_jugador:
		cuerpo_jugador.remove_collision_exception_with(cargada)
		
	cargada.freeze = false
	
	# Darle el impulso hacia adelante según la orientación del modelo
	var adelante := -modelo.global_transform.basis.z
	cargada.apply_central_impulse(adelante * impulso_lanzamiento)
	
	cargada = null
