//#define use_normalmapping
//#define flip_normalmap
//#define use_shadows
//#define flipAlpha
//#define tex1Alpha

//#define deferred

  __FRAGMENT_GLOBAL_NAMESPACE__

  uniform sampler2D textureS3o1;
  uniform sampler2D textureS3o2;
  uniform samplerCube specularTex;
  uniform samplerCube reflectTex;

  uniform vec3 sunDir;
  uniform vec3 sunDiffuse;
  uniform vec3 sunAmbient;

#ifdef use_shadows
  uniform sampler2DShadow shadowTex;
  uniform float shadowDensity;
#endif

  uniform vec4 teamColor; // alpha contains `far distance fading factor`

  varying vec4 vertexWorldPos;
  varying vec3 cameraDir;
  varying float fogFactor;

#ifdef use_normalmapping
  uniform sampler2D normalMap;
  varying mat3 tbnMatrix;
#else
  varying vec3 normalv;
#endif

uniform int numModelDynLights;

float GetShadowCoeff(vec4 shadowCoors)
{
	#ifdef use_shadows
	float coeff = shadow2DProj(shadowTex, shadowCoors).r;

	coeff  = (1.0 - coeff);
	coeff *= shadowDensity;
	return (1.0 - coeff);
	#else
	return 1.0;
	#endif
}

void main(void)
{
#ifdef use_normalmapping
	vec2 tc = gl_TexCoord[0].st;
	#ifdef flip_normalmap
		tc.t = 1.0 - tc.t;
	#endif
	vec3 nvTS  = normalize((texture2D(normalMap, tc).xyz - 0.5) * 2.0);
	vec3 normal = tbnMatrix * nvTS;
#else
	vec3 normal = normalize(normalv);
#endif

	vec3 light = max(dot(normal, sunDir), 0.0) * sunDiffuse + sunAmbient;

	vec4 diffuse     = texture2D(textureS3o1, gl_TexCoord[0].st);
	vec4 extraColor  = texture2D(textureS3o2, gl_TexCoord[0].st);

	vec3 reflectDir = reflect(cameraDir, normal);
	vec3 specular   = textureCube(specularTex, reflectDir).rgb * extraColor.g * 4.0;
	vec3 reflection = textureCube(reflectTex,  reflectDir).rgb;

	float shadow = GetShadowCoeff(gl_TexCoord[1] + vec4(0.0, 0.0, -0.00005, 0.0));

	// no highlights if in shadow; decrease light to ambient level
	specular *= shadow;
	light = mix(sunAmbient, light, shadow);


	reflection  = mix(light, reflection, extraColor.g); // reflection
	reflection += extraColor.rrr; // self-illum

	#ifndef deferred
	gl_FragColor     = diffuse;
	gl_FragColor.rgb = mix(gl_FragColor.rgb, teamColor.rgb, gl_FragColor.a); // teamcolor
	gl_FragColor.rgb = gl_FragColor.rgb * reflection + specular;
	#endif

	#ifdef deferred
	gl_FragData[0] = vec4((normal + vec3(1.0, 1.0, 1.0)) * 0.5, 1.0);
	gl_FragData[1] = vec4(mix(diffuse.rgb, teamColor.rgb, diffuse.a), extraColor.a * teamColor.a);
	gl_FragData[0].rgb += sin(time*4) / 3.14 / 10 + 0.1;
	// do not premultiply reflection, leave it to the deferred lighting pass
	// gl_FragData[GBUFFER_DIFFTEX_IDX] = vec4(mix(diffuse.rgb, teamColor.rgb, diffuse.a) * reflection, extraColor.a * teamColor.a);
	// allows standard-lighting reconstruction by lazy LuaMaterials using us
	gl_FragData[2] = extraColor;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 0.0);
	gl_FragData[4] = vec4(0.0, 0.0, 0.0, 0.0);
	#else
	//gl_FragColor.rgb = mix(gl_Fog.color.rgb, gl_FragColor.rgb, fogFactor); // fog
	gl_FragColor.a   = extraColor.a;
	__FRAGMENT_POST_SHADING__
	#endif
}
