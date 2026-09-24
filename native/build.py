"""Build the optional Windows kernel with pinned godot-cpp and portable Zig.

python native/build.py --godot-cpp PATH --zig PATH_TO_ZIG_EXE
Build intermediates live outside the project. No network/install side effects.
"""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--godot-cpp', required=True, type=Path)
parser.add_argument('--zig', required=True, type=Path)
args = parser.parse_args()
cpp = args.godot_cpp.resolve()
root = Path(__file__).resolve().parent
revision = subprocess.check_output(['git', '-C', str(cpp), 'rev-parse', 'HEAD'], text=True).strip()
if revision != '714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa':
    raise SystemExit('Use godot-cpp commit 714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa')
build = Path(tempfile.gettempdir()) / 'sefc-native-build'
build.mkdir(exist_ok=True)
sys.path.insert(0, str(cpp))
from build_profile import generate_trimmed_api
from binding_generator import _generate_bindings
profile = build / 'profile.json'
profile.write_text(json.dumps({'enabled_classes': ['RefCounted', 'OS']}))
api = generate_trimmed_api(str(cpp / 'gdextension/extension_api.json'), str(profile))
if not (build / 'gen/include/godot_cpp/classes/os.hpp').exists():
    _generate_bindings(api, False, '64', 'single', str(build))
common = [str(args.zig), 'c++', '-target', 'x86_64-windows-gnu', '-std=c++17',
          '-O3', '-DNDEBUG', '-DWINDOWS_ENABLED', '-fno-exceptions',
          '-fno-fast-math', '-ffp-contract=off', '-fvisibility=hidden',
          '-I' + str(cpp / 'include'), '-I' + str(cpp / 'gdextension'),
          '-I' + str(build / 'gen/include')]
env = os.environ.copy()
env['ZIG_GLOBAL_CACHE_DIR'] = str(build / 'zig-cache')
sources = sorted((cpp / 'src').rglob('*.cpp')) + sorted((build / 'gen/src').rglob('*.cpp')) + [root / 'match_kernels.cpp']
def compile_one(source):
    import hashlib
    obj = build / (source.stem + '-' + hashlib.sha256(str(source).encode()).hexdigest()[:8] + '.o')
    if not obj.exists() or obj.stat().st_mtime < max(source.stat().st_mtime, Path(__file__).stat().st_mtime):
        subprocess.run(common + ['-c', str(source), '-o', str(obj)], check=True, env=env)
    return obj
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    objects = list(pool.map(compile_one, sources))
out = root / 'bin'
out.mkdir(exist_ok=True)
response = build / 'objects.rsp'
response.write_text('\n'.join('"' + str(p).replace('\\', '/') + '"' for p in objects))
subprocess.run(common + ['-shared', '@' + str(response), '-o', str(out / 'match.windows.x86_64.dll')], check=True, env=env)
print('Built', out / 'match.windows.x86_64.dll', flush=True)
