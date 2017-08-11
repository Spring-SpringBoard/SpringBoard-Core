uniform sampler2D mapTex;
uniform sampler2D patternTexture;

uniform mat3 kernel;
uniform float blendFactor;

uniform float patternRotation;

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
	vec4 mapColor   = texture2D(mapTex, gl_TexCoord[0].st);

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

	vec4 color = mapColor;

	vec4 weightColor = vec4(0.0, 0.0, 0.0, 0.0);
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			float w = kernel[i][j];
			weightColor += texture2D(mapTex, gl_TexCoord[0].st + vec2(i-1, j-1) * 0.001) * w;
		}
	}
/*
	vec4 weightColor = vec4(0.0, 0.0, 0.0, 0.0);
	float totalWeight = 0.0;
	for (float i = -5.0; i <= 5.0; i++) {
        for (float j = -5.0; j <= 5.0; j++) {
            float d = i * i + j * j;
            float w = 1.0 / (d * d * d + 1.0);
            totalWeight += w;
            weightColor += texture2D(mapTex, gl_TexCoord[0].st + vec2(i, j) * 0.001) * w;
        }
    }
    weightColor /= totalWeight;
*/

	gl_FragColor = mix(weightColor, mapColor, 1.0 - patternColor.a * blendFactor);
}
