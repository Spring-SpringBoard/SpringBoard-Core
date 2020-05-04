#version 110

#define SMF_TEXSQR_SIZE 1024.0

varying vec4 vertexWorldPos;

uniform ivec2 texSquare;
varying vec2 texCoors;

void main(void) {
    vertexWorldPos = gl_Vertex;

    texCoors = (floor(gl_Vertex.xz) / SMF_TEXSQR_SIZE) - vec2(texSquare);

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
