shader_type spatial;
render_mode unshaded, cull_disabled;

// Podés ajustar estos valores desde el Inspector una vez asignado el shader
uniform float grid_size : hint_range(0.1, 10.0) = 1.0;   // tamaño de cada celda
uniform float line_thickness : hint_range(0.001, 0.1) = 0.02; // grosor de la línea
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
uniform vec4 base_color : source_color = vec4(0.1, 0.1, 0.12, 1.0);

void fragment() {
	// UV escalado según el tamaño de celda deseado
	vec2 coord = UV * (1.0 / grid_size) * 50.0; // 50 = coincide con el Size del PlaneMesh

	// Distancia al borde de celda más cercano (en X e Y)
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	float line = min(grid.x, grid.y);

	// Si estamos cerca de una línea, pintamos línea; si no, el color base
	float is_line = 1.0 - smoothstep(0.0, line_thickness * 50.0, line);

	ALBEDO = mix(base_color.rgb, line_color.rgb, is_line);
	ALPHA = mix(base_color.a, line_color.a, is_line);
	
	// Coordenada del mundo en este punto del piso, para detectar los ejes centrales
vec2 world_pos = (UV - 0.5) * 50.0; // 50 = mismo tamaño que tu PlaneMesh

float axis_thickness = 0.05;
float is_x_axis = 1.0 - smoothstep(0.0, axis_thickness, abs(world_pos.y));
float is_z_axis = 1.0 - smoothstep(0.0, axis_thickness, abs(world_pos.x));

vec3 color_with_grid = mix(base_color.rgb, line_color.rgb, is_line);
color_with_grid = mix(color_with_grid, vec3(0.85, 0.2, 0.2), is_x_axis); // rojo para eje X
color_with_grid = mix(color_with_grid, vec3(0.2, 0.4, 0.85), is_z_axis); // azul para eje Z

ALBEDO = color_with_grid;
ALPHA = mix(base_color.a, line_color.a, is_line);
}
