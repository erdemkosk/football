"""Run correctness checks serially; fixed FPS here is not a performance metric."""
import argparse
import json
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--only', nargs='+', help='Rerun changed tests, retaining the other recorded results')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
cases = ['ball_resistance_check', 'ball_landing_check', 'lofted_switch_check',
         'ai_delivery_check', 'ai_attack_check', 'attack_decisions_check',
         'locomotion_check', 'motion_contact_check', 'carry_gait_check',
         'animation_continuity_check', 'body_language_check',
         'replay_comfort_check', 'fps_regression_check', 'render_pose_check']
results = []
if args.only:
    if any(case not in cases for case in args.only): parser.error('Unknown test in --only')
    previous = root / 'tests/native-regressions.json'
    if previous.exists(): results = [r for r in json.loads(previous.read_text()) if r['test'] not in args.only]
    cases = args.only
for case in cases:
    log = root / 'tests' / ('native-regression-' + case + '.log')
    command = [args.godot, '--headless', '--path', '.', '--fixed-fps', '120',
               '--script', 'tests/' + case + '.gd', '--log-file', log.as_posix()]
    try:
        run = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             timeout=180, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        output = run.stdout.decode('utf-8', errors='replace')
        (root / 'tests' / ('native-regression-' + case + '.stdout.log')).write_text(output, encoding='utf-8')
        failed = run.returncode != 0 or bool(re.search(r'SCRIPT ERROR|Parse Error|FAIL:|\b[1-9][0-9]* failures', output))
        failed = failed or ('PASS:' not in output and 'CHECK:' not in output)
        result = {'test': case, 'passed': not failed, 'exit_code': run.returncode}
    except subprocess.TimeoutExpired:
        result = {'test': case, 'passed': False, 'error': 'timeout'}
    results.append(result)
    print(json.dumps(result), flush=True)
    (root / 'tests/native-regressions.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
