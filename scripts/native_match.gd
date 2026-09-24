extends RefCounted
## Optional, result-equivalent kernels. Unsupported platforms use the script path.
static var enabled := not "--script-kernels" in OS.get_cmdline_user_args()
static var checked := false
static var kernel: RefCounted
const CONFIG := "res://native/match.cfg"
const LIBRARY := "res://native/bin/match.windows.x86_64.dll"

static func get_kernel() -> RefCounted:
	if not enabled: return null
	if checked: return kernel
	checked=true
	if OS.get_name()!="Windows" or not OS.has_feature("x86_64"): return null
	var external := OS.get_executable_path().get_base_dir().path_join("native/bin/match.windows.x86_64.dll")
	if not FileAccess.file_exists(CONFIG) or (not FileAccess.file_exists(LIBRARY) and not FileAccess.file_exists(external)): return null
	if not ClassDB.class_exists("MatchKernels"):
		var status := GDExtensionManager.load_extension(CONFIG)
		if status!=GDExtensionManager.LOAD_STATUS_OK and status!=GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			push_warning("Native match kernels unavailable; using identical script calculations.")
			return null
	if ClassDB.class_exists("MatchKernels"): kernel=ClassDB.instantiate("MatchKernels")
	return kernel
