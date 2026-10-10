shader_type canvas_item;

// Kolor obramowania
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Grubość obrysu
uniform float outline_width : hint_range(0.0, 10.0, 1.0) = 1.0; 
// 8-kierunkowy (kwadratowy) czy 4-kierunkowy (krzyżyk)
uniform bool pattern = true;

// 1. MAGIA VERTEX SHADERA: ROZSZERZANIE PŁÓTNA
void vertex() {
	// sign(VERTEX) zwraca kierunek narożnika (-1 lub 1). 
	// Rozsuwamy fizyczne wierzchołki siatki o naszą grubość obrysu.
	VERTEX += sign(VERTEX) * outline_width;
}

bool is_uv_in_bounds(vec2 uv) {
	return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

void fragment() {
	// 2. KOREKTA ROZCIĄGANIA
	// Skoro powiększyliśmy płótno, musimy "skurczyć" mapowanie UV, żeby obrazek nie uległ deformacji.
	vec2 uv_scale = 1.0 + (TEXTURE_PIXEL_SIZE * outline_width * 2.0);
	vec2 corrected_uv = (UV - 0.5) * uv_scale + 0.5;
	
	// Pobieramy kolor ze skorygowanego miejsca
	vec4 sprite_color = vec4(0.0);
	if (is_uv_in_bounds(corrected_uv)) {
		sprite_color = texture(TEXTURE, corrected_uv);
	}
	float alpha = sprite_color.a;
	
	// Obliczamy rozmiar jednego piksela
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	
	// 3. RYSOWANIE OBRYSU
	// Szukamy sąsiednich pikseli używając naszej skorygowanej siatki
	float outline = 0.0;
	vec2 sample_uv = corrected_uv + vec2(-size.x, 0.0);
	if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
	sample_uv = corrected_uv + vec2(0.0, size.y);
	if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
	sample_uv = corrected_uv + vec2(size.x, 0.0);
	if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
	sample_uv = corrected_uv + vec2(0.0, -size.y);
	if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
	
	if (pattern) {
		sample_uv = corrected_uv + vec2(-size.x, size.y);
		if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
		sample_uv = corrected_uv + vec2(size.x, size.y);
		if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
		sample_uv = corrected_uv + vec2(-size.x, -size.y);
		if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
		sample_uv = corrected_uv + vec2(size.x, -size.y);
		if (is_uv_in_bounds(sample_uv)) outline += texture(TEXTURE, sample_uv).a;
	}
	
	outline = min(outline, 1.0);
	
	// 4. MIESZANIE I WYNIK
	vec4 final_color = mix(sprite_color, outline_color, outline - alpha);
	COLOR = vec4(final_color.rgb, max(alpha, outline));
}