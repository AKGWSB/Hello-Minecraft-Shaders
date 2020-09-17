#version 120

varying vec4 texcoord;



void main() {
    gl_Position = ftransform();
    float len = length(gl_Position.xy);
    //gl_Position.xy /= 0.15  + 0.85 * len;
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    
}