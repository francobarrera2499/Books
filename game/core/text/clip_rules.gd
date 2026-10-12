# core/text/clip_rules.gd — reglas puras de recorte de texto (§5.1, GDD§8.1). Dueño: W1-ENG. Contrato: ARCHITECTURE §3.8.
# snap: extiende la selección a palabras completas (inicio de la 1.ª palabra tocada; fin de la última + puntuación
#   pegada); exige ≥1 palabra (vacio), una sola oración (cruza_oracion), ≤40 palabras (mas_de_40).
# inherit: tramo ganador = mayor fracción cubierta solape/longitud_tramo (empate -> menor from);
#   ents = menciones que intersecan + e: del ganador; hereda a: c: f: d: p: x: sólo si fracción ≥ 0,5.
#   tags devueltas CON prefijo ("a:cornisa_existe", "c:holmes_vive", "x:EE01"), ordenadas y únicas.
#   date/place = primer d:/p: heredado ("" si no hay). Extra: "frac" (fracción del ganador).
extends RefCounted

const Markup = preload("res://core/text/markup.gd")

const MAX_WORDS := 40
const INHERIT := ["a", "c", "f", "d", "p", "x"]

static func snap(parsed: Dictionary, from: int, length: int) -> Dictionary:
	var plain: String = parsed.get("plain", "")
	var words: Array = parsed.get("words", [])
	var a := maxi(from, 0)
	var b := mini(from + maxi(length, 0), plain.length())
	var first := -1
	var last := -1
	for k in words.size():
		var w = words[k]
		if w[0] < b and w[1] > a:
			if first < 0:
				first = k
			last = k
	if first < 0 or b <= a:
		return {"ok": false, "err": "vacio", "from": a, "to": a, "text": "", "words": 0}
	var s: int = words[first][0]
	var e: int = words[last][1]
	while e < plain.length() and not Markup.is_word_char(plain[e]) and not Markup._is_space(plain[e]) and plain[e] != "\n":
		e += 1
	var n := last - first + 1
	var sents: Array = parsed.get("sentences", [])
	var k1 := Markup.sentence_index(sents, words[first][0])
	var k2 := Markup.sentence_index(sents, words[last][1] - 1)
	if k1 != k2 or k1 < 0:
		return {"ok": false, "err": "cruza_oracion", "from": s, "to": e, "text": "", "words": n}
	# la puntuación pegada no puede salirse de la oración
	if e > sents[k1][1]:
		e = sents[k1][1]
	if n > MAX_WORDS:
		return {"ok": false, "err": "mas_de_40", "from": s, "to": e, "text": "", "words": n}
	return {"ok": true, "err": "", "from": s, "to": e, "text": plain.substr(s, e - s), "words": n}

static func inherit(parsed: Dictionary, from: int, to: int) -> Dictionary:
	var best = null
	var best_frac := 0.0
	for t in parsed.get("tramos", []):
		var tl: int = t.to - t.from
		if tl <= 0:
			continue
		var ov := mini(to, t.to) - maxi(from, t.from)
		if ov <= 0:
			continue
		var fr := float(ov) / float(tl)
		if best == null or fr > best_frac or (fr == best_frac and t.from < best.from):
			best = t
			best_frac = fr
	var ents: Array = []
	for m in parsed.get("mentions", []):
		if m.from < to and m.to > from and not ents.has(m.ent):
			ents.append(m.ent)
	var tags: Array = []
	var date := ""
	var place := ""
	var tid := ""
	if best != null:
		tid = best.id
		for e in best.tags.get("e", []):
			if not ents.has(e):
				ents.append(e)
		if best_frac >= 0.5:
			for pre in INHERIT:
				for v in best.tags.get(pre, []):
					var tg: String = pre + ":" + String(v)
					if not tags.has(tg):
						tags.append(tg)
			if not best.tags.get("d", []).is_empty():
				date = best.tags.d[0]
			if not best.tags.get("p", []).is_empty():
				place = best.tags.p[0]
	tags.sort()
	return {"tramo": tid, "tags": tags, "ents": ents, "date": date, "place": place, "frac": best_frac}

# T4: recortes legales máximos. Oración ≤40 palabras -> la oración entera (con su puntuación);
# oración más larga -> todas las ventanas de 40 palabras consecutivas.
static func max_legal_clips(parsed: Dictionary) -> Array:
	var out: Array = []
	var plain: String = parsed.get("plain", "")
	var words: Array = parsed.get("words", [])
	for s in parsed.get("sentences", []):
		var idx: Array = []
		for k in words.size():
			if words[k][0] >= s[0] and words[k][1] <= s[1]:
				idx.append(k)
		if idx.is_empty():
			continue
		if idx.size() <= MAX_WORDS:
			out.append({"from": words[idx[0]][0], "to": _tail(plain, words[idx[-1]][1], s[1])})
		else:
			for st in range(0, idx.size() - MAX_WORDS + 1):
				out.append({"from": words[idx[st]][0], "to": _tail(plain, words[idx[st + MAX_WORDS - 1]][1], s[1])})
	return out

static func _tail(plain: String, e: int, limit: int) -> int:
	while e < limit and not Markup.is_word_char(plain[e]) and not Markup._is_space(plain[e]) and plain[e] != "\n":
		e += 1
	return e
