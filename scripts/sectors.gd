class_name Sectors
## The five sectors of the tower, left to right. Drives the zone title cards,
## each sector's neon accent colour and its ground haze.

const LIST := [
	{"start": 0.0, "code": "SECTOR 01", "name": "LOWER RING", "accent": Color("#05d9e8")},
	{"start": 680.0, "code": "SECTOR 02", "name": "THE GRINDER", "accent": Color("#ff8a3d")},
	{"start": 1300.0, "code": "SECTOR 03", "name": "KILLBOX", "accent": Color("#b14aed")},
	{"start": 1900.0, "code": "SECTOR 04", "name": "STILL SHRINE", "accent": Color("#f5c542")},
	{"start": 2576.0, "code": "SECTOR 05", "name": "KURO'S THRONE", "accent": Color("#ff2a6d")},
]


static func index_at(x: float) -> int:
	var index := 0
	for i in LIST.size():
		if x >= LIST[i].start:
			index = i
	return index


static func accent_at(x: float) -> Color:
	return LIST[index_at(x)].accent


## Where sector i ends (the next one's start, or the level edge).
static func end_of(i: int, level_w: float) -> float:
	return LIST[i + 1].start if i + 1 < LIST.size() else level_w
