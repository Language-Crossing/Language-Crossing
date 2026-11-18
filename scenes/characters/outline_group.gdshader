// Outline for a CanvasGroup: draws a line around everything in the group combined,
// so a character made of stacked body, outfit and hair sprites gets one outer outline
// with no lines between the layers. Set on the character's "Sprites" CanvasGroup.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
// In screen pixels; the character sets this to one art pixel.
uniform float line_thickness : hint_range(0.0, 10.0) = 2.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 size = SCREEN_PIXEL_SIZE * line_thickness;
	float outline = texture(screen_texture, SCREEN_UV + vec2(-size.x, 0.0)).a;
	outline += texture(screen_texture, SCREEN_UV + vec2(size.x, 0.0)).a;
	outline += texture(screen_texture, SCREEN_UV + vec2(0.0, size.y)).a;
	outline += texture(screen_texture, SCREEN_UV + vec2(0.0, -size.y)).a;
	outline = min(outline, 1.0);

	vec4 color = textureLod(screen_texture, SCREEN_UV, 0.0);
	// The group's texture is premultiplied; undo it before mixing.
	if (color.a > 0.0001) {
		color.rgb /= color.a;
	}
	COLOR = mix(color, line_color, outline - color.a);
}
