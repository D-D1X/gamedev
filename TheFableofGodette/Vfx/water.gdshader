shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;


// Varyings
varying vec3 var_texture_v;

uniform float WaveHeight = 5;
uniform vec2 Direction;
uniform sampler2D tex_vtx_4;
uniform sampler2D depth_tex_frg_9 : hint_depth_texture;
uniform vec4 ColorParameter : source_color = vec4(0.066667, 0.321569, 1.000000, 1.000000);



void vertex() {
// Input:2
	vec3 n_out2p0 = VERTEX;


// FloatParameter:5
	float n_out5p0 = WaveHeight;


// Input:9
	float n_out9p0 = TIME;


// FloatOp:10
	float n_in10p1 = 0.02000;
	float n_out10p0 = n_out9p0 * n_in10p1;


// Vector2Parameter:11
	vec2 n_out11p0 = Direction;


// VectorOp:12
	vec2 n_out12p0 = vec2(n_out10p0) * n_out11p0;


// UVFunc:8
	vec2 n_in8p1 = vec2(1.00000, 1.00000);
	vec2 n_out8p0 = n_out12p0 * n_in8p1 + UV;


// Texture2D:4
	vec4 n_out4p0 = texture(tex_vtx_4, n_out8p0);


// VectorOp:6
	vec3 n_out6p0 = vec3(n_out5p0) * vec3(n_out4p0.xyz);


// VectorOp:3
	vec3 n_out3p0 = n_out2p0 + n_out6p0;


// Output:0
	VERTEX = n_out3p0;


// VaryingSetter:7
	var_texture_v = vec3(n_out4p0.xyz);


}

void fragment() {
	float n_out9p0;
// ProximityFade:9
	float n_in9p0 = 1.00000;
	{
		float __depth_tex = texture(depth_tex_frg_9, SCREEN_UV).r;
		vec4 __depth_world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, __depth_tex, 1.0);
		__depth_world_pos.xyz /= __depth_world_pos.w;
		n_out9p0 = clamp(1.0 - smoothstep(__depth_world_pos.z + n_in9p0, __depth_world_pos.z, VERTEX.z), 0.0, 1.0);
	}


// FloatFunc:11
	float n_out11p0 = 1.0 - n_out9p0;


// FloatOp:12
	float n_in12p1 = 0.50000;
	float n_out12p0 = n_out11p0 * n_in12p1;


// ColorParameter:2
	vec4 n_out2p0 = ColorParameter;


// VaryingGetter:5
	vec3 n_out5p0 = var_texture_v;


// FloatOp:7
	float n_in7p1 = 2.00000;
	float n_out7p0 = pow(n_out5p0.x, n_in7p1);


// FloatOp:8
	float n_in8p1 = 0.50000;
	float n_out8p0 = n_out7p0 * n_in8p1;


// VectorOp:6
	vec3 n_out6p0 = vec3(n_out2p0.xyz) + vec3(n_out8p0);


// VectorOp:10
	vec3 n_out10p0 = vec3(n_out12p0) + n_out6p0;
	vec3 final_color = clamp(vec3(n_out12p0) + n_out6p0, 0.0, 1.0);

// FloatConstant:3
	float n_out3p0 = 0.800000;


// FloatConstant:4
	float n_out4p0 = 1.000000;


// Output:0
	ALBEDO = final_color;
	ALPHA = n_out3p0;
	ROUGHNESS = n_out4p0;


}