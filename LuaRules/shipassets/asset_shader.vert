#version 120

varying vec3 viewNormal;
varying vec3 viewTangent;
varying vec3 viewBitangent;
varying vec2 texCoord;
varying vec3 objectPos;
varying vec3 objectNormal;
varying vec3 viewPos;

void main()
{
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

	viewNormal    = gl_NormalMatrix * gl_Normal;
	// Tangent and bitangent ride on legacy texcoord units 5 and 6.
	viewTangent   = gl_NormalMatrix * gl_MultiTexCoord5.xyz;
	viewBitangent = gl_NormalMatrix * gl_MultiTexCoord6.xyz;

	texCoord     = gl_MultiTexCoord0.st;
	objectPos    = gl_Vertex.xyz;
	objectNormal = gl_Normal;
	viewPos      = (gl_ModelViewMatrix * gl_Vertex).xyz;
}
