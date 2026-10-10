shader_type canvas_item;

uniform sampler2D texture_new : filter_nearest_mipmap_anisotropic;
// W TileMapLayer UV obejmuje cały atlas, a nie pojedynczy kafel, więc przeliczamy je na lokalne UV kafla.
// Wartości muszą zgadzać się z TileSetAtlasSource (texture_region_size i use_texture_padding).
uniform vec2 tile_size = vec2(64.0);
uniform bool texture_padding = true;

void fragment() {
	float pad = texture_padding ? 1.0 : 0.0;
	vec2 atlas_px = UV / TEXTURE_PIXEL_SIZE;
	vec2 tile_uv = (mod(atlas_px, tile_size + 2.0 * pad) - pad) / tile_size;
	COLOR.rgb = texture(texture_new, clamp(tile_uv, 0.0, 1.0)).rgb;
}
