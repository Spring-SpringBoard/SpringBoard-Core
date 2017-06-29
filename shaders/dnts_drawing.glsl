#version 120

uniform sampler2D mapTex;
uniform sampler2D patternTexture;

uniform float x1, x2, z1, z2;
uniform float blendFactor;
// colorIndex: [1, 4] for adding and [-4, -1] for removing
uniform int colorIndex;
uniform int exclusive;
uniform float value;

vec4 colors[4] = vec4[](
	vec4(1.0, 0.0, 0.0, 0.0),
	vec4(0.0, 1.0, 0.0, 0.0),
	vec4(0.0, 0.0, 1.0, 0.0),
	vec4(0.0, 0.0, 0.0, 1.0)
);

void main(void)
{
	vec4 mapColor = texture2D(mapTex, gl_TexCoord[0].st);
    vec4 patternColor = texture2D(patternTexture, gl_TexCoord[1].st);

	int index = colorIndex;
	if (colorIndex < 0) {
		index = -index;
	}
	index = index - 1;

	if (exclusive == 0) {
		float color;
		if (colorIndex > 0) {
			color = value;
		} else {
			color = 1.0 - value;
		}
		color = mix(mapColor[index], color, blendFactor * patternColor.a);
		vec4 outColor = mapColor;
		outColor[index] = color;
		gl_FragColor = outColor;
	} else {
		vec4 color;
		if (colorIndex > 0) {
			color = colors[index] * value;
		} else {
			color = vec4(1.0 - value);
		}
		color = mix(mapColor, color, blendFactor * patternColor.a);
		if (colorIndex < 0) {
			color = min(mapColor, color);
		}
		gl_FragColor = color;
	}
}
