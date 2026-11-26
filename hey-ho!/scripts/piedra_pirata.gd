@tool
extends Node3D
class_name PiedraPirata

@export_tool_button("Generar / Actualizar Piedra") var btn_generar := _generar_malla_piedra


func _ready() -> void:
	if get_node_or_null("MallaPiedra") == null:
		_generar_malla_piedra()


func _generar_malla_piedra() -> void:
	var anterior := get_node_or_null("MallaPiedra")
	if anterior != null:
		anterior.free()

	var t := (1.0 + sqrt(5.0)) * 0.5
	var base_verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)
	]
	for i in base_verts.size():
		base_verts[i] = base_verts[i].normalized()

	var base_faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
	]

	var verts: Array[Vector3] = base_verts.duplicate()
	var cache_medios := {}

	var obtener_medio := func(i1: int, i2: int) -> int:
		var clave := "%d_%d" % [mini(i1, i2), maxi(i1, i2)]
		if cache_medios.has(clave):
			return cache_medios[clave]
		var medio := ((verts[i1] + verts[i2]) * 0.5).normalized()
		var idx := verts.size()
		verts.append(medio)
		cache_medios[clave] = idx
		return idx

	var caras := []
	for f in base_faces:
		var a: int = f[0]
		var b: int = f[1]
		var c: int = f[2]
		var ab: int = obtener_medio.call(a, b)
		var bc: int = obtener_medio.call(b, c)
		var ca: int = obtener_medio.call(c, a)
		caras.append([a, ab, ca])
		caras.append([b, bc, ab])
		caras.append([c, ca, bc])
		caras.append([ab, bc, ca])

	for i in verts.size():
		var v := verts[i]
		var disp := (
			1.0
			+ 0.14 * sin(2.3 * v.x + 1.7 * v.y)
			+ 0.11 * cos(2.9 * v.z - 1.5 * v.x)
			+ 0.08 * sin(3.4 * v.y + 2.1 * v.z)
		)
		var esc_y := 0.86 if v.y < 0.0 else 0.96
		verts[i] = Vector3(v.x * 1.12, v.y * esc_y, v.z * 1.04) * disp * 0.19

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for idx in caras.size():
		var c_idx = caras[idx]
		var p0: Vector3 = verts[c_idx[0]]
		var p1: Vector3 = verts[c_idx[1]]
		var p2: Vector3 = verts[c_idx[2]]

		var normal := (p2 - p0).cross(p1 - p0).normalized()
		var centro_cara := (p0 + p1 + p2) / 3.0
		if normal.dot(centro_cara) < 0.0:
			var tmp := p1
			p1 = p2
			p2 = tmp
			normal = -normal

		var tono := clampf(0.49 + normal.y * 0.09 + float((idx * 37) % 11 - 5) * 0.012, 0.30, 0.72)
		var color_cara := Color(tono, tono + 0.03, tono + 0.07, 1.0)

		for p in [p0, p1, p2]:
			st.set_normal(normal)
			st.set_color(color_cara)
			st.add_vertex(p)

	var malla_inst := MeshInstance3D.new()
	malla_inst.name = "MallaPiedra"
	malla_inst.mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.88
	malla_inst.material_override = mat

	add_child(malla_inst)
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		malla_inst.owner = get_tree().edited_scene_root
