uniform sampler2D mapTex;
uniform sampler2D brushTex;
uniform sampler2D paintTex;

uniform float x1, x2, z1, z2;
uniform float blendFactor;
uniform float falloffFactor;
uniform float featureFactor;
uniform vec4 diffuseColor;
uniform float voidFactor;

vec4 mix(vec4 penColor, vec4 mapColor, float alpha) {
	return vec4(penColor.rgb * alpha + mapColor.rgb * (1.0 - alpha), alpha);
}

void main(void)
{
	vec4 mapColor   = texture2D(mapTex, gl_TexCoord[0].st);
    vec4 brushColor = texture2D(brushTex, gl_TexCoord[1].st);
	vec4 texColor   = texture2D(paintTex, gl_TexCoord[2].st);

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
// 	color = mix(color, mapColor, alpha);
	
	// falloff crispness (use previously calculated alpha to make for a smooth falloff blending
	alpha = 1 - min(1.0f, alpha + falloffFactor);
// 	color = mix(min(color, (max(color,mapColor+alpha)-alpha)-alpha)+alpha,mapColor,color.a);

	color = mix(color, mapColor, brushColor.a);
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