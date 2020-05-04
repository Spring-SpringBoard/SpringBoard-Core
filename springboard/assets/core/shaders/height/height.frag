#version 110

varying vec4 vertexWorldPos;
uniform sampler2D texSampler;
uniform float time;

varying vec2 texCoors;

void main(void) {
    gl_FragColor = texture2D(texSampler, texCoors);

    float heightFactor = max(0.5, vertexWorldPos.y / 100.0);
    heightFactor = min(1.5, heightFactor);
    gl_FragColor.rgb *= heightFactor;

    if (vertexWorldPos.x > 300.0 && vertexWorldPos.x < 500.0) {
        gl_FragColor.g /= sin(vertexWorldPos.y / 10.0 + 4.0 * time) / 4.0 + 2.0;
    }
}
