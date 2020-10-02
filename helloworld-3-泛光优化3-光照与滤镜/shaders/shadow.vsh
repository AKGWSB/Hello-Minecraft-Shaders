#version 120

varying vec4 texcoord;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}

void main() {
    gl_Position = ftransform();
    gl_Position.xy = getFishEyeCoord(gl_Position.xy);
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}