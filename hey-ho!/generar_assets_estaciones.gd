@tool
extends EditorScript


func _run() -> void:
	var carpeta_salida := "res://Assets/Estaciones"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta_salida))

	var lavadora := _construir_lavadora()
	_exportar_glb(lavadora, carpeta_salida + "/lavadora.glb")
	lavadora.free()

	var tendedero := _construir_tendedero()
	_exportar_glb(tendedero, carpeta_salida + "/tendedero.glb")
	tendedero.free()

	EditorInterface.get_resource_filesystem().scan()
	print("Modelos 3D regenerados con mallas en: ", carpeta_salida)


func _exportar_glb(raiz: Node3D, ruta_destino: String) -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var err := gltf.append_from_scene(raiz, state)
	if err != OK:
		push_error("Error al procesar escena para GLB: " + str(err))
		return

	err = gltf.write_to_filesystem(state, ruta_destino)
	if err != OK:
		push_error("Error al guardar archivo GLB en " + ruta_destino + ": " + str(err))


# ------------------------------------------------------------------ LAVADORA NÁUTICA
func _construir_lavadora() -> Node3D:
	var root := Node3D.new()
	root.name = "LavadoraPirata"

	var mat_cuerpo := _material(Color("E8DEC8"), 0.05, 0.65)
	var mat_madera := _material(Color("6E472B"), 0.0, 0.8)
	var mat_bronce := _material(Color("C8963E"), 0.75, 0.35)
	var mat_interior := _material(Color("1E2733"), 0.2, 0.5)
	var mat_vidrio := _material(Color(0.55, 0.82, 0.92, 0.45), 0.1, 0.15, true)
	var mat_goma := _material(Color("262626"), 0.0, 0.9)

	for x in [-0.38, 0.38]:
		for z in [-0.35, 0.35]:
			_agregar_cilindro(root, "Pata", 0.07, 0.07, 0.08, Vector3(x, 0.04, z), Vector3.ZERO, mat_goma)

	_agregar_caja(root, "Cuerpo", Vector3(1.04, 1.02, 0.94), Vector3(0.0, 0.59, 0.0), mat_cuerpo)
	_agregar_caja(root, "TapaSuperior", Vector3(1.10, 0.08, 1.00), Vector3(0.0, 1.14, 0.0), mat_madera)
	_agregar_caja(root, "ZocaloInferior", Vector3(1.08, 0.08, 0.98), Vector3(0.0, 0.12, 0.0), mat_madera)
	_agregar_caja(root, "BandaIzq", Vector3(0.04, 0.96, 0.96), Vector3(-0.52, 0.60, 0.0), mat_madera)
	_agregar_caja(root, "BandaDer", Vector3(0.04, 0.96, 0.96), Vector3(0.52, 0.60, 0.0), mat_madera)

	_agregar_caja(root, "PanelControl", Vector3(0.96, 0.18, 0.04), Vector3(0.0, 0.99, 0.48), mat_madera)
	_agregar_caja(root, "CajonJabon", Vector3(0.32, 0.11, 0.03), Vector3(-0.26, 0.99, 0.50), mat_cuerpo)
	_agregar_cilindro(root, "Perilla1", 0.045, 0.045, 0.04, Vector3(0.14, 0.99, 0.51), Vector3(90, 0, 0), mat_bronce)
	_agregar_cilindro(root, "Perilla2", 0.045, 0.045, 0.04, Vector3(0.28, 0.99, 0.51), Vector3(90, 0, 0), mat_bronce)
	_agregar_cilindro(root, "BotonInicio", 0.03, 0.03, 0.04, Vector3(0.40, 0.99, 0.51), Vector3(90, 0, 0), mat_bronce)

	var centro_puerta := Vector3(0.0, 0.56, 0.48)
	_agregar_cilindro(root, "TamborFondo", 0.28, 0.28, 0.04, centro_puerta, Vector3(90, 0, 0), mat_interior)
	_agregar_toro(root, "MarcoBronce", 0.25, 0.33, centro_puerta + Vector3(0, 0, 0.02), Vector3(90, 0, 0), mat_bronce)
	_agregar_cilindro(root, "VidrioEscotilla", 0.26, 0.26, 0.02, centro_puerta + Vector3(0, 0, 0.025), Vector3(90, 0, 0), mat_vidrio)
	_agregar_caja(root, "Bisagra", Vector3(0.05, 0.14, 0.05), centro_puerta + Vector3(-0.31, 0.0, 0.02), mat_bronce)
	_agregar_caja(root, "Manija", Vector3(0.04, 0.12, 0.05), centro_puerta + Vector3(0.30, 0.0, 0.03), mat_bronce)

	return root


# ------------------------------------------------------------------ TENDEDERO PIRATA
func _construir_tendedero() -> Node3D:
	var root := Node3D.new()
	root.name = "TendederoPirata"

	var mat_madera := _material(Color("6E472B"), 0.0, 0.82)
	var mat_madera_clara := _material(Color("8C5E3C"), 0.0, 0.78)
	var mat_cuerda := _material(Color("CBB382"), 0.0, 0.92)
	var mat_hierro := _material(Color("3A3F45"), 0.7, 0.45)

	for lado in [-1.35, 1.35]:
		_agregar_cilindro(root, "Poste", 0.075, 0.09, 1.25, Vector3(lado, 0.275, 0.0), Vector3.ZERO, mat_madera)
		_agregar_caja(root, "BasePoste", Vector3(0.34, 0.08, 0.34), Vector3(lado, -0.31, 0.0), mat_madera_clara)
		_agregar_toro(root, "AmarreSoga", 0.07, 0.10, Vector3(lado, 0.24, 0.0), Vector3.ZERO, mat_cuerda)
		_agregar_cilindro(root, "TopePoste", 0.095, 0.095, 0.06, Vector3(lado, 0.91, 0.0), Vector3.ZERO, mat_hierro)

	_agregar_cilindro(root, "CuerdaPrincipal", 0.022, 0.022, 2.70, Vector3(0.0, 0.24, 0.0), Vector3(0, 0, 90), mat_cuerda)

	for i in [-1.0, 0.0, 1.0]:
		_agregar_toro(root, "Gancho", 0.032, 0.052, Vector3(i, 0.21, 0.0), Vector3.ZERO, mat_hierro)
		_agregar_caja(root, "PinzaMadera", Vector3(0.04, 0.09, 0.05), Vector3(i, 0.25, 0.0), mat_madera_clara)

	return root


# ------------------------------------------------------------------ HELPERS DE MALLA
func _material(color: Color, metalico: float, rugosidad: float, transparente: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metalico
	mat.roughness = rugosidad
	if transparente:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _agregar_caja(padre: Node3D, nombre: String, tamano: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var mesh := BoxMesh.new()
	mesh.size = tamano
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	padre.add_child(mi)
	mi.owner = padre


func _agregar_cilindro(padre: Node3D, nombre: String, r_top: float, r_bot: float, alto: float, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = alto
	mesh.radial_segments = 20
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	padre.add_child(mi)
	mi.owner = padre


func _agregar_toro(padre: Node3D, nombre: String, r_int: float, r_ext: float, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	var mesh := TorusMesh.new()
	mesh.inner_radius = r_int
	mesh.outer_radius = r_ext
	mesh.rings = 24
	mesh.ring_segments = 12
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	padre.add_child(mi)
	mi.owner = padre
