extends RefCounted
## Shared choices for quick matches and settings stored inside each career.
const HALF_MINUTES := [2,4,6,8,10,15,20]
const DEFAULT_HALF_MINUTES := 2
const DIFFICULTIES := ["Kolay","Normal","Zor"]
## Six opponent levels. The legacy three tiers remain the tuned anchors:
## Kolay = Başlangıç, Normal = Yarı Profesyonel, Zor = Dünya Klası.
const LEVELS := ["Başlangıç","Amatör","Yarı Profesyonel","Profesyonel","Dünya Klası","Efsane"]
const LEVEL_TIER := [0,0,1,1,2,2]
const TIER_LEVEL := [0,2,4]
const DEFAULT_LEVEL := 2
const LEVEL_SHORT := ["BAŞLANGIÇ","AMATÖR","YARI PRO","PROFESYONEL","DÜNYA KLASI","EFSANE"]

static func half_minutes(value: Variant) -> int:
	return int(value) if (value is int or value is float) and value in HALF_MINUTES else DEFAULT_HALF_MINUTES

static func level_of(settings: Dictionary) -> int:
	var level: Variant=settings.get("level",null)
	if level is int or level is float: return clampi(int(level),0,LEVELS.size()-1)
	var difficulty: Variant=settings.get("difficulty",1)
	return TIER_LEVEL[clampi(int(difficulty),0,2)] if difficulty is int or difficulty is float else DEFAULT_LEVEL

static func normalized(value: Variant) -> Dictionary:
	var settings: Dictionary=value if value is Dictionary else {}
	var level := level_of(settings)
	return {"half_minutes":half_minutes(settings.get("half_minutes",DEFAULT_HALF_MINUTES)),"difficulty":LEVEL_TIER[level],"level":level}
