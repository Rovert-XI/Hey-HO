@tool
class_name ModeloPirataCuchito
extends Node3D

@export_group("Ajustes Visuales")
@export var escala_modelo: float = 1.0:
	set(valor):
		escala_modelo = valor
		if is_inside_tree():
			_construir_pirata()

@export var con_sombrero_capitan: bool = true:
	set(valor):
		con_sombrero_capitan = valor
		if is_inside_tree():
			_construir_pirata()

@export var con_pata_de_palo: bool = true:
	set(valor):
		con_pata_de_palo = valor
		if is_inside_tree():
			_construir_pirata()

@export_group("Movimiento y Animacion")
@export_enum("ninguna", "idle", "caminar", "lanzar") var vista_previa_editor: String = "ninguna":
	set(valor):
		vista_previa_editor = valor
		if is_inside_tree() and Engine.is_editor_hint():
			_aplicar_vista_previa_editor()

@export var detectar_movimiento_padre: bool = true
@export var rotar_hacia_movimiento: bool = true
@export var velocidad_giro: float = 12.0
@export var umbral_velocidad_caminar: float = 0.20

var _rig: Node3D
var _anim_player: AnimationPlayer
var _reproduciendo_accion: bool = false
var _mano_derecha_socket: Marker3D
var _ultima_pos_padre: Vector3 = Vector3.ZERO
var _tiene_pos_previa: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("modelo_pirata")
		if not get_tree().node_added.is_connected(_on_nodo_agregado_escena):
			get_tree().node_added.connect(_on_nodo_agregado_escena)
	_construir_pirata()

	var padre := get_parent()
	if padre is Node3D:
		_ultima_pos_padre = (padre as Node3D).global_position
		_tiene_pos_previa = true

	if Engine.is_editor_hint():
		_aplicar_vista_previa_editor()
	elif is_instance_valid(_anim_player):
		_anim_player.play(&"idle")


func _on_nodo_agregado_escena(nodo: Node) -> void:
	if nodo is RigidBody3D:
		var padre := get_parent()
		if padre is PhysicsBody3D:
			(nodo as RigidBody3D).add_collision_exception_with(padre as PhysicsBody3D)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not detectar_movimiento_padre:
		return
	if not is_instance_valid(_anim_player):
		return

	var padre := get_parent()
	var dir_horizontal := Vector2.ZERO

	if padre is CharacterBody3D:
		var vel: Vector3 = (padre as CharacterBody3D).velocity
		dir_horizontal = Vector2(vel.x, vel.z)

	if padre is Node3D:
		var pos_actual: Vector3 = (padre as Node3D).global_position
		if _tiene_pos_previa and delta > 0.0001:
			var vel_pos := Vector2(pos_actual.x - _ultima_pos_padre.x, pos_actual.z - _ultima_pos_padre.z) / delta
			if vel_pos.length() > dir_horizontal.length():
				dir_horizontal = vel_pos
		_ultima_pos_padre = pos_actual
		_tiene_pos_previa = true

	var rapidez_horizontal: float = dir_horizontal.length()

	if rotar_hacia_movimiento and is_instance_valid(_rig) and rapidez_horizontal > umbral_velocidad_caminar:
		var angulo_mundo := atan2(dir_horizontal.x, dir_horizontal.y)
		var rot_padre_y: float = (padre as Node3D).global_rotation.y if padre is Node3D else 0.0
		var angulo_local := angulo_mundo - rot_padre_y - rotation.y
		_rig.rotation.y = lerp_angle(_rig.rotation.y, angulo_local, clampf(delta * velocidad_giro, 0.0, 1.0))

	if _reproduciendo_accion:
		return

	var anim_objetivo := &"caminar" if rapidez_horizontal > umbral_velocidad_caminar else &"idle"
	if _anim_player.current_animation != anim_objetivo:
		_anim_player.play(anim_objetivo, 0.15)


func reproducir_lanzamiento(direccion_objetivo: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(_anim_player):
		return
	if is_instance_valid(_rig) and Vector2(direccion_objetivo.x, direccion_objetivo.z).length() > 0.05:
		var padre := get_parent()
		var rot_padre_y: float = (padre as Node3D).global_rotation.y if padre is Node3D else 0.0
		_rig.rotation.y = atan2(direccion_objetivo.x, direccion_objetivo.z) - rot_padre_y - rotation.y
	_reproduciendo_accion = true
	_anim_player.stop()
	_anim_player.play(&"lanzar")


func obtener_socket_mano_derecha() -> Marker3D:
	return _mano_derecha_socket


func _aplicar_vista_previa_editor() -> void:
	if not is_instance_valid(_anim_player):
		return
	if vista_previa_editor == "ninguna":
		_anim_player.stop()
	else:
		_anim_player.play(StringName(vista_previa_editor))


func _construir_pirata() -> void:
	var anterior := get_node_or_null("RigPirata")
	if anterior != null:
		anterior.free()

	var anim_anterior := get_node_or_null("AnimationPlayerPirata")
	if anim_anterior != null:
		anim_anterior.free()

	_rig = Node3D.new()
	_rig.name = "RigPirata"
	_rig.scale = Vector3.ONE * escala_modelo
	add_child(_rig)

	# Paleta clásica estilo 2D pirata
	var mat_piel := _crear_material(Color(0.91, 0.72, 0.58), 0.75)
	var mat_nariz := _crear_material(Color(0.87, 0.49, 0.44), 0.7)
	var mat_barba := _crear_material(Color(0.94, 0.95, 0.97), 0.85)
	var mat_barba_sombra := _crear_material(Color(0.84, 0.86, 0.90), 0.85)
	var mat_rojo := _crear_material(Color(0.78, 0.15, 0.17), 0.65)
	var mat_crema := _crear_material(Color(0.95, 0.91, 0.83), 0.75)
	var mat_abrigo := _crear_material(Color(0.14, 0.21, 0.34), 0.7)
	var mat_sombrero := _crear_material(Color(0.10, 0.10, 0.13), 0.65)
	var mat_pantalon := _crear_material(Color(0.24, 0.18, 0.15), 0.8)
	var mat_cuero := _crear_material(Color(0.14, 0.10, 0.09), 0.55)
	var mat_madera := _crear_material(Color(0.52, 0.33, 0.16), 0.7)
	var mat_oro := _crear_material(Color(0.96, 0.77, 0.18), 0.3, 0.65)
	var mat_negro := _crear_material(Color(0.06, 0.06, 0.08), 0.5)
	var mat_ojo_blanco := _crear_material(Color(0.98, 0.98, 0.99), 0.3)

	# --- PIERNAS ---
	var pivote_pierna_izq := Node3D.new()
	pivote_pierna_izq.name = "PivotePiernaIzq"
	pivote_pierna_izq.position = Vector3(-0.14, 0.46, 0.0)
	_rig.add_child(pivote_pierna_izq)

	_agregar_cilindro(pivote_pierna_izq, "MusloIzq", 0.095, 0.08, 0.22, Vector3(0.0, -0.10, 0.0), mat_pantalon)
	if con_pata_de_palo:
		_agregar_cilindro(pivote_pierna_izq, "AroPataPalo", 0.085, 0.085, 0.05, Vector3(0.0, -0.22, 0.0), mat_cuero)
		_agregar_cilindro(pivote_pierna_izq, "PataDePalo", 0.045, 0.028, 0.24, Vector3(0.0, -0.34, 0.0), mat_madera)
	else:
		_agregar_cilindro(pivote_pierna_izq, "BotaIzq", 0.085, 0.09, 0.22, Vector3(0.0, -0.31, 0.0), mat_cuero)
		_agregar_caja(pivote_pierna_izq, "PuntaBotaIzq", Vector3(0.16, 0.10, 0.24), Vector3(0.0, -0.41, 0.04), mat_cuero)

	var pivote_pierna_der := Node3D.new()
	pivote_pierna_der.name = "PivotePiernaDer"
	pivote_pierna_der.position = Vector3(0.14, 0.46, 0.0)
	_rig.add_child(pivote_pierna_der)

	_agregar_cilindro(pivote_pierna_der, "MusloDer", 0.095, 0.085, 0.24, Vector3(0.0, -0.11, 0.0), mat_pantalon)
	_agregar_cilindro(pivote_pierna_der, "BotaDer", 0.085, 0.095, 0.21, Vector3(0.0, -0.32, 0.0), mat_cuero)
	_agregar_caja(pivote_pierna_der, "PuntaBotaDer", Vector3(0.16, 0.10, 0.25), Vector3(0.0, -0.41, 0.05), mat_cuero)

	# --- TORSO RECHONCHO Y ENCORVADO DE CUCHITO ---
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.position = Vector3(0.0, 0.46, 0.0)
	cuerpo.rotation = Vector3(deg_to_rad(8.0), 0.0, 0.0)
	_rig.add_child(cuerpo)

	_agregar_cilindro(cuerpo, "CamisaBase", 0.23, 0.27, 0.46, Vector3(0.0, 0.24, 0.0), mat_crema)
	_agregar_cilindro(cuerpo, "FranjaRoja1", 0.248, 0.258, 0.09, Vector3(0.0, 0.17, 0.0), mat_rojo)
	_agregar_cilindro(cuerpo, "FranjaRoja2", 0.236, 0.245, 0.09, Vector3(0.0, 0.33, 0.0), mat_rojo)

	_agregar_caja(cuerpo, "SolapaIzq", Vector3(0.13, 0.45, 0.44), Vector3(-0.21, 0.24, -0.02), mat_abrigo)
	_agregar_caja(cuerpo, "SolapaDer", Vector3(0.13, 0.45, 0.44), Vector3(0.21, 0.24, -0.02), mat_abrigo)
	_agregar_caja(cuerpo, "EspaldaCasaca", Vector3(0.46, 0.46, 0.14), Vector3(0.0, 0.24, -0.20), mat_abrigo)

	_agregar_esfera(cuerpo, "Boton1", 0.024, Vector3(-0.17, 0.34, 0.20), mat_oro)
	_agregar_esfera(cuerpo, "Boton2", 0.024, Vector3(0.17, 0.34, 0.20), mat_oro)
	_agregar_esfera(cuerpo, "Boton3", 0.024, Vector3(-0.17, 0.22, 0.21), mat_oro)
	_agregar_esfera(cuerpo, "Boton4", 0.024, Vector3(0.17, 0.22, 0.21), mat_oro)

	_agregar_cilindro(cuerpo, "Cinturon", 0.276, 0.276, 0.08, Vector3(0.0, 0.07, 0.0), mat_cuero)
	_agregar_caja(cuerpo, "Hebilla", Vector3(0.13, 0.11, 0.05), Vector3(0.0, 0.07, 0.26), mat_oro)

	# --- CABEZA EXPRESIVA ---
	var pivote_cabeza := Node3D.new()
	pivote_cabeza.name = "PivoteCabeza"
	pivote_cabeza.position = Vector3(0.0, 0.50, 0.03)
	pivote_cabeza.rotation = Vector3(deg_to_rad(-5.0), 0.0, 0.0)
	cuerpo.add_child(pivote_cabeza)

	_agregar_esfera(pivote_cabeza, "Cabeza", 0.24, Vector3(0.0, 0.20, 0.0), mat_piel)
	_agregar_esfera(pivote_cabeza, "Nariz", 0.062, Vector3(0.0, 0.19, 0.23), mat_nariz)
	_agregar_esfera(pivote_cabeza, "OrejaIzq", 0.05, Vector3(-0.23, 0.19, 0.0), mat_piel)
	_agregar_esfera(pivote_cabeza, "OrejaDer", 0.05, Vector3(0.23, 0.19, 0.0), mat_piel)
	_agregar_cilindro(pivote_cabeza, "AreteOro", 0.032, 0.032, 0.015, Vector3(-0.24, 0.13, 0.01), mat_oro, Vector3(0.0, 0.0, deg_to_rad(90.0)))

	# Patillas blancas pequeñas a los lados (sin bola atrás)
	var patilla_izq := _agregar_esfera(pivote_cabeza, "PatillaIzq", 0.045, Vector3(-0.205, 0.13, 0.05), mat_barba_sombra)
	patilla_izq.scale = Vector3(0.65, 1.25, 0.85)
	var patilla_der := _agregar_esfera(pivote_cabeza, "PatillaDer", 0.045, Vector3(0.205, 0.13, 0.05), mat_barba_sombra)
	patilla_der.scale = Vector3(0.65, 1.25, 0.85)

	# Ojo y parche
	_agregar_esfera(pivote_cabeza, "OjoDerBlanco", 0.038, Vector3(0.085, 0.23, 0.205), mat_ojo_blanco)
	_agregar_esfera(pivote_cabeza, "PupilaDer", 0.02, Vector3(0.088, 0.23, 0.232), mat_negro)
	_agregar_cilindro(pivote_cabeza, "ParcheIzq", 0.052, 0.052, 0.02, Vector3(-0.085, 0.23, 0.215), mat_negro, Vector3(deg_to_rad(85.0), deg_to_rad(-18.0), 0.0))
	_agregar_cilindro(pivote_cabeza, "CintaParche", 0.243, 0.243, 0.022, Vector3(0.0, 0.25, 0.0), mat_negro, Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(-16.0)))

	# Cejas blancas
	_agregar_caja(pivote_cabeza, "CejaIzq", Vector3(0.11, 0.036, 0.045), Vector3(-0.085, 0.285, 0.215), mat_barba, Vector3(0.0, 0.0, deg_to_rad(-12.0)))
	_agregar_caja(pivote_cabeza, "CejaDer", Vector3(0.11, 0.036, 0.045), Vector3(0.085, 0.285, 0.215), mat_barba, Vector3(0.0, 0.0, deg_to_rad(12.0)))

	# Bigote redondeado suave + barba frontal (sin salirse por detrás)
	var bigote_izq := _agregar_esfera(pivote_cabeza, "BigoteIzq", 0.046, Vector3(-0.056, 0.145, 0.218), mat_barba)
	bigote_izq.scale = Vector3(1.55, 0.72, 0.78)
	bigote_izq.rotation = Vector3(0.0, deg_to_rad(14.0), deg_to_rad(-16.0))

	var bigote_der := _agregar_esfera(pivote_cabeza, "BigoteDer", 0.046, Vector3(0.056, 0.145, 0.218), mat_barba)
	bigote_der.scale = Vector3(1.55, 0.72, 0.78)
	bigote_der.rotation = Vector3(0.0, deg_to_rad(-14.0), deg_to_rad(16.0))

	var barba_sup := _agregar_esfera(pivote_cabeza, "BarbaSuperior", 0.165, Vector3(0.0, 0.075, 0.105), mat_barba)
	barba_sup.scale = Vector3(1.05, 0.92, 0.82)

	_agregar_cilindro(pivote_cabeza, "BarbaLarga", 0.145, 0.045, 0.26, Vector3(0.0, -0.055, 0.135), mat_barba_sombra, Vector3(deg_to_rad(-14.0), 0.0, 0.0))

	# Pañoleta roja pirata + nudo y cintas cayendo pegadas atrás
	_agregar_esfera(pivote_cabeza, "Panoleta", 0.244, Vector3(0.0, 0.245, -0.005), mat_rojo)
	_agregar_esfera(pivote_cabeza, "NudoPanoleta", 0.032, Vector3(0.0, 0.215, -0.242), mat_rojo)
	_agregar_caja(pivote_cabeza, "ColaPanoletaIzq", Vector3(0.030, 0.105, 0.012), Vector3(-0.020, 0.162, -0.244), mat_rojo, Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-14.0)))
	_agregar_caja(pivote_cabeza, "ColaPanoletaDer", Vector3(0.030, 0.105, 0.012), Vector3(0.020, 0.162, -0.244), mat_rojo, Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(14.0)))

	# --- SOMBRERO TRICORNIO DE CAPITÁN PIRATA ---
	if con_sombrero_capitan:
		var sombrero := Node3D.new()
		sombrero.name = "SombreroCapitan"
		sombrero.position = Vector3(0.0, 0.355, -0.01)
		sombrero.rotation = Vector3(deg_to_rad(-6.0), 0.0, deg_to_rad(-2.0))
		pivote_cabeza.add_child(sombrero)

		_agregar_cilindro(sombrero, "BaseAla", 0.24, 0.26, 0.025, Vector3(0.0, 0.01, 0.01), mat_sombrero)
		_agregar_cilindro(sombrero, "CopaSombrero", 0.165, 0.215, 0.15, Vector3(0.0, 0.085, 0.0), mat_sombrero)
		var tope_copa := _agregar_esfera(sombrero, "TopeCopa", 0.165, Vector3(0.0, 0.155, 0.0), mat_sombrero)
		tope_copa.scale = Vector3(1.0, 0.32, 1.0)

		# Visera frontal levantada con pico central
		_agregar_caja(sombrero, "AlaFrenteCentro", Vector3(0.22, 0.16, 0.032), Vector3(0.0, 0.085, 0.215), mat_sombrero, Vector3(deg_to_rad(14.0), 0.0, 0.0))
		_agregar_caja(sombrero, "PicoFrente", Vector3(0.135, 0.135, 0.032), Vector3(0.0, 0.125, 0.225), mat_sombrero, Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(45.0)))
		_agregar_caja(sombrero, "BordeOroPicoIzq", Vector3(0.145, 0.016, 0.038), Vector3(-0.048, 0.172, 0.236), mat_oro, Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(45.0)))
		_agregar_caja(sombrero, "BordeOroPicoDer", Vector3(0.145, 0.016, 0.038), Vector3(0.048, 0.172, 0.236), mat_oro, Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(-45.0)))

		# Alas laterales dobladas
		_agregar_caja(sombrero, "AlaFrenteIzq", Vector3(0.21, 0.135, 0.030), Vector3(-0.165, 0.072, 0.165), mat_sombrero, Vector3(deg_to_rad(12.0), deg_to_rad(-34.0), deg_to_rad(14.0)))
		_agregar_caja(sombrero, "BordeOroAlaIzq", Vector3(0.215, 0.015, 0.036), Vector3(-0.180, 0.138, 0.178), mat_oro, Vector3(deg_to_rad(12.0), deg_to_rad(-34.0), deg_to_rad(14.0)))

		_agregar_caja(sombrero, "AlaFrenteDer", Vector3(0.21, 0.135, 0.030), Vector3(0.165, 0.072, 0.165), mat_sombrero, Vector3(deg_to_rad(12.0), deg_to_rad(34.0), deg_to_rad(-14.0)))
		_agregar_caja(sombrero, "BordeOroAlaDer", Vector3(0.215, 0.015, 0.036), Vector3(0.180, 0.138, 0.178), mat_oro, Vector3(deg_to_rad(12.0), deg_to_rad(34.0), deg_to_rad(-14.0)))

		# Solapas traseras dobladas
		_agregar_caja(sombrero, "SolapaAtrasIzq", Vector3(0.22, 0.125, 0.030), Vector3(-0.175, 0.068, -0.105), mat_sombrero, Vector3(deg_to_rad(-12.0), deg_to_rad(46.0), deg_to_rad(-12.0)))
		_agregar_caja(sombrero, "BordeOroAtrasIzq", Vector3(0.225, 0.014, 0.035), Vector3(-0.188, 0.129, -0.118), mat_oro, Vector3(deg_to_rad(-12.0), deg_to_rad(46.0), deg_to_rad(-12.0)))

		_agregar_caja(sombrero, "SolapaAtrasDer", Vector3(0.22, 0.125, 0.030), Vector3(0.175, 0.068, -0.105), mat_sombrero, Vector3(deg_to_rad(-12.0), deg_to_rad(-46.0), deg_to_rad(12.0)))
		_agregar_caja(sombrero, "BordeOroAtrasDer", Vector3(0.225, 0.014, 0.035), Vector3(0.188, 0.129, -0.118), mat_oro, Vector3(deg_to_rad(-12.0), deg_to_rad(-46.0), deg_to_rad(12.0)))

		# Calavera con huesos cruzados
		_agregar_esfera(sombrero, "CalaveraCraneo", 0.034, Vector3(0.0, 0.105, 0.240), mat_crema)
		_agregar_caja(sombrero, "CalaveraMandibula", Vector3(0.036, 0.022, 0.024), Vector3(0.0, 0.077, 0.240), mat_crema)
		_agregar_esfera(sombrero, "CalaveraOjoIzq", 0.0085, Vector3(-0.012, 0.105, 0.270), mat_negro)
		_agregar_esfera(sombrero, "CalaveraOjoDer", 0.0085, Vector3(0.012, 0.105, 0.270), mat_negro)
		_agregar_cilindro(sombrero, "HuesoCruzado1", 0.007, 0.007, 0.105, Vector3(0.0, 0.052, 0.234), mat_crema, Vector3(0.0, 0.0, deg_to_rad(58.0)))
		_agregar_cilindro(sombrero, "HuesoCruzado2", 0.007, 0.007, 0.105, Vector3(0.0, 0.052, 0.236), mat_crema, Vector3(0.0, 0.0, deg_to_rad(-58.0)))

		# Pluma curva estilizada metida detrás del ala izquierda
		var pluma_base := _agregar_esfera(sombrero, "PlumaBase", 0.055, Vector3(-0.175, 0.135, 0.01), mat_rojo)
		pluma_base.scale = Vector3(0.25, 1.35, 0.65)
		pluma_base.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-15.0), deg_to_rad(18.0))

		var pluma_media := _agregar_esfera(sombrero, "PlumaMedia", 0.050, Vector3(-0.198, 0.195, -0.035), mat_rojo)
		pluma_media.scale = Vector3(0.22, 1.30, 0.58)
		pluma_media.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(-15.0), deg_to_rad(28.0))

		var pluma_punta := _agregar_esfera(sombrero, "PlumaPunta", 0.036, Vector3(-0.215, 0.235, -0.082), mat_crema)
		pluma_punta.scale = Vector3(0.20, 1.15, 0.50)
		pluma_punta.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-15.0), deg_to_rad(36.0))

	# --- BRAZOS ARTICULADOS ---
	var pivote_brazo_izq := Node3D.new()
	pivote_brazo_izq.name = "PivoteBrazoIzq"
	pivote_brazo_izq.position = Vector3(-0.31, 0.39, 0.0)
	cuerpo.add_child(pivote_brazo_izq)

	_agregar_esfera(pivote_brazo_izq, "HombroIzq", 0.075, Vector3.ZERO, mat_abrigo)
	_agregar_cilindro(pivote_brazo_izq, "MangaIzq", 0.068, 0.075, 0.17, Vector3(-0.02, -0.09, 0.0), mat_crema, Vector3(0.0, 0.0, deg_to_rad(-10.0)))
	_agregar_cilindro(pivote_brazo_izq, "AntebrazoIzq", 0.058, 0.052, 0.17, Vector3(-0.04, -0.23, 0.02), mat_piel, Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(-8.0)))
	_agregar_esfera(pivote_brazo_izq, "ManoIzq", 0.062, Vector3(-0.05, -0.33, 0.04), mat_piel)

	var pivote_brazo_der := Node3D.new()
	pivote_brazo_der.name = "PivoteBrazoDer"
	pivote_brazo_der.position = Vector3(0.31, 0.39, 0.0)
	cuerpo.add_child(pivote_brazo_der)

	_agregar_esfera(pivote_brazo_der, "HombroDer", 0.075, Vector3.ZERO, mat_abrigo)
	_agregar_cilindro(pivote_brazo_der, "MangaDer", 0.068, 0.075, 0.17, Vector3(0.02, -0.09, 0.0), mat_crema, Vector3(0.0, 0.0, deg_to_rad(10.0)))
	_agregar_cilindro(pivote_brazo_der, "AntebrazoDer", 0.058, 0.052, 0.17, Vector3(0.04, -0.23, 0.02), mat_piel, Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(8.0)))
	_agregar_esfera(pivote_brazo_der, "ManoDer", 0.062, Vector3(0.05, -0.33, 0.04), mat_piel)

	_mano_derecha_socket = Marker3D.new()
	_mano_derecha_socket.name = "ManoDerechaSocket"
	_mano_derecha_socket.position = Vector3(0.05, -0.34, 0.08)
	pivote_brazo_der.add_child(_mano_derecha_socket)

	_construir_animaciones()
	if Engine.is_editor_hint():
		_aplicar_vista_previa_editor()


func _construir_animaciones() -> void:
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayerPirata"
	add_child(_anim_player)

	var lib := AnimationLibrary.new()

	# 1. IDLE
	var anim_idle := Animation.new()
	anim_idle.length = 1.6
	anim_idle.loop_mode = Animation.LOOP_LINEAR

	_agregar_pista(anim_idle, "RigPirata/Cuerpo:position", [
		[0.0, Vector3(0.0, 0.46, 0.0)],
		[0.8, Vector3(0.0, 0.485, 0.0)],
		[1.6, Vector3(0.0, 0.46, 0.0)]
	])
	_agregar_pista(anim_idle, "RigPirata/Cuerpo:rotation", [
		[0.0, Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-1.5))],
		[0.8, Vector3(deg_to_rad(10.0), 0.0, deg_to_rad(1.5))],
		[1.6, Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-1.5))]
	])
	_agregar_pista(anim_idle, "RigPirata/Cuerpo/PivoteCabeza:rotation", [
		[0.0, Vector3(deg_to_rad(-5.0), deg_to_rad(-4.0), 0.0)],
		[0.8, Vector3(deg_to_rad(-2.0), deg_to_rad(4.0), 0.0)],
		[1.6, Vector3(deg_to_rad(-5.0), deg_to_rad(-4.0), 0.0)]
	])
	_agregar_pista(anim_idle, "RigPirata/Cuerpo/PivoteBrazoIzq:rotation", [
		[0.0, Vector3(0.0, 0.0, deg_to_rad(-4.0))],
		[0.8, Vector3(0.0, 0.0, deg_to_rad(-9.0))],
		[1.6, Vector3(0.0, 0.0, deg_to_rad(-4.0))]
	])
	_agregar_pista(anim_idle, "RigPirata/Cuerpo/PivoteBrazoDer:rotation", [
		[0.0, Vector3(0.0, 0.0, deg_to_rad(4.0))],
		[0.8, Vector3(0.0, 0.0, deg_to_rad(9.0))],
		[1.6, Vector3(0.0, 0.0, deg_to_rad(4.0))]
	])
	lib.add_animation(&"idle", anim_idle)

	# 2. CAMINAR
	var anim_caminar := Animation.new()
	anim_caminar.length = 0.56
	anim_caminar.loop_mode = Animation.LOOP_LINEAR

	_agregar_pista(anim_caminar, "RigPirata/Cuerpo:position", [
		[0.0, Vector3(0.0, 0.45, 0.0)],
		[0.14, Vector3(0.0, 0.51, 0.0)],
		[0.28, Vector3(0.0, 0.44, 0.0)],
		[0.42, Vector3(0.0, 0.49, 0.0)],
		[0.56, Vector3(0.0, 0.45, 0.0)]
	])
	_agregar_pista(anim_caminar, "RigPirata/Cuerpo:rotation", [
		[0.0, Vector3(deg_to_rad(11.0), deg_to_rad(-5.0), deg_to_rad(-5.0))],
		[0.28, Vector3(deg_to_rad(11.0), deg_to_rad(5.0), deg_to_rad(6.0))],
		[0.56, Vector3(deg_to_rad(11.0), deg_to_rad(-5.0), deg_to_rad(-5.0))]
	])
	_agregar_pista(anim_caminar, "RigPirata/PivotePiernaIzq:rotation", [
		[0.0, Vector3(deg_to_rad(34.0), 0.0, 0.0)],
		[0.28, Vector3(deg_to_rad(-30.0), 0.0, 0.0)],
		[0.56, Vector3(deg_to_rad(34.0), 0.0, 0.0)]
	])
	_agregar_pista(anim_caminar, "RigPirata/PivotePiernaDer:rotation", [
		[0.0, Vector3(deg_to_rad(-34.0), 0.0, 0.0)],
		[0.28, Vector3(deg_to_rad(36.0), 0.0, 0.0)],
		[0.56, Vector3(deg_to_rad(-34.0), 0.0, 0.0)]
	])
	_agregar_pista(anim_caminar, "RigPirata/Cuerpo/PivoteBrazoIzq:rotation", [
		[0.0, Vector3(deg_to_rad(-32.0), 0.0, deg_to_rad(-6.0))],
		[0.28, Vector3(deg_to_rad(32.0), 0.0, deg_to_rad(-6.0))],
		[0.56, Vector3(deg_to_rad(-32.0), 0.0, deg_to_rad(-6.0))]
	])
	_agregar_pista(anim_caminar, "RigPirata/Cuerpo/PivoteBrazoDer:rotation", [
		[0.0, Vector3(deg_to_rad(32.0), 0.0, deg_to_rad(6.0))],
		[0.28, Vector3(deg_to_rad(-32.0), 0.0, deg_to_rad(6.0))],
		[0.56, Vector3(deg_to_rad(32.0), 0.0, deg_to_rad(6.0))]
	])
	lib.add_animation(&"caminar", anim_caminar)

	# 3. LANZAR
	var anim_lanzar := Animation.new()
	anim_lanzar.length = 0.36
	anim_lanzar.loop_mode = Animation.LOOP_NONE

	_agregar_pista(anim_lanzar, "RigPirata/Cuerpo:rotation", [
		[0.0, Vector3(deg_to_rad(8.0), 0.0, 0.0)],
		[0.10, Vector3(deg_to_rad(-8.0), deg_to_rad(-18.0), 0.0)],
		[0.22, Vector3(deg_to_rad(18.0), deg_to_rad(14.0), 0.0)],
		[0.36, Vector3(deg_to_rad(8.0), 0.0, 0.0)]
	])
	_agregar_pista(anim_lanzar, "RigPirata/Cuerpo/PivoteBrazoDer:rotation", [
		[0.0, Vector3(0.0, 0.0, deg_to_rad(5.0))],
		[0.10, Vector3(deg_to_rad(65.0), 0.0, deg_to_rad(18.0))],
		[0.22, Vector3(deg_to_rad(-88.0), 0.0, deg_to_rad(-10.0))],
		[0.36, Vector3(0.0, 0.0, deg_to_rad(5.0))]
	])
	_agregar_pista(anim_lanzar, "RigPirata/Cuerpo/PivoteBrazoIzq:rotation", [
		[0.0, Vector3(0.0, 0.0, deg_to_rad(-5.0))],
		[0.10, Vector3(deg_to_rad(-45.0), 0.0, deg_to_rad(-15.0))],
		[0.22, Vector3(deg_to_rad(35.0), 0.0, deg_to_rad(-8.0))],
		[0.36, Vector3(0.0, 0.0, deg_to_rad(-5.0))]
	])
	lib.add_animation(&"lanzar", anim_lanzar)

	_anim_player.add_animation_library(&"", lib)
	_anim_player.animation_finished.connect(_on_animacion_terminada)


func _on_animacion_terminada(nombre_anim: StringName) -> void:
	if nombre_anim == &"lanzar":
		_reproduciendo_accion = false
		if is_instance_valid(_anim_player):
			if Engine.is_editor_hint() and vista_previa_editor != "lanzar":
				_aplicar_vista_previa_editor()
			elif not Engine.is_editor_hint():
				_anim_player.play(&"idle", 0.12)


func _agregar_pista(anim: Animation, ruta: String, claves: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath(ruta))
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	for par in claves:
		anim.track_insert_key(idx, float(par[0]), par[1])


func _crear_material(color: Color, rugosidad: float = 0.7, metalico: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rugosidad
	mat.metallic = metalico
	return mat


func _agregar_caja(padre: Node3D, nombre: String, tamano: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var malla := BoxMesh.new()
	malla.size = tamano
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	padre.add_child(mi)
	return mi


func _agregar_esfera(padre: Node3D, nombre: String, radio: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	padre.add_child(mi)
	return mi


func _agregar_cilindro(padre: Node3D, nombre: String, radio_sup: float, radio_inf: float, altura: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var malla := CylinderMesh.new()
	malla.top_radius = radio_sup
	malla.bottom_radius = radio_inf
	malla.height = altura
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	padre.add_child(mi)
	return mi
