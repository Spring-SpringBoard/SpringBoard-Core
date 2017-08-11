uniform sampler2D mapTex;
uniform sampler2D patternTexture;
uniform sampler2D brushTexture;

uniform float x1, x2, z1, z2;
uniform float blendFactor;
uniform float falloffFactor;
uniform float featureFactor;
uniform vec4 diffuseColor;
uniform float voidFactor;
uniform float patternRotation;

vec4 mix(vec4 penColor, vec4 mapColor, float alpha) {
	return vec4(penColor.rgb * alpha + mapColor.rgb * (1.0 - alpha), alpha);
}

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

	vec4 brushTextureColor = texture2D(brushTexture, gl_TexCoord[2].st);

	vec4 color = diffuseColor * brushTextureColor;

	// mode goes here
	color = %s;

	//alpha *= 20;
	//alpha = floor(alpha) / 20;
	//color.rgb = color.rgb * alpha;

	// extract texture features
	float ff = (1.0 - featureFactor) / 2.0;
	color = mix(min(color, (max(color,mapColor+ff)-ff)-ff)+ff,mapColor,color.a);

	// apply only a percentage part of the texture
	//blendFactor = blendFactor * blendFactor;
	color = mix(color, mapColor, blendFactor);

	// calculate alpha (smaller the further away it is), used to draw circles
	vec2 size = vec2(x2 - x1, z2 - z1);
	vec2 center = size / 2.0;
	vec2 delta = (gl_TexCoord[0].xy - vec2(x1, z1) - center) / size;
	float distance = sqrt(delta.x * delta.x + delta.y * delta.y);
	float alpha = 1.0 - 2.0 * distance;
	alpha = clamp(alpha, 0.0, 1.0);
// 	color = mix(color, mapColor, alpha);

	// falloff crispness (use previously calculated alpha to make for a smooth falloff blending
	alpha = 1.0 - min(1.0, alpha + falloffFactor);
// 	color = mix(min(color, (max(color,mapColor+alpha)-alpha)-alpha)+alpha,mapColor,color.a);

	color = mix(color, mapColor, patternColor.a);
	// TODO: this can be used for deleting textures (void maps)
	//alpha = 1;
// 	if (alpha > 0.9) {
// 		alpha = 1;
// 	}
	color.a = 1.0 - (1.0 - alpha) * voidFactor;
	color.a = min(color.a, mapColor.a);

	float f1 = min(color.a, (max(color.a, mapColor.a + alpha) - alpha) - alpha) + alpha;
	color.a = f1 * alpha + mapColor.a * (1.0 - alpha);

	gl_FragColor = color;
	//gl_FragColor.a = 1; // there are issues if this is less than 1
}
