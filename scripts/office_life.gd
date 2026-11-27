class_name OfficeLife
extends Node3D
## Vida de oficina (port de ZN/Zplan/Zup del original) + NPC del piso 2 + espías.

const GX := -12.0
const GZ := -3.0
const GS := .3
const GW := 100
const GH := 80
const OX := 40.0

var main: Node3D
var nav: AStarGrid2D        # máscara para NPC (ZM)
var nav2: AStarGrid2D       # piso 2
var navp: AStarGrid2D       # jugador (ZB): todo lo caminable del piso 1
var ZN: Array = []
var ZC: Array = []
var spots := {}
var left := false
var N2: Array = []
var game_tex: CanvasTex
var spies: Array = []
var spy_caught := 0
var spy_fails := 0
var spy_log: Array = []


func setup(m: Node3D) -> void:
	main = m
	add_to_group("office")
	_build_nav()
	for k in Data.ZS:
		spots[k] = []
		for p in Data.ZS[k]:
			spots[k].append({"x": p[0], "z": p[1], "yaw": p[2], "sy": p[3] if p.size() > 3 else 0.0, "app": p[4] if p.size() > 4 else null, "o": null})
	for i in Data.ZD.size():
		var d: Array = Data.ZD[i]
		var r := Rig.create(Color(d[4]), Color(d[5]), Color(d[6]), d[0])
		add_child(r)
		r.visible = false
		var home = null
		if d[9] == "s":
			var sp := _spot_free(d[2], d[3])
			home = {"x": sp.x, "z": sp.y, "yaw": PI, "sy": 0.0, "app": null, "o": null}
		elif d[9] != "c":
			home = {"x": d[2], "z": d[3], "yaw": PI, "sy": .54, "app": [d[2], d[3] + .95], "o": null}
		ZN.append({"name": d[0], "dept": d[1], "r": r, "loc": d[7], "tips": d[8], "home": home, "boss": d[9] == "b", "clean": d[9] == "c", "k": i * 1.7, "sp": 1.2 + randf() * .3})
	_floor2()
	Game.day_started.connect(reset)
	Game.pre_finish.append(_spy_finish)
	Game.spy_ok = func(need: int) -> bool: return need <= 0 or spy_caught >= mini(need, spies.size())


# ================= navegación =================
func _build_nav() -> void:
	navp = AStarGrid2D.new()
	navp.region = Rect2i(0, 0, GW, GH)
	navp.cell_size = Vector2(GS, GS)
	navp.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navp.update()
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, GW, GH)
	nav.cell_size = Vector2(GS, GS)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for j in GH:
		for i in GW:
			var x := GX + (i + .5) * GS
			var z := GZ + (j + .5) * GS
			var ok := true
			for o in [Vector2.ZERO, Vector2(.2, 0), Vector2(-.2, 0), Vector2(0, .2), Vector2(0, -.2)]:
				if not main.free_at(x + o.x, z + o.y): ok = false; break
			var allowed := ok and not (x > 8.1 and z < 3.4) and x > -4.1 and not (z < 3.1 and x < 4.2)
			nav.set_point_solid(Vector2i(i, j), not allowed)
			navp.set_point_solid(Vector2i(i, j), not ok)
	nav2 = AStarGrid2D.new()
	nav2.region = Rect2i(0, 0, 54, 62)
	nav2.cell_size = Vector2(.4, .4)
	nav2.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav2.update()
	for j in 62:
		for i in 54:
			var x := OX - 4.2 + (i + .5) * .4
			var z := -3.0 + (j + .5) * .4
			var ok := true
			for o in [Vector2.ZERO, Vector2(.18, 0), Vector2(-.18, 0), Vector2(0, .18), Vector2(0, -.18)]:
				if not main.free_at(x + o.x, z + o.y): ok = false; break
			nav2.set_point_solid(Vector2i(i, j), not ok)


func _cell(g: AStarGrid2D, x: float, z: float, ox: float, oz: float, s: float) -> Vector2i:
	return Vector2i(int(floor((x - ox) / s)), int(floor((z - oz) / s)))


func _snap(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	if g.is_in_boundsv(c) and not g.is_point_solid(c): return c
	for r in range(1, 14):
		for a in range(-r, r + 1):
			for b in range(-r, r + 1):
				if maxi(absi(a), absi(b)) != r: continue
				var q := c + Vector2i(a, b)
				if g.is_in_boundsv(q) and not g.is_point_solid(q): return q
	return c


func _los(g: AStarGrid2D, a: Vector2, b: Vector2, ox: float, oz: float, s: float) -> bool:
	var n := int(ceil(a.distance_to(b) / .12))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		var c := _cell(g, p.x, p.y, ox, oz, s)
		if not g.is_in_boundsv(c) or g.is_point_solid(c): return false
	return true


func path(from: Vector2, to: Vector2, f2 := false, player := false) -> Array:
	var g := nav2 if f2 else (navp if player else nav)
	var ox := OX - 4.2 if f2 else GX
	var oz := GZ
	var s := .4 if f2 else GS
	var a := _snap(g, _cell(g, from.x, from.y, ox, oz, s))
	var b := _snap(g, _cell(g, to.x, to.y, ox, oz, s))
	var pts: PackedVector2Array = g.get_point_path(a, b)
	if pts.is_empty(): return [to]
	var raw: Array = []
	for p in pts: raw.append(Vector2(ox, oz) + p + Vector2(s / 2, s / 2))
	var out: Array = []
	var cur: Vector2 = raw[0]
	var k := 1
	while k < raw.size():
		var j := raw.size() - 1
		while j > k and not _los(g, cur, raw[j], ox, oz, s): j -= 1
		out.append(raw[j]); cur = raw[j]; k = j + 1
	out.append(to)
	return out


func _spot_free(x: float, z: float) -> Vector2:
	var r := 0.0
	while r < 4:
		for a in 12:
			var px := x + cos(a * .5236) * r
			var pz := z + sin(a * .5236) * r
			if main.free_at(px, pz) and not ZN.any(func(q): return q.home != null and Vector2(q.home.x - px, q.home.z - pz).length() < 1.1):
				return Vector2(px, pz)
		r += .3
	return Vector2(x, z)


# ================= vida diaria =================
func reset() -> void:
	ZC.clear()
	left = false
	for k in spots:
		for p in spots[k]: p.o = null
	for i in ZN.size():
		var n: Dictionary = ZN[i]
		var defs := {"x":0.0,"z":0.0,"yaw":0.0,"s":"away","sb":0.0,"ph":0.0,"path":[],"tm":0.0,"ad":0.0,"leave":0,"d1":0,"dL":0,"d2":0,"met":0,"gr":randf_range(3, 10),"cb":null,"face":null,"an":"","tf":0.0,"after":null,"pl":null,"tp":null,"chk":1.0,"out":false,
			"s1":600 + randf_range(0, 50),"sl":(780 if n.boss else 720) + randf_range(0, 45),"s2":900 + randf_range(0, 45)}
		for kv in defs:
			n[kv] = defs[kv]
		n.r.visible = false
		if n.clean:
			n.x = 6.0; n.z = 11.0; n.s = "stand"; n.tm = randf_range(1, 4); n.r.visible = true
		elif i < 4:
			n.x = n.home.x; n.z = n.home.z; n.yaw = PI; n.s = "sit"; n.sb = 1.0; n.pl = n.home; n.tm = randf_range(3, 9); n.r.visible = true
		else:
			n.ad = randf_range(4, 30)
	_plan_spies()


func post(n, x: String) -> void:
	Game.chat.append({"n": n.name if n is Dictionary else str(n), "t": Game.clock_str(), "x": x})
	if Game.chat.size() > 60: Game.chat.pop_front()


func say(n: Dictionary, t: String, sec := 3.5) -> void:
	n.r.say(t, sec)


func go(n: Dictionary, t: Dictionary, after = null) -> void:
	var a: Array = []
	if n.pl != null and n.pl.get("app") != null: a.append(Vector2(n.pl.app[0], n.pl.app[1]))
	var f: Vector2 = a[0] if a.size() else Vector2(n.x, n.z)
	var to: Vector2 = Vector2(t.app[0], t.app[1]) if t.get("app") != null else Vector2(t.x, t.z)
	a += path(f, to)
	if t.get("app") != null: a.append(Vector2(t.x, t.z))
	if n.pl != null and n.pl.get("o") == n: n.pl.o = null
	if t.has("o") and t.o == null: t.o = n
	n.pl = null; n.tp = t; n.path = a; n.after = after; n.s = "walk"


func _end(n: Dictionary) -> void:
	var t: Dictionary = n.tp
	n.s = "sit" if t.get("sy", 0.0) > 0 else "stand"
	if t.has("yaw"): n.yaw = t.yaw
	n.pl = t; n.an = ""
	var f = n.after
	n.after = null
	if f is Callable: f.call()


func _arrive(n: Dictionary) -> void:
	n.r.visible = true
	n.x = 6.0; n.z = -2.3; n.yaw = 0.0; n.pl = null; n.sb = 0.0; n.s = "stand"
	say(n, "¡Buenos días!", 3)
	go(n, n.home if n.home != null else {"x": 6.0, "z": 11.0}, func(): n.tm = randf_range(3, 8))


func _leave(n: Dictionary) -> void:
	if n.leave or n.s == "away": return
	n.leave = 1; n.an = ""; n.cb = null
	post(n, "Me voy, ¡hasta mañana! 👋")
	say(n, "¡Hasta mañana!", 3)
	go(n, {"x": 6.0, "z": -2.3}, func(): n.s = "away"; n.ad = 0.0; n.r.visible = false)


func _chat(a: Dictionary, b: Dictionary) -> void:
	if a.cb != null or b.cb != null: return
	a.cb = b; b.cb = a
	a.face = Vector2(b.x, b.z); b.face = Vector2(a.x, a.z)
	a.an = "chat"; b.an = "chat"
	ZC.append({"a": a, "b": b, "q": Data.ZCONV.pick_random().duplicate(), "i": 0, "t": .6})


func _meet(n: Dictionary) -> void:
	for m in ZN:
		if m != n and m.s == "stand" and m.cb == null and m.pl != null and m.pl.get("o") == m and Vector2(m.x - n.x, m.z - n.z).length() < 1.9:
			_chat(n, m); return


func _brk(n: Dictionary, kind: String, dur: float) -> void:
	var L: Array = (spots.bench + spots.coffee + spots.vend) if kind == "lunch" else spots[kind]
	var F: Array = L.filter(func(p): return p.o == null)
	if F.is_empty():
		n.tm = 4; return
	if kind == "coffee" or kind == "lunch":
		post(n, "Salgo a almorzar 🍽️" if kind == "lunch" else "Voy por un café ☕")
	go(n, F.pick_random(), func():
		n.tm = dur
		var jam := Game.pending_at(5)
		say(n, ("¡Se atascó la copiadora!" if jam else "🖨️ Imprimiendo…") if kind == "copy" else ("¡Buen provecho! 🍽️" if kind == "lunch" else ("💧 Agua fresca" if kind == "cooler" else "☕ Mmm, café…")), 3)
		_meet(n))


func _visit(n: Dictionary) -> bool:
	var C: Array = ZN.filter(func(m): return m != n and m.home != null and m.s == "sit" and m.pl == m.home and m.cb == null and not (m.loc and Game.pending_at(m.loc)))
	if C.is_empty(): return false
	var m: Dictionary = C.pick_random()
	var h: Dictionary = m.home
	go(n, {"x": h.x + (-1.2 if h.x > 5 else 1.2), "z": h.z - .1}, func(): n.tm = 14.0; _chat(n, m))
	return true


func _plan(n: Dictionary) -> void:
	var T: int = Game.st.time
	if n.leave: return
	n.an = ""
	if n.home != null and n.pl != n.home:
		go(n, n.home, func(): n.tm = randf_range(6, 14)); return
	if n.clean:
		var q: Array = Data.ZROAM.pick_random()
		go(n, {"x": q[0], "z": q[1]}, func(): n.an = "sweep"; say(n, ["🧹 Barriendo…", "Cuidado, piso mojado", "¡Qué desorden!"].pick_random(), 3); n.tm = randf_range(5, 9)); return
	if n.loc and Game.pending_at(n.loc):
		n.an = "wave"; say(n, ["¡Mi PC no funciona!", "¡Necesito ayuda de TI!", "¡Ayúdame, por favor!"].pick_random(), 4); n.tm = randf_range(9, 14); return
	if not n.d1 and T >= n.s1:
		n.d1 = 1; _brk(n, "coffee", randf_range(14, 20)); return
	if not n.dL and T >= n.sl:
		n.dL = 1; _brk(n, "lunch", randf_range(24, 32)); return
	if not n.d2 and T >= n.s2:
		n.d2 = 1; _brk(n, "coffee", randf_range(14, 20)); return
	var r := randf()
	if n.boss and r < .35:
		var q: Array = Data.ZROAM.pick_random()
		go(n, {"x": q[0], "z": q[1]}, func(): n.tm = randf_range(5, 8); say(n, ["¿Cómo va la meta del mes?", "Quiero cero incidentes hoy", "Mantengan la seguridad al día"].pick_random(), 4)); return
	if r < .2:
		if _visit(n): return
	elif r < .3:
		_brk(n, "copy", randf_range(8, 12)); return
	elif r < .38:
		_brk(n, "cooler", randf_range(8, 12)); return
	elif r < .5:
		n.an = "phone"; say(n, Data.ZPH.pick_random(), 4); n.tm = randf_range(6, 9); return
	elif r < .6:
		say(n, Data.ZSOLO.pick_random(), 3.5)
	n.tm = randf_range(7, 16)


func talk(n: Dictionary) -> void:
	n.face = Vector2(main.cam.position.x, main.cam.position.z)
	n.tf = 4.0
	var first: bool = not n.met
	n.met = 1
	say(n, "¡Qué bueno que llegaste! Mi PC falla." if n.loc and Game.pending_at(n.loc) else (n.tips + Data.ZHELLO).pick_random(), 5)
	if first:
		Game.st.sat = min(100, Game.st.sat + 1); Game.hud()
		Game.toast("💬 Charla con %s (+1 satisfacción)" % n.name)


func nearest(p: Vector2, maxd: float):
	var b = null
	var bd := maxd
	for n in ZN:
		if n.s == "away" or n.out or not n.r.visible: continue
		var d := p.distance_to(Vector2(n.x, n.z))
		if d < bd: b = n; bd = d
	return b


func _ang(a: float, b: float, k: float) -> float:
	return a + atan2(sin(b - a), cos(b - a)) * minf(1, k)


func _up(n: Dictionary, dt: float, t: float) -> void:
	var r: Rig = n.r
	var cp := Vector2(main.cam.position.x, main.cam.position.z)
	var pd := cp.distance_to(Vector2(n.x, n.z))
	if n.s == "away":
		if n.ad > 0:
			n.ad -= dt
			if n.ad <= 0: _arrive(n)
		return
	r.name_label.visible = pd < 4.5
	if n.s == "walk":
		if n.path.is_empty():
			_end(n)
		else:
			var p: Vector2 = n.path[0]
			var dv := p - Vector2(n.x, n.z)
			var d := dv.length()
			var sp: float = n.sp * (.45 if pd < 1 else 1.0)
			if d < .06:
				n.path.pop_front()
			else:
				var s := minf(sp * dt, d)
				n.x += dv.x / d * s; n.z += dv.y / d * s
				n.yaw = _ang(n.yaw, atan2(dv.x, dv.y), dt * 9)
				n.ph += sp * dt * 5.5
		for m in ZN:
			if m != n and m.s != "away":
				var e := Vector2(n.x - m.x, n.z - m.z)
				var el := e.length()
				if el > 0 and el < .5:
					n.x += e.x / el * dt * .7; n.z += e.y / el * dt * .7
	else:
		n.tm -= dt
		if n.tm <= 0: _plan(n)
		if n.loc and n.home != null and n.pl != n.home:
			n.chk -= dt
			if n.chk < 0:
				n.chk = 1.0
				if Game.pending_at(n.loc): n.tm = 0
		if n.face != null:
			n.yaw = _ang(n.yaw, atan2(n.face.x - n.x, n.face.y - n.z), dt * 6)
		elif n.pl != null and n.pl.has("yaw"):
			n.yaw = _ang(n.yaw, n.pl.yaw, dt * 4)
		if n.tf > 0:
			n.tf -= dt
			if n.tf <= 0 and n.cb == null: n.face = null
		if pd < 2.3 and n.cb == null and r.bubble_t <= 0 and not n.clean:
			n.gr -= dt
			if n.gr <= 0:
				n.gr = randf_range(30, 60); say(n, Data.ZHELLO.pick_random(), 3)
	n.sb += ((1.0 if n.s == "sit" else 0.0) - n.sb) * minf(1, dt * 7)
	var w: bool = n.s == "walk"
	r.animate(dt, t, n.sb, w, n.ph, n.an)
	var sy: float = n.pl.get("sy", .54) if n.pl != null and n.pl.get("sy", 0.0) > 0 else .54
	r.position = Vector3(n.x, n.sb * (sy - .58) + (absf(sin(n.ph)) * .03 if w else 0.0), n.z)
	r.rotation.y = n.yaw
	var df := 0.0
	if pd < 4:
		var a: float = atan2(cp.x - n.x, cp.y - n.z) - n.yaw
		df = clampf(atan2(sin(a), cos(a)), -.9, .9)
	r.hd.rotation.y += (df - r.hd.rotation.y) * minf(1, dt * 5)


func tick(dt: float, t: float) -> void:
	if not Game.st.has("time"): return
	if not left and (Game.st.over or Game.st.time >= Data.END):
		left = true
		var i := 0
		for n in ZN:
			var nn: Dictionary = n
			get_tree().create_timer(i * .9).timeout.connect(func(): _leave(nn))
			i += 1
	for n in ZN: _up(n, dt, t)
	for k in range(ZC.size() - 1, -1, -1):
		var c: Dictionary = ZC[k]
		var bad: bool = [c.a, c.b].any(func(x): return x.s == "walk" or x.s == "away")
		if bad or c.i >= c.q.size():
			if not bad:
				c.t -= dt
				if c.t > 0: continue
			for x in [c.a, c.b]:
				x.cb = null; x.face = null; x.an = ""
			ZC.remove_at(k)
			continue
		c.t -= dt
		if c.t <= 0:
			say(c.b if c.i % 2 else c.a, c.q[c.i], 3.2)
			c.i += 1
			c.t = 3.4
	_spy_tick()
	_floor2_tick(dt, t)


# ================= piso 2 =================
func _floor2() -> void:
	game_tex = CanvasTex.make(self, Vector2i(640, 360), _draw_game)
	var tvm := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(2.4, 1.35)
	tvm.mesh = q
	tvm.material_override = Mats.screen(game_tex.texture(), 1.0)
	tvm.position = Vector3(OX + 15.86 - .06, 1.9, 18)
	tvm.rotation.y = -PI / 2
	add_child(tvm)
	var gl := OmniLight3D.new(); gl.position = Vector3(OX + 14.6, 1.9, 18); gl.light_color = Color("#7a9aff"); gl.light_energy = 1.0; gl.omni_range = 7
	add_child(gl)
	var seats := [[OX + 13.45, 15.75], [OX + 13.45, 16.5], [OX + 13.45, 17.25]]
	var gi := 0
	for i in Data.C2.size():
		var c: Dictionary = Data.C2[i]
		var r := Rig.create(Color(c.sh), Color(c.sk), Color(c.hr), c.n)
		add_child(r)
		var n := {"n": c.n, "r": r, "x": 0.0, "z": 0.0, "yaw": 0.0, "s": "idle", "tm": randf_range(2, 7), "path": [], "ph": randf() * 6, "wv": 0.0, "cd": 0.0, "gamer": c.has("g"), "cheer": 0.0, "next": 2.0 + gi * 2, "t0": randf() * 10, "out": false}
		if n.gamer:
			n.x = seats[gi][0]; n.z = seats[gi][1]; n.yaw = PI / 2; gi += 1
		else:
			var a: Array = Data.ANCH2[(i * 3 + 2) % Data.ANCH2.size()]
			n.x = OX + a[0]; n.z = a[1]; n.yaw = randf() * TAU
		r.position = Vector3(n.x, -.17 if n.gamer else 0.0, n.z)
		r.rotation.y = n.yaw
		N2.append(n)


func _draw_game(ci: CanvasItem, sz: Vector2) -> void:
	var W := sz.x; var H := sz.y
	var ts := Time.get_ticks_msec() / 1000.0
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(W, 0), Vector2(W, 180), Vector2(0, 180)]), PackedColorArray([Color("#2a1a5a"), Color("#2a1a5a"), Color("#ffb060"), Color("#ffb060")]))
	ci.draw_circle(Vector2(470, 150), 40, Color("#ffe08a"))
	for i in 18:
		var x := i * 44 - fmod(ts * 10, 44)
		var h := 50 + ((i * 37) % 80)
		ci.draw_rect(Rect2(x, 180 - h, 38, h), Color("#3a2450"))
		for k in 5:
			if (i * 7 + k * 3) % 4:
				ci.draw_rect(Rect2(x + 6 + (k % 2) * 16, 180 - h + 8 + (k / 2) * 18, 6, 8), Color("#ffd27a"))
	ci.draw_rect(Rect2(0, 180, W, H - 180), Color("#1a8a5a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(W * .44, 180), Vector2(W * .56, 180), Vector2(W * 1.15, H), Vector2(-W * .15, H)]), Color("#2a2a32"))
	for k in 9:
		var p := fmod(k + ts * 2.2, 9) / 9
		var y := 180 + (H - 180) * p * p
		var w := 2 + p * 12
		var hh := 3 + p * 20
		ci.draw_rect(Rect2(W / 2 - w / 2, y, w, hh), Color("#f4f4f4"))
		ci.draw_rect(Rect2(W / 2 - (60 + p * 420) - w, y, w * 2, hh * 2), Color("#2f7a4a"))
		ci.draw_rect(Rect2(W / 2 + (60 + p * 420) - w, y, w * 2, hh * 2), Color("#2f7a4a"))
	var sx := W / 2 + sin(ts * 1.3) * 50
	var sy := 300 + sin(ts * 9) * 2
	ci.draw_rect(Rect2(sx - 52, sy - 30, 104, 36), Color("#c4302a"))
	ci.draw_rect(Rect2(sx - 40, sy - 52, 80, 24), Color("#1a1a20"))
	ci.draw_rect(Rect2(sx - 34, sy - 48, 68, 16), Color("#8ab4d8"))
	ci.draw_rect(Rect2(sx - 60, sy, 22, 14), Color("#111111"))
	ci.draw_rect(Rect2(sx + 38, sy, 22, 14), Color("#111111"))
	CanvasTex.text(ci, "$ %d" % (12430 + int(ts * 3) * 10), Vector2(W - 18, 36), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	CanvasTex.text(ci, "★★★", Vector2(W - 18, 66), 26, Color("#ffd02a") if fmod(ts, 1.0) < .5 else Color("#ffd02a55"), HORIZONTAL_ALIGNMENT_RIGHT)
	CanvasTex.text(ci, "Sigue al objetivo · Entrega en el muelle", Vector2(W / 2, H - 14), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


var _game_t := 0.0
func _floor2_tick(dt: float, t: float) -> void:
	var cx: float = main.cam.position.x
	var on2 := cx > OX - 6 and cx < OX + 30
	for n in N2:
		n.r.visible = on2 and not n.out
	if not on2: return
	_game_t += dt
	if _game_t > .08:
		_game_t = 0
		game_tex.refresh()
	var cp := Vector2(main.cam.position.x, main.cam.position.z)
	for n in N2:
		var r: Rig = n.r
		var pd := cp.distance_to(Vector2(n.x, n.z))
		r.name_label.visible = pd < 12
		if n.gamer:
			n.cheer -= dt; n.next -= dt
			if n.next <= 0:
				n.cheer = 1.4; n.next = randf_range(6, 14); r.say(Data.GAMER.pick_random(), 3)
			var up: bool = n.cheer > 0
			r.animate(dt, t, 1.0, false, 0, "")
			r.aL.rotation.x = -2.7 + sin(t / 90.0) * .3 if up else -.95 + sin(t / 140.0 + n.t0) * .06
			r.aR.rotation.x = -2.7 + cos(t / 90.0) * .3 if up else -.95 + cos(t / 160.0 + n.t0) * .06
			r.position.y = -.17 + (absf(sin(t / 110.0)) * .05 if up else 0.0)
			continue
		if n.s == "walk" and n.path.size():
			var p: Vector2 = n.path[0]
			var dv := p - Vector2(n.x, n.z)
			var d := dv.length()
			if d < .12:
				n.path.pop_front()
				if n.path.is_empty(): n.s = "idle"; n.tm = randf_range(3, 10)
			else:
				n.x += dv.x / d * 1.25 * dt; n.z += dv.y / d * 1.25 * dt
				n.yaw = _ang(n.yaw, atan2(dv.x, dv.y), dt * 8)
				n.ph += dt * 8
			r.animate(dt, t, 0, true, n.ph, "")
		else:
			n.wv -= dt; n.cd -= dt
			r.animate(dt, t, 0, false, 0, "wave" if n.wv > 0 else "")
			if pd < 3.4 and n.cd <= 0:
				n.cd = 14.0; n.wv = 2.0
				n.yaw = atan2(cp.x - n.x, cp.y - n.z)
				r.say(Data.LINES2.get(n.n, ["¡Hola!"]).pick_random(), 4)
			n.tm -= dt
			if n.tm <= 0 and n.wv <= 0:
				var a: Array = Data.ANCH2.pick_random()
				var pth := path(Vector2(n.x, n.z), Vector2(OX + a[0], a[1]), true)
				if pth.size(): n.path = pth; n.s = "walk"
				else: n.tm = 3.0
		r.position = Vector3(n.x, 0, n.z)
		r.rotation.y = n.yaw


# ================= espionaje corporativo =================
func _plan_spies() -> void:
	for s in spies:
		if is_instance_valid(s.tag): s.tag.queue_free()
	spies.clear(); spy_caught = 0; spy_fails = 0; spy_log.clear()
	var cand: Array = ZN.filter(func(n): return not n.boss and not n.clean)
	cand.shuffle()
	var cnt := 2 if int(Game.G.get("lvl", 1)) >= 3 else 1
	for i in mini(cnt, cand.size()):
		var n: Dictionary = cand[i]
		var tag := Label3D.new()
		tag.text = "💾 ¡Copiando datos!"
		tag.font = CanvasTex.font(true)
		tag.font_size = 40; tag.pixel_size = .0035
		tag.modulate = Color.WHITE; tag.outline_size = 24; tag.outline_modulate = Color(.77, .19, .16, .92)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.position.y = 2.45; tag.visible = false
		n.r.add_child(tag)
		spies.append({"n": n, "t": (800 if i else 600) + randi() % 110, "phase": "wait", "spot": Data.SPOTS.pick_random(), "tag": tag, "has": false, "caught": false, "t0": 0.0})


func _spy_tick() -> void:
	if Game.st.over: return
	var now := Time.get_ticks_msec()
	for sp in spies:
		var n: Dictionary = sp.n
		if sp.caught: continue
		if sp.phase == "wait":
			if Game.st.time >= sp.t and n.s != "away" and n.s != "walk" and n.cb == null and not n.leave:
				sp.phase = "go"
				var s: Dictionary = sp.spot
				go(n, {"x": s.x, "z": s.z, "yaw": s.yaw}, func():
					if sp.caught: return
					sp.phase = "steal"; sp.t0 = Time.get_ticks_msec(); n.an = "phone"; n.tm = 40.0)
		elif sp.phase == "steal":
			n.tm = 40.0
			if now - sp.t0 > 30000:
				sp.phase = "done"; sp.has = true; n.an = ""; n.tm = 2.0
				Game.st.sec = max(0, Game.st.sec - 6); Game.hud()
				spy_log.push_front(Game.clock_str() + " · 🚨 DLP: copia masiva de archivos en " + sp.spot.n)
				Game.toast("🚨 Alerta DLP: copia masiva de archivos en " + sp.spot.n + ". Revisa las cámaras y confronta al responsable (X).", 6000)
		sp.tag.visible = sp.phase == "steal" and Vector2(n.x - main.cam.position.x, n.z - main.cam.position.z).length() < 14


func confront() -> void:
	if main.cam.position.x > 30 or main.cam.position.x < -4.5: return
	var b = nearest(Vector2(main.cam.position.x, main.cam.position.z), 2.9)
	if b == null:
		Game.toast("No hay nadie lo bastante cerca para confrontar (acércate a menos de 3 m)."); return
	var sp = null
	for s in spies:
		if s.n == b and not s.caught: sp = s
	if sp != null and (sp.phase == "steal" or sp.has):
		sp.caught = true; spy_caught += 1; b.an = ""
		var in_act: bool = sp.phase == "steal"
		sp.phase = "caught"; sp.tag.visible = false
		Game.G.xp = int(Game.G.xp) + (30 if in_act else 18)
		Game.st.earn += 40 if in_act else 25
		Game.st.sec = min(100, Game.st.sec + (10 if in_act else 6))
		Game.save(); Game.hud()
		say(b, "¡No es lo que parece!", 4)
		spy_log.push_front(Game.clock_str() + " · 🕵 " + b.name + " fue confrontado" + (" en el acto" if in_act else " con la memoria USB") + " y escoltado fuera.")
		Game.toast(("🕵 ¡Lo atrapaste en el acto! %s intentaba robar información (+30 XP)" if in_act else "🕵 Revisaste a %s y encontraste la memoria USB con datos (+18 XP)") % b.name, 5500)
		Game.beep(880, .15)
		Game.ach("soc")
		var bb: Dictionary = b
		get_tree().create_timer(1.5).timeout.connect(func(): _leave(bb))
	elif sp != null:
		Game.toast("Aún no hay pruebas contra " + b.name + ". Vigila las cámaras y confronta cuando lo veas actuar.")
	else:
		spy_fails += 1
		Game.bump(-5, -3, "❌ Acusaste a " + b.name + " sin pruebas: era inocente. Pierdes confianza del equipo.")
		say(b, "¿Yo? ¡Qué ofensa!", 4)


func _spy_finish() -> String:
	var lk: Array = spies.filter(func(s): return s.has and not s.caught)
	if lk.size(): Game.st.sec = max(0, Game.st.sec - 15 * lk.size())
	var m := ""
	if spy_caught: m += " 🕵 Atrapaste a %d espía(s)." % spy_caught
	if lk.size(): m += " 💸 Fuga de información: " + ", ".join(lk.map(func(s): return s.n.name)) + " vendió datos a la competencia (−15 seguridad c/u)."
	if spy_fails: m += " Acusaciones falsas: %d." % spy_fails
	return m
