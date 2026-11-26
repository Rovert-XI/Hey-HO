extends SceneTree
var fallos := 0
var pruebas := 0
func check(c: bool, m: String) -> void:
	pruebas += 1
	if c:
		print("  ok   ", m)
	else:
		fallos += 1
		print("  FALLA ", m)
func _init() -> void:
	_correr()
func _correr() -> void:
	var esc := Node3D.new()
	var s := SistemaSol.new()
	s.name = "SistemaSol"
	var ciclo := CicloDia.new()
	ciclo.name = "CicloDia"
	s.add_child(ciclo)
	var luz := DirectionalLight3D.new()
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	s.sol = luz
	s.entorno = we
	var sg := SistemaSogas.new()
	sg.modo_prueba = false
	sg.sistema_sol = s
	esc.add_child(luz); esc.add_child(we); esc.add_child(s); esc.add_child(sg)
	root.add_child(esc)
	for i in 3:
		await process_frame
	var cambios := []
	var inestables := []
	var perdidos := [0]
	sg.soga_cambio.connect(func(p, i, r): cambios.append([p, i, r]))
	sg.plataforma_desestabilizada.connect(func(p, d): inestables.append([p, d]))
	sg.nivel_perdido.connect(func(): perdidos[0] += 1)

	print("[1] cargar(datos)")
	sg.cargar({"lavadora": [20.0, 0.0], "tendedero": [100.0, 80.0], "despacho": [100.0, 100.0]})
	check(cambios.size() == 6, "avisa las 6 sogas al HUD (soga_cambio x6): %d" % cambios.size())
	check(sg.sogas["lavadora"][0] == 20.0 and sg.sogas["lavadora"][1] == 0.0, "números cargados")
	check(sg.visuales["lavadora1"].visible == false and sg.visuales["lavadora0"].visible == true, "repinta: la soga en 0 desaparece, la de 20 se ve")
	var col: Color = (sg.visuales["lavadora0"].material_override as StandardMaterial3D).albedo_color
	check(col.r > SistemaSogas.MADERA.r + 0.05 and col.g < SistemaSogas.MADERA.g - 0.02, "la soga de 20 se ve rojiza")
	check(inestables.has(["lavadora", true]), "la lavadora queda inestable")
	check(is_equal_approx(s.peligro, SistemaSol.peligro_soga(0.0)), "el sol recibe el peligro máximo (soga en 0)")
	check(perdidos[0] == 0, "con una soga en 0 NO se pierde el nivel")

	print("[2] datos() es una copia")
	var copia := sg.datos()
	copia["lavadora"][0] = 99.0
	check(sg.sogas["lavadora"][0] == 20.0, "cambiar la copia no toca las sogas")

	print("[3] multiplicador de desgaste")
	sg.cargar({})
	sg.registrar_lanzamiento("izquierda", -1.0)
	check(sg.sogas["lavadora"][0] == 98.0, "×1: -2")
	sg.multiplicador_desgaste = 10.0
	sg.registrar_lanzamiento("derecha", 7.5)
	check(sg.sogas["tendedero"][1] == 80.0, "×10: -20")
	sg.registrar_pedido(-0.4)
	check(sg.sogas["despacho"][0] == 60.0, "×10 en el despacho: -40")
	sg.multiplicador_desgaste = 1.0

	print("[4] reparación pública")
	sg.cargar({"lavadora": [0.0, 100.0], "tendedero": [100.0, 100.0], "despacho": [100.0, 100.0]})
	check(sg.plataforma_mas_danada() == "lavadora", "plataforma_mas_danada = lavadora")
	for i in 150:                       # 2,5 s manteniendo
		sg.mantener_reparacion("lavadora", 1.0 / 60.0)
	check(sg.sogas["lavadora"][0] == 50.0, "tras 2 s sube a 50 (cuesta 20)")
	for i in 240:                       # sigue manteniendo 4 s más
		sg.mantener_reparacion("lavadora", 1.0 / 60.0)
	check(sg.sogas["lavadora"][0] == 50.0, "si no suelta, no se repite sola")
	sg.soltar_reparacion()
	for i in 130:
		sg.mantener_reparacion("lavadora", 1.0 / 60.0)
	check(sg.sogas["lavadora"][0] == 100.0, "al soltar y volver a mantener, sube a 100")
	check(inestables.has(["lavadora", false]), "la plataforma deja de ser inestable")

	print("[5] derrota y reiniciar")
	sg.cargar({})
	sg._poner("tendedero", 0, 0.0)
	sg._poner("tendedero", 1, 0.0)
	check(perdidos[0] == 0, "las dos en 0 todavía no pierden: tienen 30 s para repararse")
	sg._process(SistemaSogas.T_ROTURA + 0.1)   # pasan los 30 s sin repararlas: se rompen las dos
	check(perdidos[0] == 1 and sg.perdido, "las dos sogas de una plataforma rotas: nivel_perdido (una sola vez)")
	sg.registrar_lanzamiento("derecha", 7.5)
	check(perdidos[0] == 1, "ya perdido: no se desgasta mas ni se avisa dos veces")
	sg.reiniciar()
	check(not sg.perdido and sg.sogas["tendedero"][0] == 100.0 and s.apagado == 1.0 and s.peligro == 0.0, "reiniciar deja sogas, luz y peligro como nuevos")
	print("== %d pruebas, %d fallos ==" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)
