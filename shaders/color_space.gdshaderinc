// Procedural palette colors are authored in sRGB, just like StandardMaterial3D.
// Compatibility shades in sRGB; Metal/Vulkan need linear albedo values.
vec3 palette_color(vec3 color) {
 if (OUTPUT_IS_SRGB) { return color; }
 return mix(color / 12.92, pow((color + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
}
