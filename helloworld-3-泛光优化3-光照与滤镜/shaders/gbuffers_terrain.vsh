#version 120

varying vec4 texcoord;
varying vec4 lightMapCoord;
varying vec3 color;
varying float blockId;

attribute vec4 mc_Entity;

void main() {
    gl_Position = ftransform();
    color = gl_Color.rgb;   // 方块原色
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0; // 方块纹理坐标
    lightMapCoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;    // 光照纹理坐标
    blockId = mc_Entity.x;  // 方块id
}