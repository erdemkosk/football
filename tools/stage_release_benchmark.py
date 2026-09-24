"""Create an isolated release benchmark project without changing game settings."""
from pathlib import Path
import argparse
import shutil
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
mode = parser.add_mutually_exclusive_group()
mode.add_argument('--player-batch', action='store_true')
mode.add_argument('--wet-turf', action='store_true')
args = parser.parse_args()
stage = Path(tempfile.mkdtemp(prefix='sefc-release-'))
for folder in ['scripts', 'shaders', 'assets', 'native', 'addons']:
    shutil.copytree(root / folder, stage / folder, ignore=shutil.ignore_patterns('*.pdb', '*.lib', '__pycache__'))
shutil.copy2(root / 'main.tscn', stage / 'main.tscn')
project = (root / 'project.godot').read_text(encoding='utf-8').replace('run/main_scene="res://main.tscn"', 'run/main_scene="res://benchmark.tscn"')
(stage / 'project.godot').write_text(project, encoding='utf-8')
presets = (root / 'export_presets.cfg').read_text(encoding='utf-8')
template = Path(tempfile.gettempdir()) / 'sefc-native-tools/windows_release_x86_64.exe'
presets = presets.replace('[preset.1.options]', '[preset.1.options]\ncustom_template/release="' + template.as_posix() + '"')
presets = presets.replace('application/modify_resources=true', 'application/modify_resources=false')
(stage / 'export_presets.cfg').write_text(presets, encoding='utf-8')
source = (root / 'tests/performance_benchmark.gd').read_text(encoding='utf-8')
source = source.replace('extends SceneTree', '''extends Node
@onready var root: Window=get_tree().root
var process_frame: Signal:
    get: return get_tree().process_frame
var physics_frame: Signal:
    get: return get_tree().physics_frame
func quit(code: int=0) -> void: get_tree().quit(code)''')
source = source.replace('func _initialize()', 'func _ready()')
# Use the active-play-only sample used by editor measurements.
paired = (root / 'tests/fps_compare_benchmark.gd').read_text(encoding='utf-8')
sample = paired[paired.index('func sample('):paired.index('func run()')]
source = source[:source.index('func sample(')] + sample
source += '''
func run() -> void:
    game=load("res://main.tscn").instantiate(); root.add_child(game); await physics_frame
    game.match_menu.config_path="user://benchmark-settings.tmp"
    game.match_menu.display.set_fullscreen(false); game.match_menu.display.select_resolution(Vector2i(1440,900))
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
    RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
    var native=load("res://scripts/native_match.gd")
    print("RELEASE BUILD debug=",OS.is_debug_build()," native=",native.get_kernel()!=null)
    await sample("warmup",true,1,true)
    results.clear()
    for trial in range(2):
        for enabled in ([false,true] if trial==0 else [true,false]):
            native.enabled=enabled
            label="native" if enabled else "script"
            await sample(label+"-day-"+str(trial),true,0)
            await sample(label+"-night-"+str(trial),true,1)
            await sample(label+"-rain-"+str(trial),true,1,true)
    var file=FileAccess.open(OS.get_executable_path().get_base_dir().path_join("results.json"),FileAccess.WRITE)
    if file: file.store_string(JSON.stringify(results,"\\t")); file.close()
    game.free(); quit()
'''
if args.player_batch:
    custom = (root / 'tests/player_batch_benchmark.gd').read_text(encoding='utf-8')
    source = source[:source.index('func run()')] + custom[custom.index('func run()'):]
    source = source.replace('var label := "before"', 'var label := "before"\nvar batch_enabled:=true')
    source = source.replace('game.start_match(false,false)', 'game.start_match(false,false)\n\tfor player in game.players+game.referees.actors:\n\t\tif is_instance_valid(player.render_batch): player.render_batch.set_active(batch_enabled)')
elif args.wet_turf:
    shutil.copy2(root / 'tests/grass_wet_before.gdshader', stage / 'shaders/grass_wet_before.gdshader')
    custom = (root / 'tests/wet_turf_live_benchmark.gd').read_text(encoding='utf-8')
    source = source[:source.index('func run()')] + custom[custom.index('func run()'):]
    source = source.replace('var label := "before"', 'var label := "before"\nvar original_shader:=false')
    source = source.replace('game.start_match(false,false)', 'game.start_match(false,false)\n\tgame.stadium.grass.shader=load("res://shaders/grass_wet_before.gdshader") if original_shader else load("res://shaders/grass.gdshader")')
(stage / 'benchmark.gd').write_text(source.expandtabs(4), encoding='utf-8')
(stage / 'benchmark.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://benchmark.gd" id="1"]\n[node name="Benchmark" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
(stage / 'out').mkdir()
(root / 'tests/release-stage-path.tmp').write_text(str(stage), encoding='utf-8')
print(stage)
