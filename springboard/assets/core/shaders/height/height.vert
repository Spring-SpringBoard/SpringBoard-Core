#version 110

uniform sampler2D customSampler;
uniform vec2 customSamplerSize;

varying vec4 vertexWorldPos;

#define SMF_TEXSQR_SIZE 1024.0

uniform ivec2 texSquare;
varying vec2 texCoors;

void main(void) {
    vertexWorldPos = gl_Vertex;

    vec4 pos = texture2D(customSampler, vertexWorldPos.xz / customSamplerSize);
    // vertexWorldPos.xy += (pos.g + pos.r + pos.b) * 1.0;

    // vertexWorldPos.y += sin(gl_Vertex.x * 20.0) * 100.0;
    vertexWorldPos.y += ((pos.r + pos.g + pos.b) / 3.0 - 0.5) * 200.0;

    texCoors = (floor(gl_Vertex.xz) / SMF_TEXSQR_SIZE) - vec2(texSquare);

    gl_Position = gl_ModelViewProjectionMatrix * vertexWorldPos;
}
