# Unit: core/util/timekey.gd (W1-ENG). §3.2.
extends "res://tests/test_base.gd"

const TK = preload("res://core/util/timekey.gd")

func test_tk_and_parse():
	eq(TK.tk(4, "dawn"), 40)
	eq(TK.tk(0, "N"), 3)
	eq(TK.tk(7, "night"), 74)
	eq(TK.tk(1, "X"), -1)
	eq(TK.parse("4.dawn"), 40)
	eq(TK.parse("P.N"), 3)
	eq(TK.parse("10.M"), 101)
	eq(TK.parse("E.dawn"), 110)
	eq(TK.parse("7.night"), 74)
	for bad in ["", "x", "4", "4.X", "12.M", "-1.M", ".M", "4."]:
		eq(TK.parse(bad), -1, bad)

func test_label_roundtrip():
	eq(TK.label(3), "P.N")
	eq(TK.label(40), "4.dawn")
	eq(TK.label(101), "10.M")
	eq(TK.label(110), "E.dawn")
	for d in range(0, 12):
		for s in TK.SLOTS:
			eq(TK.parse(TK.label(TK.tk(d, s))), TK.tk(d, s), "%d.%s" % [d, s])

func test_order():
	ok(TK.parse("3.night") < TK.parse("4.dawn"))
	ok(TK.parse("4.dawn") < TK.parse("4.M"))
	ok(TK.parse("P.N") < TK.parse("P.night"))

func test_idx():
	eq(TK.idx_count(), 29)
	eq(TK.idx(0, "N"), 0)
	eq(TK.idx(1, "M"), 1)
	eq(TK.idx(5, "N"), 15)
	eq(TK.idx(6, "T"), 16)
	eq(TK.idx(6, "M"), -1, "día 6 sólo T")
	eq(TK.idx(7, "M"), 17)
	eq(TK.idx(9, "N"), 25)
	eq(TK.idx(10, "N"), 28)
	eq(TK.idx(4, "dawn"), -1)
	eq(TK.idx(11, "M"), -1)
	for i in TK.idx_count():
		var x := TK.from_idx(i)
		eq(TK.idx(x.day, x.slot), i)
	eq(TK.from_idx(29), {})
	eq(TK.from_idx(-1), {})

func test_idx_helpers():
	eq(TK.idx_of_tk("4.M"), TK.idx(4, "M"))
	eq(TK.idx_of_tk("4.dawn"), -1)
	eq(TK.idx_at_or_after("4.dawn"), TK.idx(4, "M"))
	eq(TK.idx_at_or_after("6.dawn"), TK.idx(6, "T"))
	eq(TK.idx_at_or_after("10.night"), 29)
	eq(TK.of(40), 40)
	eq(TK.of("4.dawn"), 40)
	eq(TK.of(40.0), 40)
	eq(TK.of(null), -1)
	eq(TK.day_of(101), 10)
	eq(TK.slot_of(101), "M")
