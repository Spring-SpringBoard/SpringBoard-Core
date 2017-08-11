#version 120

uniform sampler2D mapTex;
uniform sampler2D patternTexture;

uniform float x1, x2, z1, z2;
uniform float blendFactor;
// colorIndex: [1, 4] for adding and [-4, -1] for removing
uniform int colorIndex;
uniform int exclusive;
uniform float value;
uniform float patternRotation;

vec4 colors[4] = vec4[](
	vec4(1.0, 0.0, 0.0, 0.0),
	vec4(0.0, 1.0, 0.0, 0.0),
	vec4(0.0, 0.0, 1.0, 0.0),
	vec4(0.0, 0.0, 0.0, 1.0)
);

float rotatedSize(float size, float rotation) {
    return size * (
        abs(sin(rotation)) +
        abs(cos(rotation))
    );
}

vec2 rotate(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, -s, s, c);
	return m * v;
}

void main(void)
{
	vec4 mapColor = texture2D(mapTex, gl_TexCoord[0].st);

	float rotatedSize = rotatedSize(1.0, patternRotation);
	vec2 patternCoords = gl_TexCoord[1].st;
	patternCoords -= vec2(0.5, 0.5);
	patternCoords = rotate(patternCoords, -patternRotation);
	patternCoords += vec2(0.5, 0.5);
	vec2 diff = vec2((rotatedSize - 1.0) / 2.0);
	patternCoords *= rotatedSize;
	patternCoords -= diff;
	if (patternCoords.x < 0.0 || patternCoords.y < 0.0 ||
		patternCoords.x > 1.0 || patternCoords.y > 1.0) {
		gl_FragColor = mapColor;
		return;
	}
	vec4 patternColor = texture2D(patternTexture, patternCoords);

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
			//color = 1.0 - value;
			color = 0.0;
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
			//color = vec4(1.0 - value);
			color = vec4(0.0);
		}
		color = mix(mapColor, color, blendFactor * patternColor.a);
		if (colorIndex < 0) {
			color = min(mapColor, color);
		}
		gl_FragColor = color;
	}
}
