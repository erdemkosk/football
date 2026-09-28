# Connected player body and shirt

`player_body.res` and `player_shirt.res` are shared by every player and official.
The body joins the neck, torso, arms and legs into one welded surface, split only
at material boundaries (skin, shorts, socks). The shirt joins torso and sleeves
and preserves the existing kit atlas. Both resources include generated LODs.

`scripts/shirt_skin.gd` attaches both meshes to one 15-bone render skeleton:
torso, shoulders, elbows, pelvis, hips, knees, four joint-volume correctives and
an upper-neck bone. Existing animated nodes remain authoritative for contacts.
Skin and cloth share their shoulder/waist weight field. Vertex alpha masks
covered skin so it cannot pierce the shirt during extreme arm poses.

Hands retain live wrist nodes and use cached curl/spread blend shapes. Face and
hair meshes remain identity-specific attachments. Only collar and cuff trims
are rigidly batched; hand anchors must never be detached by that batch.

Regenerate after editing the shape:

```sh
godot --headless --path . --script tools/build_player_shirt.gd
godot --headless --path . --script tools/build_player_body.gd
```

Validate topology, deformation, material seams, hands and contact independence:

```sh
godot --headless --path . --script tests/player_skin_binding_check.gd
godot --headless --path . --script tests/skin_pose_cache_check.gd
godot --headless --path . --script tests/character_polish_check.gd
godot --headless --path . --script tests/visual_quality_check.gd
godot --path . --script tests/player_body_check.gd -- --visual
godot --path . --script tests/player_refinement_gallery.gd
```

The two galleries save `/tmp/sefc-characters-anatomy.png`,
`/tmp/sefc-characters-anatomy-motion.png` and
`/tmp/sefc-characters-refinement-closeups.png`.
