shader_type spatial;
render_mode unshaded, blend_add;

void fragment() {
    ALBEDO = vec3(0.8, 0.9, 1.0); // Sword-like color
    ALPHA = smoothstep(0.5, 1.0, UV.y); // Vertical fade
}