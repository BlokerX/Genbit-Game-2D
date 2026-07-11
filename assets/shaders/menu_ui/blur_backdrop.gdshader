shader_type canvas_item;
uniform sampler2D screen_texture_nearest: hint_screen_texture,filter_nearest_mipmap_anisotropic;
uniform sampler2D screen_texture_linear: hint_screen_texture,filter_linear_mipmap_anisotropic;
uniform float blur_strength = 1.0;
uniform bool use_nearest = true;
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	if (use_nearest) COLOR = textureLod(screen_texture_nearest,SCREEN_UV,blur_strength);
	else COLOR = textureLod(screen_texture_linear,SCREEN_UV,blur_strength);
}
