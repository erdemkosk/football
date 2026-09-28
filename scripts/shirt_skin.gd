extends Node
## A shared weighted skeleton for the connected body and shirt. Existing
## animation joints stay authoritative for IK, movement and ball contacts.
const SURFACE=preload("res://assets/models/player_shirt.res")
const BODY=preload("res://assets/models/player_body.res")
const BodyShape=preload("res://scripts/player_body_mesh.gd")
const ORIGIN:=Vector3(0,1.22,0)
const REST:=[Vector3(0,.94,0),Vector3(-.28,1.475,0),Vector3(.28,1.475,0),Vector3(-.28,1.20,0),Vector3(.28,1.20,0),Vector3.ZERO,Vector3(-.14,.85,0),Vector3(.14,.85,0),Vector3(-.14,.52,0),Vector3(.14,.52,0),Vector3(-.28,1.20,0),Vector3(.28,1.20,0),Vector3(-.14,.52,0),Vector3(.14,.52,0),Vector3(0,1.60+BodyShape.CROWN*(1-BodyShape.HEAD_SCALE),0)]
var actor
var skeleton: RID
var poses: Array[Transform3D]=[]
var joints: Array[Node3D]=[]
var bind_inverse: Array[Transform3D]=[]
var body: MeshInstance3D
var local_poses: Array[Transform3D]=[]
var mesh_inverse := Transform3D.IDENTITY
var head_pose := Transform3D.IDENTITY
var pose_ready := false

func setup(player) -> void:
	actor=player; name="PlayerSkin"; actor.add_child(self)
	joints.assign([actor.spine,actor.left_arm,actor.right_arm,actor.left_elbow,actor.right_elbow,actor.rig,actor.left_leg,actor.right_leg,actor.left_knee,actor.right_knee])
	for at: Vector3 in REST:
		bind_inverse.append(Transform3D(Basis.IDENTITY,ORIGIN-at))
		poses.append(Transform3D.IDENTITY)
	skeleton=RenderingServer.skeleton_create()
	RenderingServer.skeleton_allocate_data(skeleton,REST.size())
	for i in range(REST.size()): RenderingServer.skeleton_bone_set_transform(skeleton,i,Transform3D.IDENTITY)
	body=MeshInstance3D.new(); body.name="ConnectedBody"; body.mesh=BODY
	actor.jersey_body.add_child(body)
	for i in range(3): body.set_surface_override_material(i,actor.kit_materials[["skin","shorts","socks"][i]])
	RenderingServer.instance_attach_skeleton(actor.jersey_body.get_instance(),skeleton)
	RenderingServer.instance_attach_skeleton(body.get_instance(),skeleton)
	actor.kit_materials.printed.set_shader_parameter("skeletal_waist",true)
	RenderingServer.frame_pre_draw.connect(sync_pose)
	sync_pose()

func sync_pose() -> void:
	# The mesh, shoulders and head share spine space. Rig/world movement
	# cancels from the skin equation; hips need only the inverse spine pose.
	var next: Array[Transform3D]=[actor.spine.transform,actor.left_arm.transform,actor.right_arm.transform,actor.left_elbow.transform,actor.right_elbow.transform,actor.left_leg.transform,actor.right_leg.transform,actor.left_knee.transform,actor.right_knee.transform,actor.jersey_body.transform]
	var mesh_changed := not pose_ready or next[9]!=local_poses[9]
	if mesh_changed: mesh_inverse=next[9].affine_inverse()
	if next!=local_poses:
		local_poses=next
		var hips := next[0].affine_inverse()
		var left_hip := hips*next[5]
		var right_hip := hips*next[6]
		var relative: Array[Transform3D]=[Transform3D.IDENTITY,next[1],next[2],next[1]*next[3],next[2]*next[4],hips,left_hip,right_hip,left_hip*next[7],right_hip*next[8]]
		for i in range(relative.size()):
			var at:=relative[i]
			if i==0: at.basis=Basis.from_scale(Vector3(actor.jersey_body.scale.x,1,1))
			upload(i,mesh_inverse*at*bind_inverse[i])
		for i in range(4):
			var joint: Node3D=joints[[3,4,8,9][i]]
			var q:=joint.quaternion
			var half:=Quaternion.IDENTITY.slerp(q,.5)
			var angle:=Quaternion.IDENTITY.angle_to(q)
			var volume:=minf(1.32,1.0/maxf(.5,cos(angle*.5)))
			var bend:=Transform3D(Basis(half)*Basis.from_scale(Vector3(1,1,volume)),joint.position)
			upload(10+i,mesh_inverse*relative[[1,2,6,7][i]]*bend*bind_inverse[10+i])
	var neck: Transform3D=actor.head_joint.transform
	if not pose_ready or mesh_changed or neck!=head_pose:
		head_pose=neck
		neck.basis=neck.basis*Basis.from_scale(Vector3.ONE/actor.head_joint.scale)
		upload(14,mesh_inverse*neck*bind_inverse[14])
	pose_ready=true

func upload(index: int,pose: Transform3D) -> void:
	if poses[index]==pose: return
	poses[index]=pose
	RenderingServer.skeleton_bone_set_transform(skeleton,index,pose)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync_pose): RenderingServer.frame_pre_draw.disconnect(sync_pose)
	if skeleton.is_valid(): RenderingServer.free_rid(skeleton)
