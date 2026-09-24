extends RefCounted
## Readability and presentation preferences shared by match UI and settings.
var game
var text_size := 0
var team_symbols := false
var short_presentation := false
var reduce_motion := false
var ui_sounds := true
var score_scale := 1.0
var player_scale := 1.0
var map_scale := 1.0
const SCALES := [1.0,1.15,1.30]

func scale_factor() -> float:
	return SCALES[clampi(text_size,0,2)]

func hud_scale(part: String) -> float:
	return clampf(float(get(part+"_scale"))*scale_factor(),.75,1.5)

func save(cfg: ConfigFile) -> void:
	for key in ["text_size","team_symbols","short_presentation","reduce_motion","ui_sounds","score_scale","player_scale","map_scale"]: cfg.set_value("experience",key,get(key))
	cfg.set_value("experience","local_reports",game.playtest.enabled)

func load_config(cfg: ConfigFile) -> void:
	text_size=clampi(int(cfg.get_value("experience","text_size",0)),0,2)
	for key in ["team_symbols","short_presentation"]: set(key,bool(cfg.get_value("experience",key,false)))
	reduce_motion=bool(cfg.get_value("experience","reduce_motion",false))
	ui_sounds=bool(cfg.get_value("experience","ui_sounds",true))
	for key in ["score_scale","player_scale","map_scale"]: set(key,clampf(float(cfg.get_value("experience",key,1.0)),.75,1.15))
	game.playtest.enabled=bool(cfg.get_value("experience","local_reports",true))
