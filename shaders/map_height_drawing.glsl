uniform sampler2D mapTex;
uniform sampler2D patternTexture;
uniform sampler2D heightTexture;

uniform float minHeight;
uniform float maxHeight;

uniform float strength;

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

	vec4 color = mapColor;

	// TODO: Heightmap-based coloring logic should go here
	vec4 heightColor = texture2D(heightTexture, gl_TexCoord[3].st);
	float height = heightColor.r;
	float relativeHeight = (height - minHeight) / (maxHeight - minHeight);

	vec4 heightValue = vec4(0.0);

	const vec4 hill = vec4(0.53, 0.53, 0.45, 1.0);
	const vec4 plain = vec4(0.7, 0.43, 0.5, 1.0);
	const vec4 snow = vec4(0.9, 0.9, 0.9, 1.0);
	if (relativeHeight < 0.5) {
		heightValue = plain;
	} else if (relativeHeight < 0.7) {
		heightValue = mix(plain, hill, (relativeHeight - 0.5) / 0.2);
	} else if (relativeHeight < 0.9) {
		float factor = (relativeHeight - 0.7) / 0.2;
		heightValue = mix(hill, snow, abs(sin(factor * 50.0)) / 3.14);
	} else {
		heightValue = snow;
	}


	gl_FragColor = mix(heightValue, mapColor, 1.0 - patternColor.a * strength);
}
