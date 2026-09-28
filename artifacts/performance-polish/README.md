# Animation performance check — 2026-09-28

The baseline is the working copy at the start of this optimization task, **including the recently added animations**. This is not a comparison with an older release or proof that earlier animation additions were free.

Production changes are limited to `scripts/shirt_skin.gd` and `scripts/contextual_motion.gd`. The skin reuses unchanged local transforms, cancels common world/rig motion and refreshes the head independently. Contextual motion skips free-ball calculations when the ball is possessed, empty tackle scans and inactive pose/block branches. Meshes, materials, animation formulas, input, physics rate, contact thresholds and decision frequencies are unchanged.

## Native match samples

Apple M4 Pro, Godot 4.7.2 debug executable, Metal Mobile renderer, 1440×900, original 4× MSAA, physics 120 Hz. VSync was requested off and Engine.max_fps set to 0, but observed presentation stayed around 120 FPS; do not interpret this as uncapped throughput. No other test workload ran alongside these samples.

Two 5-second samples per scene in opposite orders, with 1.5 seconds settling before each. Only `playing` frames count; all recorded samples contain at least 600 frames. Initial startup warmup is excluded (the initial baseline warmup had no eligible playing frames). Live AI trajectories can diverge, so sub-millisecond changes in these short samples are not evidence of a general speedup. The native GPU timing monitor returned zero and is unavailable here.

| Scene | Before FPS | After FPS | Before p95 ms | After p95 ms |
|---|---:|---:|---:|---:|
| day | 119.99 | 119.98 | 8.869 | 8.925 |
| night | 119.99 | 119.99 | 8.934 | 8.969 |
| rain | 119.97 | 119.99 | 8.994 | 9.016 |

No measurable FPS improvement or sustained drop in these runs. This is a limited check on this Mac, not a Windows/low-end hardware guarantee. Raw samples: [before.json](before.json), [after.json](after.json).

## Paired CPU measurements

Eight alternating old/new trials on identical actor inputs, headless, medians in microseconds per player invocation. These isolate the scripts and do not measure rendered frame time. The preserved baseline sources are in `baseline/`.

| Case | Before µs | After µs | Cost reduction |
|---|---:|---:|---:|
| paused-pose | 5.135 | 1.417 | +72.4% |
| moving-fixed-pose | 5.915 | 1.435 | +75.7% |
| running-pose-30hz | 5.963 | 2.962 | +50.3% |
| running-pose-120hz | 6.398 | 7.260 | -13.5% |
| context-carried-ball | 2.997 | 1.667 | +44.4% |
| context-free-ball | 3.035 | 2.196 | +27.6% |

The cache benefits stationary poses and the existing distant-player pose schedule. Fully changing every joint on every 120 Hz sample adds about 0.9 µs/player to this isolated skin call because it also checks the cache; this case is intentionally reported. In the instrumented 22-player live simulation, total skin synchronization averaged 135.7 → 123.8 µs per sample (about 9% less). These figures are subsystem costs, not whole-game FPS gains.

## Regression checks

257 checks passed across eight suites: contextual animations 96; motion/contact 76; high saves 8; character/fingers 13; replay 31; existing performance safety 19; skin binding 3; new skin cache 11. The new suite compares 540 running/kicking/raised-arm poses across three physiques with the original world-space deformation, and covers world motion, parent/child changes, head scale, mesh changes, hidden actors, replay-style transform restoration and physical contact anchors. Largest transform-component discrepancy: 0.00000570 (float32 roundoff).

Native visual/contextual validation also ran the same 96 contextual checks; these are not double-counted above. Logs: `check-*.txt`; CPU profiles: `profile-before.txt`, `profile-after.txt`.

Reproduce from the project root, without other heavy workloads:

```sh
godot --headless --path . --script artifacts/performance-polish/cpu_benchmark.gd --log-file /tmp/sefc-animation-cpu.log
godot --path . --script artifacts/performance-polish/native_benchmark.gd --log-file /tmp/sefc-animation-native.log
godot --headless --path . --fixed-fps 120 --script tests/skin_pose_cache_check.gd --log-file /tmp/sefc-skin-cache.log
```

The CPU benchmark rewrites `paired-cpu.json`; the native benchmark rewrites `after.json`. Native settings use a temporary config path and do not save over the player's display preferences.
