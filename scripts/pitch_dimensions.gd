extends RefCounted
## Shared world-space pitch bounds. Goal/penalty-area dimensions remain independent.
const WIDTH := 72.0
const LENGTH := 100.0
const HALF_WIDTH := WIDTH * 0.5
const HALF_LENGTH := LENGTH * 0.5
# Reposition the authored stadium and team shapes without scaling people or goals.
const EXTRA_WIDTH := WIDTH - 64.0
const SIDE_SHIFT := EXTRA_WIDTH * 0.5
const WIDTH_RATIO := WIDTH / 64.0
