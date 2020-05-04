#version 110

uniform sampler2D texSampler;
uniform sampler2D texSplatDistr;
uniform sampler2D texSplatTexture;

uniform vec2 customSamplerSize;

varying vec4 vertexWorldPos;
varying vec2 texCoors;

void main(void) {
  vec4 color = texture2D(texSampler, texCoors);
  vec4 splatDistr = texture2D(texSplatDistr, vertexWorldPos.xz / customSamplerSize);
  vec4 splat = texture2D(texSplatTexture, texCoors) * splatDistr.r;

  // gl_FragColor = color + splat;
  // gl_FragColor = splat;
  gl_FragColor = splat;
  // gl_FragColor = color + splat;
}
