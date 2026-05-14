shader_type canvas_item;

uniform sampler2D texture_new : filter_nearest_mipmap_anisotropic;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec3 final = texture(texture_new,UV).rgb;
	COLOR.rgb = final;
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
