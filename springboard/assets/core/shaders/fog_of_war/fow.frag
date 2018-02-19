#version 110

uniform sampler2D customSampler;
uniform sampler2D texSampler;
uniform vec2 customSamplerSize;

varying vec4 vertexWorldPos;
varying vec2 texCoors;

void main(void) {
    float fow = texture2D(customSampler, vertexWorldPos.xz / customSamplerSize).r;
    gl_FragColor = texture2D(texSampler, texCoors);
    gl_FragColor.rgb = mix(vec3(0.0), gl_FragColor.rgb, fow);

    // show height (since we don't have any lighting)
    float heightFactor = max(0.5, vertexWorldPos.y / 100.0);
    heightFactor = min(1.5, heightFactor);
    gl_FragColor.rgb *= heightFactor;
}
