# core/text/markup.gd — marcado de texto de data/ (§4.3) -> ParsedText. Dueño: W1-ENG. Contrato: ARCHITECTURE §3.8.
# parse(src, ctx := {}) / lint(src, ctx := {}): el 2.º parámetro es una extensión compatible (el contrato sólo fija src):
#   ctx.names: {ent: name} superficie por defecto de [[ent]] (sin names -> el id)
#   ctx.abbrev: [..] abreviaturas que no cortan oración (por defecto DEFAULT_ABBREV = lists.abbrev de §4.6)
#   ctx.act: "act.17" reemplaza la entidad @act de las menciones (plantillas runtime)
#   ctx.allow_placeholders: true en plantillas (no marca ${x} sin resolver)
#   ctx.entities: {id:..} o [ids] -> lint verifica que existan (menciones, e:, p:)
# Índices = índices de String de GDScript sobre `plain`, fin exclusivo. Nunca push_error: errores en "errors".
# Etiquetas de tramo: tags = {a:[],e:[],c:[],f:[],d:[],p:[],q:[],h:[],w:[],x:[]} (valores sin prefijo).
extends RefCounted

const PREFIXES := ["a", "e", "c", "f", "d", "p", "q", "h", "w", "x"]
const FONT_SLOTS := ["imprenta", "maquina", "manuscrito", "ui"]
const INKS := ["negra", "lapiz", "azul", "roja", "tenue"]
const SIMPLE_STYLES := ["i", "b", "sc", "del", "rasante"]
const FORBIDDEN_GLYPHS := ["†", "‡", "⅓", "℔"]
const DEFAULT_ABBREV := ["Mr.", "Mrs.", "Dr.", "St.", "Sr.", "Sra.", "Cnel.", "Col.", "vol.", "vols.", "cap.", "pág.", "n.º", "a.", "p.", "m.", "etc."]
const ESCAPABLE := "{}[]<\\."
const TERMINATORS := ".?!…"
const CLOSERS := "»\"”’)]'"
const OPENERS := "«“\"(¿¡—–[‘'"
const MAX_TRAMO_WORDS := 40

static var _wc := {}   # caché: código -> es carácter de palabra

static func fill(src: String, vars: Dictionary) -> String:
	if src.find("${") < 0:
		return src
	var out := PackedStringArray()
	var i := 0
	var n := src.length()
	while i < n:
		var k := src.find("${", i)
		if k < 0:
			out.append(src.substr(i))
			break
		var e := src.find("}", k + 2)
		if e < 0:
			out.append(src.substr(i))
			break
		out.append(src.substr(i, k - i))
		var name := src.substr(k + 2, e - k - 2)
		if vars.has(name):
			out.append(_vstr(vars[name]))
		else:
			out.append(src.substr(k, e - k + 1))
		i = e + 1
	return "".join(out)

static func _vstr(v) -> String:
	if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v):
		return str(int(v))
	if typeof(v) == TYPE_ARRAY:
		var ps := PackedStringArray()
		for x in v:
			ps.append(_vstr(x))
		return ", ".join(ps)
	return str(v)

# Escapa texto libre para insertarlo en marcado sin que se interprete.
static func escape(s: String) -> String:
	var out := PackedStringArray()
	for i in s.length():
		var c := s[i]
		if c in ["{", "}", "[", "]", "<", "\\"]:
			out.append("\\" + c)
		else:
			out.append(c)
	return "".join(out)

static func empty_tags() -> Dictionary:
	var t := {}
	for p in PREFIXES:
		t[p] = []
	return t

static func parse(src: String, ctx := {}) -> Dictionary:
	var names: Dictionary = ctx.get("names", {})
	var act: String = String(ctx.get("act", ""))
	var allow_ph: bool = bool(ctx.get("allow_placeholders", false))
	var out := PackedStringArray()
	var plen := 0
	var mentions: Array = []
	var tramos: Array = []
	var styles: Array = []
	var errors: Array = []
	var nobreak := {}
	var stack: Array = []          # estilos abiertos {kind,val,from,tag,order}
	var tramo = null               # tramo abierto
	var order := 0
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		# --- escape ---
		if c == "\\":
			if i + 1 < n and ESCAPABLE.contains(src[i + 1]):
				var lit := src[i + 1]
				if lit == ".":
					nobreak[plen] = true
				out.append(lit)
				plen += 1
				i += 2
			else:
				errors.append("pos %d: escape desconocido '\\%s'" % [i, (src[i + 1] if i + 1 < n else "")])
				out.append("\\")
				plen += 1
				i += 1
			continue
		# --- tramo ---
		if c == "{" and i + 1 < n and src[i + 1] == "{":
			if tramo != null:
				errors.append("pos %d: tramo anidado" % i)
				i += 2
				continue
			var bar := _find_unescaped(src, "|", i + 2)
			var close := src.find("}}", i + 2)
			var header := ""
			var body_start := i + 2
			if bar < 0 or (close >= 0 and close < bar and not _inside_placeholder(src, close)):
				errors.append("pos %d: tramo sin separador '|'" % i)
			else:
				header = src.substr(i + 2, bar - i - 2)
				body_start = bar + 1
			var tr := {"id": "", "from": plen, "to": plen, "tags": empty_tags()}
			for tok in header.split(" ", false):
				if tok.begins_with("#"):
					if tr.id != "":
						errors.append("pos %d: tramo con dos ids" % i)
					tr.id = tok.substr(1)
					if tr.id == "":
						errors.append("pos %d: id de tramo vacío" % i)
					continue
				var colon := tok.find(":")
				if colon <= 0:
					errors.append("pos %d: etiqueta mal formada '%s'" % [i, tok])
					continue
				var pre := tok.substr(0, colon)
				var val := tok.substr(colon + 1)
				if not PREFIXES.has(pre):
					errors.append("pos %d: prefijo desconocido '%s'" % [i, pre])
					continue
				if val == "":
					errors.append("pos %d: etiqueta '%s:' sin valor" % [i, pre])
					continue
				if val.contains("${") and not allow_ph:
					errors.append("pos %d: placeholder sin resolver en etiqueta '%s'" % [i, tok])
				if not tr.tags[pre].has(val):
					tr.tags[pre].append(val)
			tramo = tr
			i = body_start
			continue
		if c == "}" and i + 1 < n and src[i + 1] == "}":
			if tramo == null:
				errors.append("pos %d: '}}' sin apertura" % i)
			else:
				tramo.to = plen
				tramos.append(tramo)
				tramo = null
			i += 2
			continue
		# --- mención ---
		if c == "[" and i + 1 < n and src[i + 1] == "[":
			var endm := _find_unescaped_seq(src, "]]", i + 2)
			if endm < 0:
				errors.append("pos %d: mención sin cerrar" % i)
				out.append("[[")
				plen += 2
				i += 2
				continue
			var inner := src.substr(i + 2, endm - i - 2)
			var barm := _find_unescaped(inner, "|", 0)
			var ent := inner if barm < 0 else inner.substr(0, barm)
			ent = ent.strip_edges()
			var surface := ""
			if barm < 0:
				surface = String(names.get(ent, ent))
				if ent.begins_with("@"):
					errors.append("pos %d: mención %s sin superficie" % [i, ent])
			else:
				surface = _unescape(inner.substr(barm + 1), errors, i)
				if surface.contains("${") and not allow_ph:
					errors.append("pos %d: placeholder sin resolver en mención '%s'" % [i, surface])
			if ent == "":
				errors.append("pos %d: mención sin entidad" % i)
			if inner.contains("[[") or inner.contains("{{") or inner.contains("}}"):
				errors.append("pos %d: marcado dentro de una mención" % i)
			if ent == "@act" and act != "":
				ent = act
			mentions.append({"from": plen, "to": plen + surface.length(), "ent": ent})
			out.append(surface)
			plen += surface.length()
			i = endm + 2
			continue
		if c == "]" and i + 1 < n and src[i + 1] == "]":
			errors.append("pos %d: ']]' sin apertura" % i)
			i += 2
			continue
		# --- estilo ---
		if c == "<" and i + 1 < n and (src[i + 1] == "/" or _is_ascii_letter(src[i + 1])):
			var gt := src.find(">", i + 1)
			var tag := src.substr(i + 1, gt - i - 1) if gt > 0 and gt - i < 40 else ""
			var st := _style_of(tag)
			if st.is_empty():
				errors.append("pos %d: estilo desconocido '<%s>'" % [i, tag if tag != "" else src.substr(i + 1, 8)])
				out.append("<")
				plen += 1
				i += 1
				continue
			if st.close:
				if stack.is_empty() or stack[-1].tag != st.kind:
					errors.append("pos %d: cierre '</%s>' sin pareja" % [i, tag.substr(1)])
				else:
					var o = stack.pop_back()
					styles.append({"from": o.from, "to": plen, "kind": o.kind, "val": o.val, "_o": o.order})
			else:
				order += 1
				stack.append({"kind": st.kind, "val": st.val, "from": plen, "tag": st.kind, "order": order})
			i = gt + 1
			continue
		# --- placeholder sin resolver ---
		if c == "$" and i + 1 < n and src[i + 1] == "{":
			var e2 := src.find("}", i + 2)
			if e2 > 0 and not allow_ph:
				errors.append("pos %d: placeholder sin resolver '%s'" % [i, src.substr(i, e2 - i + 1)])
		out.append(c)
		plen += 1
		i += 1
	if tramo != null:
		errors.append("tramo '%s' sin cerrar" % tramo.id)
		tramo.to = plen
		tramos.append(tramo)
	for o in stack:
		errors.append("estilo <%s> sin cerrar" % o.kind)
		styles.append({"from": o.from, "to": plen, "kind": o.kind, "val": o.val, "_o": o.order})
	styles.sort_custom(func(a, b):
		if a.from != b.from:
			return a.from < b.from
		if a.to != b.to:
			return a.to > b.to
		return a._o < b._o)
	for s in styles:
		s.erase("_o")
	var plain := "".join(out)
	var abbrev: Array = ctx.get("abbrev", DEFAULT_ABBREV)
	return {
		"plain": plain,
		"mentions": mentions,
		"tramos": tramos,
		"styles": styles,
		"sentences": sentences_of(plain, abbrev, nobreak),
		"words": words_of(plain),
		"errors": errors,
	}

static func lint(src: String, ctx := {}) -> Array:
	var p := parse(src, ctx)
	var errs: Array = p.errors.duplicate()
	for g in FORBIDDEN_GLYPHS:
		if src.contains(g):
			errs.append("glifo prohibido '%s'" % g)
	var ents = ctx.get("entities", null)
	var seen := {}
	for t in p.tramos:
		var label: String = ("#" + t.id) if t.id != "" else ("@%d" % t.from)
		if t.id != "":
			if seen.has(t.id):
				errs.append("tramo %s: id duplicado" % label)
			seen[t.id] = true
		var wn := count_words(p.words, t.from, t.to)
		if wn > MAX_TRAMO_WORDS:
			errs.append("tramo %s: %d palabras (máx. %d)" % [label, wn, MAX_TRAMO_WORDS])
		if wn == 0:
			errs.append("tramo %s: vacío" % label)
		if not _within_one_sentence(p.sentences, p.plain, t.from, t.to):
			errs.append("tramo %s: cruza oraciones" % label)
		for d in t.tags.d:
			if not _is_date(d):
				errs.append("tramo %s: fecha d: inválida '%s'" % [label, d])
		if ents != null:
			for pre in ["e", "p"]:
				for v in t.tags[pre]:
					if not _ent_exists(ents, v) and not String(v).contains("${"):
						errs.append("tramo %s: entidad %s:%s inexistente" % [label, pre, v])
	errs.append_array(_article_dups(src, ctx.get("names", {})))
	if ents != null:
		for m in p.mentions:
			if String(m.ent).begins_with("@") or String(m.ent).begins_with("act.") or String(m.ent).contains("${"):
				continue
			if not _ent_exists(ents, m.ent):
				errs.append("mención [[%s]] inexistente" % m.ent)
	return errs

const ARTICLES := ["el", "la", "los", "las", "un", "una", "unos", "unas", "del", "al", "lo"]

# [[ent]] sin superficie usa entities[ent].name; si el nombre empieza con artículo y el texto ya trae uno
# delante («contra la [[roca]]» con name «la roca»), el plano diría «la la roca».
static func _article_dups(src: String, names: Dictionary) -> Array:
	var out: Array = []
	if names.is_empty():
		return out
	var i := src.find("[[")
	while i >= 0:
		var e := _find_unescaped_seq(src, "]]", i + 2)
		if e < 0:
			break
		var inner := src.substr(i + 2, e - i - 2)
		if not inner.contains("|") and names.has(inner):
			var first := String(names[inner]).get_slice(" ", 0).to_lower()
			if ARTICLES.has(first):
				var k := i - 1
				while k >= 0 and _is_space(src[k]):
					k -= 1
				var stop := k
				while k >= 0 and is_word_char(src[k]):
					k -= 1
				var prev := src.substr(k + 1, stop - k).to_lower()
				if ARTICLES.has(prev):
					out.append("artículo duplicado: «%s [[%s]]» se lee «%s %s»; usar [[%s|…]]" % [prev, inner, prev, names[inner], inner])
		i = src.find("[[", e + 2)
	return out

static func _ent_exists(ents, id) -> bool:
	if typeof(ents) == TYPE_DICTIONARY:
		return ents.has(id)
	if typeof(ents) == TYPE_ARRAY:
		return ents.has(id)
	return true

static func _is_date(s: String) -> bool:
	if s.length() != 10 or s[4] != "-" or s[7] != "-":
		return false
	return s.substr(0, 4).is_valid_int() and s.substr(5, 2).is_valid_int() and s.substr(8, 2).is_valid_int()

static func _is_ascii_letter(c: String) -> bool:
	var u := c.unicode_at(0)
	return (u >= 97 and u <= 122) or (u >= 65 and u <= 90)

static func _style_of(tag: String) -> Dictionary:
	if tag == "":
		return {}
	var close := tag.begins_with("/")
	var t := tag.substr(1) if close else tag
	if close:
		if SIMPLE_STYLES.has(t):
			return {"close": true, "kind": t}
		if t == "f":
			return {"close": true, "kind": "font"}
		if t == "ink":
			return {"close": true, "kind": "ink"}
		return {}
	if SIMPLE_STYLES.has(t):
		return {"close": false, "kind": t, "val": ""}
	if t.begins_with("f="):
		var v := t.substr(2)
		return {"close": false, "kind": "font", "val": v} if FONT_SLOTS.has(v) else {}
	if t.begins_with("ink="):
		var v2 := t.substr(4)
		return {"close": false, "kind": "ink", "val": v2} if INKS.has(v2) else {}
	return {}

static func _find_unescaped(s: String, ch: String, from: int) -> int:
	var i := from
	var n := s.length()
	while i < n:
		var c := s[i]
		if c == "\\":
			i += 2
			continue
		if c == ch:
			return i
		i += 1
	return -1

# Primera aparición de seq desde `from` que no empiece en un carácter escapado («\]]]» cierra en el 2.º «]»).
static func _find_unescaped_seq(s: String, seq: String, from: int) -> int:
	var i := from
	var n := s.length()
	while i < n:
		if s[i] == "\\":
			i += 2
			continue
		if s.substr(i, seq.length()) == seq:
			return i
		i += 1
	return -1

static func _inside_placeholder(s: String, pos: int) -> bool:
	var k := s.rfind("${", pos)
	if k < 0:
		return false
	var e := s.find("}", k)
	return e >= pos

static func _unescape(s: String, errors: Array, pos: int) -> String:
	var out := PackedStringArray()
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "\\" and i + 1 < s.length() and ESCAPABLE.contains(s[i + 1]):
			out.append(s[i + 1])
			i += 2
			continue
		if c == "\\":
			errors.append("pos %d: escape desconocido en mención" % pos)
		out.append(c)
		i += 1
	return "".join(out)

# --- palabras y oraciones ---
static func is_word_char(c: String) -> bool:
	var u := c.unicode_at(0)
	if _wc.has(u):
		return _wc[u]
	var r := (u >= 48 and u <= 57) or c.to_upper() != c.to_lower()
	_wc[u] = r
	return r

static func words_of(plain: String) -> Array:
	var words: Array = []
	var n := plain.length()
	var i := 0
	while i < n:
		if not is_word_char(plain[i]):
			i += 1
			continue
		var s := i
		i += 1
		while i < n:
			if is_word_char(plain[i]):
				i += 1
			elif plain[i] in ["'", "’", "-"] and i + 1 < n and is_word_char(plain[i + 1]):
				i += 2
			else:
				break
		words.append([s, i])
	return words

# Palabras completamente dentro de [from, to). words está ordenado: búsqueda binaria del primero con inicio ≥ from.
static func count_words(words: Array, from: int, to: int) -> int:
	var lo := 0
	var hi := words.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if words[mid][0] < from:
			lo = mid + 1
		else:
			hi = mid
	var n := 0
	while lo < words.size() and words[lo][1] <= to:
		n += 1
		lo += 1
	return n

static func _is_space(c: String) -> bool:
	return c == " " or c == "\t" or c == "\r" or c == " " or c == " " or c == " "

static func sentences_of(plain: String, abbrev: Array = DEFAULT_ABBREV, nobreak := {}) -> Array:
	var out: Array = []
	var n := plain.length()
	var start := -1
	var last_ns := -1
	var i := 0
	while i < n:
		var c := plain[i]
		if c == "\n":
			if start >= 0:
				out.append([start, last_ns + 1])
				start = -1
			i += 1
			continue
		if _is_space(c):
			i += 1
			continue
		if start < 0:
			start = i
		last_ns = i
		if TERMINATORS.contains(c) and not (c == "." and nobreak.has(i)):
			var j := i + 1
			while j < n and CLOSERS.contains(plain[j]):
				j += 1
			if j >= n or plain[j] == "\n" or _is_space(plain[j]):
				if c == "." and _is_abbrev(plain, i, abbrev):
					i += 1
					continue
				out.append([start, j])
				start = -1
				last_ns = j - 1
				i = j
				continue
		i += 1
	if start >= 0:
		out.append([start, last_ns + 1])
	return out

static func _is_abbrev(plain: String, dot: int, abbrev: Array) -> bool:
	var s := dot
	while s > 0 and not _is_space(plain[s - 1]) and plain[s - 1] != "\n":
		s -= 1
	var tok := plain.substr(s, dot - s + 1)
	while tok.length() > 1 and OPENERS.contains(tok[0]):
		tok = tok.substr(1)
	if abbrev.has(tok):
		return true
	if tok.length() == 2:
		var c := tok[0]
		if c.to_upper() == c and c.to_lower() != c:
			return true
	return false

static func sentence_index(sentences: Array, pos: int) -> int:
	var lo := 0
	var hi := sentences.size() - 1
	while lo <= hi:
		var mid := (lo + hi) >> 1
		if pos < sentences[mid][0]:
			hi = mid - 1
		elif pos >= sentences[mid][1]:
			lo = mid + 1
		else:
			return mid
	return -1

static func _within_one_sentence(sentences: Array, plain: String, from: int, to: int) -> bool:
	var a := from
	var b := to
	while a < b and (_is_space(plain[a]) or plain[a] == "\n"):
		a += 1
	while b > a and (_is_space(plain[b - 1]) or plain[b - 1] == "\n"):
		b -= 1
	if a >= b:
		return true
	var k := sentence_index(sentences, a)
	if k < 0:
		return false
	return b <= sentences[k][1]
