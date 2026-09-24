extends RefCounted
const Native=preload("res://scripts/native_match.gd")
## Shared resistance model for the physical ball and pre-kick trajectory estimates.
const DRY_ROLLING := 2.0
const DRY_DAMPING := 0.12
const DRY_AIR := 0.0026
const MAGNUS := 0.10
const GRAVITY := 9.81
static var flight_origin := Vector3.INF
static var flight_velocity := Vector3.INF
static var flight_spin := INF
static var flight_drag := INF
static var flight_samples: Dictionary={}

static func profile(surface,point: Vector3) -> Vector2:
	if is_instance_valid(surface) and surface.has_method("ball_resistance"): return surface.ball_resistance(point)
	if is_instance_valid(surface): return Vector2(surface.ball_drag(point),surface.ball_rolling_damping(point))
	return Vector2(DRY_ROLLING,DRY_DAMPING)

static func along(surface,origin: Vector3,target: Vector3) -> Vector2:
	if not is_instance_valid(surface): return Vector2(DRY_ROLLING,DRY_DAMPING)
	var result := Vector2.ZERO
	for i in range(5): result+=profile(surface,origin.lerp(target,(i+0.5)/5.0))
	return result/5.0

static func stop_time(speed: float,resistance: Vector2) -> float:
	return log(1+maxf(0,speed)*resistance.y/resistance.x)/resistance.y

static func rolling_speed(speed: float,delta: float,resistance: Vector2) -> float:
	# Exact integration of dv/dt = -(rolling resistance + speed-dependent loss).
	var ratio := resistance.x/resistance.y
	return maxf(0,(speed+ratio)*exp(-resistance.y*delta)-ratio)

static func distance_at(speed: float,time: float,resistance: Vector2) -> float:
	var duration := minf(time,stop_time(speed,resistance))
	var ratio := resistance.x/resistance.y
	return maxf(0,(speed+ratio)*(1-exp(-resistance.y*duration))/resistance.y-ratio*duration)

static func travel_time(speed: float,distance: float,resistance: Vector2) -> float:
	var low := 0.0
	var high := stop_time(speed,resistance)
	var ratio := resistance.x/resistance.y
	for i in range(13):
		var middle := (low+high)*0.5
		# Every midpoint is already before stop_time. Keep the same bisection
		# while avoiding thirteen redundant logarithms and parameter divisions.
		var travelled := maxf(0,(speed+ratio)*(1-exp(-resistance.y*middle))/resistance.y-ratio*middle)
		if travelled<distance: low=middle
		else: high=middle
	return (low+high)*0.5

static func passing_speed(base: float,distance: float,resistance: Vector2) -> float:
	# Assistance adjusts the kick only. There is no target-dependent force in flight.
	var reserve := distance_at(4.0,stop_time(4.0,resistance),resistance)
	if distance_at(base,stop_time(base,resistance),resistance)>=distance+reserve: return base
	var low := base
	var high := 30.0
	for i in range(12):
		var middle := (low+high)*0.5
		if distance_at(middle,stop_time(middle,resistance),resistance)<distance+reserve: low=middle
		else: high=middle
	return high

static func air_drag(surface) -> float:
	return surface.ball_air_drag() if is_instance_valid(surface) else DRY_AIR

static func air_velocity(velocity: Vector3,delta: float,drag: float) -> Vector3:
	return velocity/(1+drag*velocity.length()*delta)

static func apply_spin(velocity: Vector3,spin: float,delta: float) -> Vector3:
	# Magnus deflection changes heading without adding artificial kinetic energy.
	if absf(spin)<0.001: return velocity
	var horizontal := Vector3(velocity.x,0,velocity.z).rotated(Vector3.UP,-spin*MAGNUS*delta)
	return Vector3(horizontal.x,velocity.y,horizontal.z)

static func decay_spin(spin: float,delta: float,airborne: bool,rolling_resistance: float=DRY_ROLLING) -> float:
	return move_toward(spin,0,delta*(0.17 if airborne else rolling_resistance*0.45))

static func sample_flight(origin: Vector3,velocity: Vector3,spin: float,seconds: float,steps: int,surface=null) -> PackedVector3Array:
	var drag := air_drag(surface)
	# Cover, receiving runs and second-ball support ask for the same flight.
	# Reuse only identical physical inputs; a deflection invalidates immediately.
	if origin!=flight_origin or velocity!=flight_velocity or spin!=flight_spin or drag!=flight_drag:
		flight_samples.clear()
		flight_origin=origin; flight_velocity=velocity; flight_spin=spin; flight_drag=drag
	var key := [seconds,steps]
	if flight_samples.has(key): return flight_samples[key].duplicate()
	var kernel := Native.get_kernel()
	if kernel!=null and spin==0.0 and steps>=0 and steps<=1000000:
		var result: PackedVector3Array=kernel.sample_straight_flight(origin,velocity,seconds,steps,drag)
		if flight_samples.size()>=8: flight_samples.clear()
		flight_samples[key]=result.duplicate()
		return result
	var points := PackedVector3Array([origin])
	var delta := seconds/float(maxi(1,steps))
	var position := origin
	var flight := velocity
	var curve := spin
	for step in range(steps):
		flight=air_velocity(flight+Vector3.DOWN*GRAVITY*delta,delta,drag)
		flight=apply_spin(flight,curve,delta)
		curve=decay_spin(curve,delta,true)
		position+=flight*delta
		points.append(position)
	if flight_samples.size()>=8: flight_samples.clear()
	flight_samples[key]=points.duplicate()
	return points

static func lob_velocity(origin: Vector3,target: Vector3,flight: float,surface=null) -> Vector3:
	var kernel := Native.get_kernel()
	if kernel!=null: return kernel.lob_velocity(origin,target,flight,air_drag(surface))
	var launch := (target-origin)/flight+Vector3.UP*4.905*flight
	var drag := air_drag(surface)
	var delta := flight/48
	# Predict loss before the kick; the launched ball still follows normal physics.
	for iteration in range(3):
		var position := origin
		var velocity := launch
		for step in range(48):
			var next := air_velocity(velocity+Vector3.DOWN*9.81*delta,delta,drag)
			position+=(velocity+next)*0.5*delta
			velocity=next
		launch+=(target-position)/flight
	return launch
