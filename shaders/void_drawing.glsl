uniform sampler2D mapTex;
uniform sampler2D patternTexture;

uniform float x1, x2, z1, z2;
uniform float voidFactor;
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

	float vf = voidFactor;
	if (vf > 0.0) {
		vf = 1.0;
	} else {
		vf = -1.0;
	}
    vf *= patternColor.a;
	//if (vf > 0.0) {
	if (vf > 0.5) {
		//color.a = 1.0 - vf;
		color.a = 0.0;
		color.a = min(color.a, mapColor.a);
	//} else {
	} else if (vf < -0.5) {
		//color.a = -vf;
		color.a = 1.0;
		color.a = max(color.a, mapColor.a);
	}
	//color.a = f1 * alpha + mapColor.a * (1.0 - alpha);

	gl_FragColor = color;
	//gl_FragColor.a = 1; // there are issues if this is less than 1
}
