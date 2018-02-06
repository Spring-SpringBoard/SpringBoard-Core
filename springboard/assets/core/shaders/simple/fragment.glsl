uniform sampler2D texSampler;

varying vec2 texCoors;

void main(void) {
    gl_FragColor = texture2D(texSampler, texCoors);
}
