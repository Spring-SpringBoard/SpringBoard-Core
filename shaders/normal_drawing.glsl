uniform sampler2D mapTex;
uniform sampler2D paintTex;

uniform float x1, x2, z1, z2;
uniform float blendFactor;
uniform float falloffFactor;
uniform float featureFactor;
uniform vec4 diffuseColor;

vec4 mix(vec4 penColor, vec4 mapColor, float alpha) {
	return vec4(penColor.rgb * alpha + mapColor.rgb * (1.0 - alpha), 1.0);
}

void main(void)
{
	vec4 mapColor = texture2D(mapTex, gl_TexCoord[0].st);
	vec4 texColor = texture2D(paintTex, gl_TexCoord[1].st);

	vec4 color = texColor;

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
	float falloffAlpha = 1 - min(1.0f, alpha + falloffFactor);
	color = mix(min(color, (max(color,mapColor+falloffAlpha)-falloffAlpha)-falloffAlpha)+falloffAlpha,mapColor,color.a);
	
	//color.xz = color.ra;
	//color.y = sqrt(1 - dot(color.xz, color.xz));

	//shadingNormal.xyz = NORMALIZE(terrainNormal.xyz * (1 - detailNormalTex.a) 
    //                           + detailNormalTex.rgb)
	//color.rgb = normalize(color.rgb);
	color.a = 0.0;
	// color.r = color.r
	//color.a = color.g;
	//color.rgb = color.r;
	//color.gb = color.r;
	
	//color.rgb = normalize(color.rgb);
	//color.a = 1 - color.g;
	//color.rgb = color.rrr;
	//color = %s;
	
	gl_FragColor = color;
	//gl_FragColor.a = 1; // there are issues if this is less than 1
}