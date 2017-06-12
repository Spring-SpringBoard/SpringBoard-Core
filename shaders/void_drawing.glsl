uniform sampler2D mapTex;
uniform sampler2D patternTexture;

uniform float x1, x2, z1, z2;
uniform float voidFactor;

void main(void)
{
	vec4 mapColor = texture2D(mapTex, gl_TexCoord[0].st);
	vec4 patternColor = texture2D(patternTexture, gl_TexCoord[1].st);
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
