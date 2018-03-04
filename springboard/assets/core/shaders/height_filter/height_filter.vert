#version 120

varying vec4 vertexWorldPos;

#define SMF_TEXSQR_SIZE 1024.0

uniform ivec2 texSquare;
varying vec2 texCoors;

void main(void) {
    vertexWorldPos = gl_Vertex;

    texCoors = (floor(gl_Vertex.xz) / SMF_TEXSQR_SIZE) - vec2(texSquare);

    gl_Position = gl_ModelViewProjectionMatrix * vertexWorldPos;
}
