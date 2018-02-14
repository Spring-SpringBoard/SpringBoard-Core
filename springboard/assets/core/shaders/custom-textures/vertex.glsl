varying vec4 vertexWorldPos;

void main(void) {
    vertexWorldPos = gl_Vertex;
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
