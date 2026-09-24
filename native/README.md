# Optional match kernels

The Windows x86-64 build accelerates lob launch prediction, zero-spin flight
sampling and the delivery interception loop. It changes neither the search
candidates nor the physics tick rate. `scripts/native_match.gd` loads the library
once, lazily. Other platforms and missing-library builds keep the GDScript
implementations. `-- --script-kernels` disables the native path for comparisons.

Curved flight stays in GDScript: an initial native rotation experiment differed
by up to 0.000000715 metres at three sampled points. That implementation was
removed rather than relaxing decision-equivalence requirements.

## Rebuild

The included Windows DLL was compiled with Zig 0.14.1, using godot-cpp tag
`godot-4.4-stable`, commit `714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa`.
The 4.4 extension ABI is used by the project's Godot 4.7.2 runtime.

1. Obtain [Zig 0.14.1](https://ziglang.org/download/0.14.1/zig-x86_64-windows-0.14.1.zip).
   Official archive SHA256: `554f5378228923ffd558eac35e21af020c73789d87afeabf4bfd16f2e6feed2c`.
2. Clone [godot-cpp](https://github.com/godotengine/godot-cpp) at the commit above.
3. Run `python native/build.py --godot-cpp PATH --zig PATH_TO_ZIG_EXE`.

Build intermediates and the compiler cache go to the temporary directory.
The build uses float32 vectors, float64 scalar calculations, no fast-math and
no fused multiply-add. This is required for the equality tests, not optional
performance tuning. The build does not download dependencies or install tools.

`addons/native_match_export` adds the DLL, runtime config and third-party notices
to Windows exports. Native sources are excluded from Godot's resource scan.
The config deliberately uses `.cfg` and explicit loading: unsupported platforms
must not automatically try to load a Windows-only extension. The DLL is placed
beside the exported executable under `native/bin/`.

## Verification

- `tests/native_ball_check.gd`: 54,000 exact scalar/vector comparisons, including
  different air resistance, 0/1/12/48/64 steps and varying launch positions.
- `tests/native_delivery_check.gd`: 4,800 full assessment dictionaries, alternating
  reference/native order, dry/wet weather, all AI difficulties, hidden/dismissed
  players, missing receivers, ground/lob routes and saturated risks.
- `tests/native_match_benchmark.gd`: two reversed-order real-render comparisons.
- `tools/stage_release_benchmark.py`: makes a separate temporary export project;
  it never changes the game's main scene or export preset. Run the exported EXE
  and collect its `results.json`. Export logs must contain no script parse errors.

The kernel microbenchmarks do not establish a whole-game FPS gain or a 120 FPS
guarantee. See `tests/native_optimization_results.md` for actual frame measurements.
