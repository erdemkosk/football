extends RefCounted
## FIFA-style custom gameplay sliders. Every value runs 0..1 with 0.5 as the
## tuned default; the human side and the CPU side are set independently.
## Sliders scale existing physical and tactical quantities only; they never
## add a hidden result, a target magnet or a scripted outcome.
const KEYS := ["sprint_speed","acceleration","shot_error","pass_error","shot_speed","keeper","first_touch","line_height","line_width","marking","runs","injuries"]
const LABELS := ["Sprint hızı","İvme","Şut hatası","Pas hatası","Şut hızı","Kaleci yeteneği","İlk dokunuş hatası","Savunma çizgisi yüksekliği","Savunma genişliği","Markaj sıkılığı","Hücum koşu sıklığı","Sakatlık sıklığı"]
const SIDES := ["SEN","CPU"]
var game
var values: Array = [{},{}]

func _init() -> void:
	reset()

func reset() -> void:
	for side in range(2):
		for key in KEYS: values[side][key]=.5

func side(team: int) -> int:
	return 0 if game!=null and game.human_team(team) else 1

func value(team: int,key: String) -> float:
	return float(values[side(team)].get(key,.5))

## 0 → low, 0.5 → 1.0, 1 → high.
func scale(team: int,key: String,low: float,high: float) -> float:
	var v := value(team,key)
	return lerpf(low,1.0,v*2.0) if v<.5 else lerpf(1.0,high,(v-.5)*2.0)

## Signed offset in [-reach, reach].
func offset(team: int,key: String,reach: float) -> float:
	return (value(team,key)-.5)*2.0*reach

func set_value(side_index: int,key: String,v: float) -> void:
	values[clampi(side_index,0,1)][key]=clampf(v,0,1)
	apply()

func is_default() -> bool:
	for side in range(2):
		for key in KEYS:
			if not is_equal_approx(float(values[side][key]),.5): return false
	return true

## Push per-team multipliers to the systems that read them every frame.
func apply() -> void:
	if game==null: return
	for team in range(2):
		game.strike_quality.shot_error_scale[team]=scale(team,"shot_error",.45,1.8)
		game.strike_quality.pass_error_scale[team]=scale(team,"pass_error",.45,1.8)
		game.strike_quality.shot_speed_scale[team]=scale(team,"shot_speed",.9,1.1)
	for p in game.players:
		p.sprint_scale=scale(p.team,"sprint_speed",.88,1.12)
		p.accel_scale=scale(p.team,"acceleration",.85,1.15)

func save(cfg: ConfigFile) -> void:
	for side_index in range(2):
		for key in KEYS: cfg.set_value("sliders","%s_%s" % [["user","cpu"][side_index],key],values[side_index][key])

func load_config(cfg: ConfigFile) -> void:
	for side_index in range(2):
		for key in KEYS: values[side_index][key]=clampf(float(cfg.get_value("sliders","%s_%s" % [["user","cpu"][side_index],key],.5)),0,1)
	apply()
