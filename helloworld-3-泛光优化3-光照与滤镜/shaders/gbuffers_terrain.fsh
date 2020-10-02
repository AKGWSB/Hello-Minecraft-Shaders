#version 120

// 声明2号颜色缓冲区为 R32F 格式 只有x通道可用 传递方块id
const int R32F = 114;
const int colortex2Format = R32F;

uniform sampler2D texture;
uniform sampler2D lightmap;

uniform int worldTime;

varying vec4 texcoord;
varying vec4 lightMapCoord;
varying vec3 color;
varying float blockId;

const float isNightArray[24] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
};

/* DRAWBUFFERS:023 */
void main() {

    // 昼夜交替插值
    int hour = worldTime/1000;
    float cur = isNightArray[hour];
    float next = isNightArray[(hour+1<24)?(hour+1):(0)];
    float delta = float(worldTime-hour*1000)/1000;
    float isNight = mix(cur, next, delta);

    // 纹理 * 颜色
    vec4 blockColor = texture2D(texture, texcoord.st);
    blockColor.rgb *= color;

    // 光照
    float lightTorch = lightMapCoord.x * 0.4;
    // 如果是发光物体则不收光照影响
    if(blockId>=10089) {
        lightTorch /= 0.4;
    }
    // 环境光照
    float lightSky = lightMapCoord.y;
    lightSky = pow(lightSky, 2);
    /*
    if(worldTime>13000) {
        lightSky *= 0.15;   // 夜晚
    }
    */
    lightSky *= (1-isNight*0.85);
    blockColor.rgb *= max(lightTorch, lightSky);

    gl_FragData[0] = blockColor;
    gl_FragData[1] = vec4(blockId);
    gl_FragData[2] = vec4(isNight, 0, 0, 0);
}