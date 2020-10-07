#version 120

uniform int worldTime;
uniform float rainStrength;

varying float isNight;

varying vec3 mySkyColor;
varying vec3 mySunColor;
varying vec4 texcoord;

vec3 sunColorArr[24] = {
    vec3(2, 2, 1),      // 0-1000
    vec3(2, 1.5, 1),    // 1000 - 2000
    vec3(1, 1, 1),      // 2000 - 3000
    vec3(1, 1, 1),      // 3000 - 4000
    vec3(1, 1, 1),      // 4000 - 5000 
    vec3(1, 1, 1),      // 5000 - 6000
    vec3(1, 1, 1),      // 6000 - 7000
    vec3(1, 1, 1),      // 7000 - 8000
    vec3(1, 1, 1),      // 8000 - 9000
    vec3(1, 1, 1),      // 9000 - 10000
    vec3(1, 1, 1),      // 10000 - 11000
    vec3(1, 1, 1),      // 11000 - 12000
    vec3(2, 1.5, 0.5),      // 12000 - 13000
    vec3(0.3, 0.5, 0.9),      // 13000 - 14000
    vec3(0.3, 0.5, 0.9),      // 14000 - 15000
    vec3(0.3, 0.5, 0.9),      // 15000 - 16000
    vec3(0.3, 0.5, 0.9),      // 16000 - 17000
    vec3(0.3, 0.5, 0.9),      // 17000 - 18000
    vec3(0.3, 0.5, 0.9),      // 18000 - 19000
    vec3(0.3, 0.5, 0.9),      // 19000 - 20000
    vec3(0.3, 0.5, 0.9),      // 20000 - 21000
    vec3(0.3, 0.5, 0.9),      // 21000 - 22000
    vec3(0.3, 0.5, 0.9),      // 22000 - 23000
    vec3(0.3, 0.5, 0.9)       // 23000 - 24000(0)
};

vec3 skyColorArr[24] = {
    vec3(0.1, 0.6, 0.9),        // 0-1000
    vec3(0.1, 0.6, 0.9),        // 1000 - 2000
    vec3(0.1, 0.6, 0.9),        // 2000 - 3000
    vec3(0.1, 0.6, 0.9),        // 3000 - 4000
    vec3(0.1, 0.6, 0.9),        // 4000 - 5000 
    vec3(0.1, 0.6, 0.9),        // 5000 - 6000
    vec3(0.1, 0.6, 0.9),        // 6000 - 7000
    vec3(0.1, 0.6, 0.9),        // 7000 - 8000
    vec3(0.1, 0.6, 0.9),        // 8000 - 9000
    vec3(0.1, 0.6, 0.9),        // 9000 - 10000
    vec3(0.1, 0.6, 0.9),        // 10000 - 11000
    vec3(0.1, 0.6, 0.9),        // 11000 - 12000
    vec3(0.1, 0.6, 0.9),        // 12000 - 13000
    vec3(0.02, 0.2, 0.27),      // 13000 - 14000
    vec3(0.02, 0.2, 0.27),      // 14000 - 15000
    vec3(0.02, 0.2, 0.27),      // 15000 - 16000
    vec3(0.02, 0.2, 0.27),      // 16000 - 17000
    vec3(0.02, 0.2, 0.27),      // 17000 - 18000
    vec3(0.02, 0.2, 0.27),      // 18000 - 19000
    vec3(0.02, 0.2, 0.27),      // 19000 - 20000
    vec3(0.02, 0.2, 0.27),      // 20000 - 21000
    vec3(0.02, 0.2, 0.27),      // 21000 - 22000
    vec3(0.02, 0.2, 0.27),      // 22000 - 23000
    vec3(0.02, 0.2, 0.27)       // 23000 - 24000(0)
};

void main() {

    // 颜色过渡插值
	int hour = worldTime/1000;
    int next = (hour+1<24)?(hour+1):(0);
    float delta = float(worldTime-hour*1000)/1000;
	// 天空颜色
    mySkyColor = mix(skyColorArr[hour], skyColorArr[next], delta);
    // 太阳颜色
    mySunColor = mix(sunColorArr[hour], sunColorArr[next], delta);

    // 昼夜交替插值
    isNight = 0;  // 白天
    if(12000<worldTime && worldTime<13000) {
        isNight = 1.0 - (13000-worldTime) / 1000.0; // 傍晚
    }
    else if(13000<=worldTime && worldTime<=23000) {
        isNight = 1.0;    // 晚上
    }
    else if(23000<worldTime) {
        isNight = (24000-worldTime) / 1000.0;   // 拂晓
    }

    // 天气渐变
    //mySkyColor = mix(mySkyColor, vec3(0.7, 0.7, 0.8) * (1-isNight*0.7), rainStrength);
    //mySunColor = mix(mySunColor, vec3(0.7, 0.7, 0.8) * (1-isNight*0.5), rainStrength);

    gl_Position = ftransform();
    texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}