uniform sampler2D mapTex;
uniform sampler2D patternTexture;

uniform mat3 kernel;
uniform float blendFactor;

void main(void)
{
	vec4 mapColor   = texture2D(mapTex, gl_TexCoord[0].st);
	vec4 patternColor = texture2D(patternTexture, gl_TexCoord[1].st);

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
