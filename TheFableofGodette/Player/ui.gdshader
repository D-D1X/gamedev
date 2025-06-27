shader_type canvas_item;

uniform float time : hint_range(0.0, 1.0); // Controls distortion over time
uniform vec4 font_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Default Red

void fragment() {
    vec2 uv = UV;

    // Apply sine wave distortion
    uv.x += sin(uv.y * 20.0 + TIME * 5.0) * 0.05 * (1.0 - time);
    uv.y += cos(uv.x * 20.0 + TIME * 5.0) * 0.05 * (1.0 - time);

    vec4 color = texture(TEXTURE, uv);

    // Apply the font color and fade-in effect
    color *= font_color; // Multiplies the sampled texture color by the uniform font color
    color.a *= time;  // Apply fade-in effect

    COLOR = color;
}
