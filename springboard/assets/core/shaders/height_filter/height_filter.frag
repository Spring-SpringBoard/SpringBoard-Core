#version 110

varying vec4 vertexWorldPos;
uniform sampler2D texSampler;

uniform float minHeight;
uniform float maxHeight;

varying vec2 texCoors;

void main(void) {
    gl_FragColor = texture2D(texSampler, texCoors);

    float heightFactor = max(0.5, vertexWorldPos.y / 100.0);
    heightFactor = min(1.5, heightFactor);

    gl_FragColor.rgb *= heightFactor;
    if (vertexWorldPos.y >= minHeight && vertexWorldPos.y <= maxHeight) {
        gl_FragColor.rgb = mix(gl_FragColor.rgb, vec3(1.0, 0.0, 0.2), 0.5);
    }
}
