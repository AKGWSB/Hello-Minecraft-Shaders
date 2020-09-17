#version 120

uniform sampler2D texture;

varying vec4 texcoord;

vec2 fishEye(vec2 positionInScreenCoord) {
    vec2 positionInNdcCoord = positionInScreenCoord*2 - 1;
    positionInNdcCoord *= 0.15 + 0.85 * length(positionInNdcCoord.xy);
    positionInScreenCoord = positionInNdcCoord * 0.5 + 0.5;
    return positionInScreenCoord;
}

void main() {
    vec2 texcoordst = fishEye(texcoord.st);
    gl_FragData[0] = texture2D(texture, texcoordst);
}