#version 120

// 声明2号颜色缓冲区为 R32F 格式 只有x通道可用 传递方块id
const int R32F = 114;
const int colortex2Format = R32F;

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 texcoord;
varying vec4 lightMapCoord;
varying vec3 color;
varying float blockId;

/* DRAWBUFFERS:02 */
void main() {
    // 纹理 * 颜色
    vec4 blockColor = texture2D(texture, texcoord.st);
    blockColor.rgb *= color;

    // 光照
    vec3 light = texture2D(lightmap, lightMapCoord.st).rgb; 
    blockColor.rgb *= light;

    gl_FragData[0] = blockColor;
    gl_FragData[1] = vec4(blockId);
}