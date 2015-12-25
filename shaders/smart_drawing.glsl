uniform sampler2D mapTex;
uniform sampler2D heightmapTex;
uniform sampler2D paintTex1;
uniform sampler2D paintTex2;
uniform sampler2D paintTex3;
uniform sampler2D paintTex4;

uniform float x1, x2, z1, z2;
uniform float blendFactor;
uniform float falloffFactor;
uniform float featureFactor;
uniform vec4 diffuseColor;
uniform float voidFactor;

uniform vec4 minHeight;
uniform vec4 minSlope;

vec4 mix(vec4 penColor, vec4 mapColor, float alpha) {
	return vec4(penColor.rgb * alpha + mapColor.rgb * (1.0 - alpha), alpha);
}

void main(void)
{
	vec4 mapColor = texture2D(mapTex, gl_TexCoord[0].st);
	vec2 heightCoord = gl_TexCoord[1].st;
	heightCoord = vec2(heightCoord.x / 12, heightCoord.y / 8);
	float height = texture2D(heightmapTex, heightCoord);
	
	vec4 texColor1 = texture2D(paintTex1, gl_TexCoord[1].st);
	vec4 texColor2 = texture2D(paintTex2, gl_TexCoord[1].st);
	vec4 texColor3 = texture2D(paintTex3, gl_TexCoord[1].st);
	vec4 texColor4 = texture2D(paintTex4, gl_TexCoord[1].st);
	
// 	float dh1 = texture2D(heightmapTex, heightCoord + vec2(1, 0)) - height;
// 	float dh2 = texture2D(heightmapTex, heightCoord + vec2(0, 1)) - height;
// 	float dh3 = texture2D(heightmapTex, heightCoord + vec2(-1, 0)) - height;
// 	float dh4 = texture2D(heightmapTex, heightCoord + vec2(0, -1)) - height;
// 	//float slope = sqrt(dh1 * dh1 + dh2 * dh2 + dh3 * dh3 + dh4 * dh4) / 4;
// 	float slope = sqrt(dh1 * dh1 + dh2 * dh2 + dh3 * dh3 + dh4 * dh4);
	
	float dh1 = texture2D(heightmapTex, heightCoord + vec2(0.02, 0)) - height;
	float dh2 = texture2D(heightmapTex, heightCoord + vec2(0, 0.03)) - height;
	float dh3 = texture2D(heightmapTex, heightCoord + vec2(-0.02, 0)) - height;
	float dh4 = texture2D(heightmapTex, heightCoord + vec2(0, -0.03)) - height;
	//float slope = sqrt(dh1 * dh1 + dh2 * dh2) / 100;
	float slope = sqrt(dh1 * dh1 + dh2 * dh2 + dh3 * dh3 + dh4 * dh4) / 150;
	
// 	if (height < minHeight || height > maxHeight) {
// 		gl_FragColor = mapColor;
// 		return;
// 	}
	vec4 weights = vec4(0, 0, 0, 0);
	float weightSum = 0;
	for (int i = 0; i < 4; i++) {
		weights[i] = 1 / ((slope - minSlope[i]) * (slope - minSlope[i]) + 0.1);
		weightSum += weights[i];
	}
	if (slope < minSlope[0]) {
		gl_FragColor = mapColor;
		return;
	} /*if (slope < minSlope[1]) { // 0
		texColor = texColor1;
		float d1 = slope - minSlope[0];
		float d2 = minSlope[1] - slope;
		texColor = mix(texColor1, texColor2, (d2 - d1) / (d1 + d2) + 0.5);
		texColor.a = 1;
	} else if (slope < minSlope[2]) { // 1
		float d1 = slope - minSlope[1];
		float d2 = minSlope[2] - slope;
		texColor = mix(texColor1, texColor2, (d2 - d1) / (d1 + d2) + 0.5);
		texColor.a = 1;
	} else if (slope < minSlope[3]) { // 2
		float d1 = slope - minSlope[2];
		float d2 = minSlope[3] - slope;
		texColor = mix(texColor1, texColor2, (d2 - d1) / (d1 + d2) + 0.5);
		texColor.a = 1;
	} else { // 3
		float d1 = slope - minSlope[2];
		float d2 = slope - minSlope[3];
		texColor = mix(texColor1, texColor2, (d2 - d1) / (d1 + d2) + 0.5);
		texColor.a = 1;
	}*/
	
	vec4 texColor = vec4(0, 0, 0, 0);
	for (int i = 0; i < 4; i++) {
		vec4 t;
		if (i == 0) {
			t = texColor1;
		} else if (i == 1) {
			t = texColor2;
		} else if (i == 2) {
			t = texColor3;
		} else if (i == 3) {
			t = texColor4;
		}
		texColor += t * weights[i];
	}
	texColor /= weightSum;
	texColor.a = 1;
	
// 	slope = abs(dh1) + abs(dh2);
// 	slope /= 100;
// 	texColor = vec4(slope/3, slope/3, slope/3, 1);
	vec4 color = diffuseColor * texColor;
	
	// mode goes here
	color = %s;

	//alpha *= 20;
	//alpha = floor(alpha) / 20;
	//color.rgb = color.rgb * alpha;

	// extract texture features
	featureFactor = (1 - featureFactor) / 2;
	color = mix(min(color, (max(color,mapColor+featureFactor)-featureFactor)-featureFactor)+featureFactor,mapColor,color.a);

	// apply only a percentage part of the texture
	//blendFactor = blendFactor * blendFactor;
	color = mix(color, mapColor, blendFactor);

	// calculate alpha (smaller the further away it is), used to draw circles
	vec2 size = vec2(x2 - x1, z2 - z1);
	vec2 center = size / 2;
	vec2 delta = (gl_TexCoord[0].xy - vec2(x1, z1) - center) / size;
	float distance = sqrt(delta.x * delta.x + delta.y * delta.y);
	float alpha = 1 - 2 * distance;
	alpha = clamp(alpha, 0, 1);
	color = mix(color, mapColor, alpha);
	
	// falloff crispness (use previously calculated alpha to make for a smooth falloff blending
	alpha = 1 - min(1.0f, alpha + falloffFactor);
	color = mix(min(color, (max(color,mapColor+alpha)-alpha)-alpha)+alpha,mapColor,color.a);

	// TODO: this can be used for deleting textures (void maps)
	//alpha = 1;
// 	if (alpha > 0.9) {
// 		alpha = 1;
// 	}
	color.a = 1 - (1 - alpha) * voidFactor;
	color.a = min(color.a, mapColor.a);
	
	color.a = mix(min(color.a, (max(color.a,mapColor.a+alpha)-alpha)-alpha)+alpha,mapColor.a,1 - alpha);
	
	gl_FragColor = color;
	//gl_FragColor.a = 1; // there are issues if this is less than 1
}