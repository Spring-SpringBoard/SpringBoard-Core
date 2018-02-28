#version 110

uniform sampler2D customSampler;
uniform vec2 customSamplerSize;

varying vec4 vertexWorldPos;

void main(void) {
    gl_FragColor = texture2D(customSampler, vertexWorldPos.xz / customSamplerSize);

    float heightFactor = max(0.5, vertexWorldPos.y / 100.0);
    heightFactor = min(1.5, heightFactor);
    gl_FragColor.rgb *= heightFactor;
}
