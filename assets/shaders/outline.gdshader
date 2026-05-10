shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_thickness : hint_range(0, 10) = 1.0;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
	
	// 1. Obliczamy maskę obwódki (szukamy sąsiadów)
	float alpha_sum = 0.0;
	alpha_sum += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	alpha_sum += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	alpha_sum += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	alpha_sum += texture(TEXTURE, UV + vec2(0, size.y)).a;
	alpha_sum += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	alpha_sum += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	alpha_sum += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	alpha_sum += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
	
	float outline_mask = clamp(alpha_sum, 0.0, 1.0);
	
	// 2. Pobieramy surowy kolor tekstury
	vec4 raw_tex = texture(TEXTURE, UV);
	
	// 3. Nakładamy MODULACJĘ (COLOR) tylko na grafikę mikstury
	// Dzięki temu FreezeEffect zabarwi tylko środek
	vec4 modulated_potion = raw_tex;
	
	// 4. Izolujemy samą obwódkę (tam gdzie jest sąsiedztwo, ale nie ma środka)
	// Używamy max(0.0, ...), żeby nie mieć ujemnych wartości
	float only_outline_area = clamp(outline_mask - raw_tex.a, 0.0, 1.0);
	
	// 5. Łączymy: 
	// Jeśli jesteśmy w polu mikstury -> rysujemy modulated_potion
	// Jeśli jesteśmy na zewnątrz (w masce obwódki) -> rysujemy czysty line_color
	
	vec4 final_output = mix(modulated_potion, line_color, only_outline_area);
	
	// Nadpisujemy COLOR wynikiem, który ma już w sobie uwzględnioną modulację środka
	COLOR = final_output;
}