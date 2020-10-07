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

/* DRAWBUFFERS:02 */
void main() {

    /*
    // 昼夜交替插值
    int hour = worldTime/1000;
    float cur = isNightArray[hour];
    float next = isNightArray[(hour+1<24)?(hour+1):(0)];
    float delta = float(worldTime-hour*1000)/1000;
    float isNight = mix(cur, next, delta);
    */
    float isNight = 0;  // 白天
    if(12000<worldTime && worldTime<13000) {
        isNight = 1.0 - (13000-worldTime) / 1000.0; // 傍晚
    }
    else if(13000<=worldTime && worldTime<=23000) {
        isNight = 1.0;    // 晚上
    }
    else if(23000<worldTime) {
        isNight = (24000-worldTime) / 1000.0;   // 拂晓
    }
    

    // 纹理 * 颜色
    vec4 blockColor = texture2D(texture, texcoord.st);
    blockColor.rgb *= color;

    // 人造光源光照
    float lightTorch = lightMapCoord.x * 0.4;
    // 如果是发光物体则不受光照影响
    if(blockId>=10089) {
        lightTorch /= 0.4;
    }
    // 环境光照
    float lightSky = lightMapCoord.y;
    lightSky = pow(lightSky, 2);
    lightSky *= (1-isNight*0.8);   // 夜晚则减弱
    // 光照混合--取最大值
    blockColor.rgb *= max(lightTorch, lightSky);

    /*
    if(blockId == 10091) {
        blockColor.rgb = vec3(0);
    }
    */

    gl_FragData[0] = blockColor;
    gl_FragData[1] = vec4(blockId);
}