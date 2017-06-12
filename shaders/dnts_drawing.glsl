#version 120

uniform sampler2D mapTex;
uniform sampler2D patternTexture;

uniform float x1, x2, z1, z2;
uniform float blendFactor;
uniform float falloffFactor;
uniform float voidFactor;
// colorIndex: [1, 4] for adding and [-4, -1] for removing
uniform int colorIndex;

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
	int factor = 1;
	if (colorIndex < 0) {
		factor = -1;
		index = -index;
	}
	index = index - 1;
	if (colorIndex < 0) {
		vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
	}
	float color = 1;

	//alpha *= 20;
	//alpha = floor(alpha) / 20;
	//color.rgb = color.rgb * alpha;

	// apply only a percentage part of the texture
	// blendFactor = blendFactor * blendFactor;
	color = mix(mapColor[index], color, blendFactor);

	color = mix(mapColor[index], color, patternColor.a);
	// TODO: this can be used for deleting textures (void maps)
	//alpha = 1;
// 	if (alpha > 0.9) {
// 		alpha = 1;
// 	}

	// color.a = 1.0 - (1.0 - alpha) * voidFactor;
	// color.a = min(color.a, mapColor.a);
	//
	// float f1 = min(color.a, (max(color.a, mapColor.a + alpha) - alpha) - alpha) + alpha;
	// color.a = f1 * alpha + mapColor.a * (1.0 - alpha);

	//gl_FragColor = vec4(0.0, 0.0, 1.0, 0.0);
	vec4 outColor = mapColor;
	outColor[index] = color;
	gl_FragColor = outColor;
	//gl_FragColor = mapColor;
	//gl_FragColor.a = 1; // there are issues if this is less than 1
}
