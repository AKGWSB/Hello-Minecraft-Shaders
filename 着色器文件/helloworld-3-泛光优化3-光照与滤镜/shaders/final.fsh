#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform ivec2 eyeBrightnessSmooth;

varying vec4 texcoord;

/* 
 *  @function getScaleInverse : 得到缩放采样后的图像
 *  @param src                : 源纹理
 *  @param pos                : 屏幕坐标 xy 轴
 *  @param anchor             : 缩放图像存储位置 -- 左下角坐标
 *  @param fact               : 缩放比例为 2^fact 倍
 *  @return                   : 从缩放中还原的像素值
 */
vec4 getScaleInverse(sampler2D src, vec2 pos, vec2 anchor, int fact) {
    return texture2D(src, pos/pow(2, fact)+anchor);
}

/*
 *  @function ACESToneMapping : 色调映射
 *  @param color              : 原颜色
 *  @param adapted_lum        : 亮度调整因子
 *  @return                   : 色调映射之后的值
 *  @explain                  : 感谢知乎大佬：@叛逆者
 *                            : 源码地址 https://zhuanlan.zhihu.com/p/21983679
 */
vec3 ACESToneMapping(vec3 color, float adapted_lum) {
	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;
	color *= adapted_lum;
	return (color * (A * color + B)) / (color * (C * color + D) + E);
}

/*
 *  @function saturation : 饱和度调整
 *  @param color         : 原颜色
 *  @param factor        : 调整因子范围 [0~无穷] 饱和度升高
 */ 
vec3 saturation(vec3 color, float factor) {
    float brightness = dot(color, vec3(0.2125, 0.7154, 0.0721));
    return mix(vec3(brightness), color, factor);
}

/*
 *  @function exposure : 曝光调节
 *  @param color       : 原颜色
 *  @param factor      : 调整因子 范围 0~1
 *  @explain           : factor越大则暗处越亮
 */ 
vec3 exposure(vec3 color, float factor) {
    float skylight = float(eyeBrightnessSmooth.y)/240;
    skylight = pow(skylight, 6.0) * factor + (1.0f-factor);
    return color / skylight;
}

void main() {
    vec4 color = texture2D(colortex0, texcoord.st);

    // 计算泛光
    vec4 bloom = vec4(vec3(0), 1);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.0, 0.2), 2).rgb * 1.2;
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.3, 0.2), 3).rgb * 1.3;
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.5, 0.2), 4).rgb * 1.4;
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.6, 0.2), 5).rgb * 1.5;
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.7, 0.2), 6).rgb * 1.6;
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.8, 0.2), 7).rgb * 1.7;
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.9, 0.2), 8).rgb * 1.8;
    color.rgb = mix(color.rgb, bloom.rgb, 0.05);

    // 曝光调节
    color.rgb = exposure(color.rgb, 0.7);

    // 色调映射
    color.rgb = ACESToneMapping(color.rgb, 1);

    // 饱和度
    color.rgb = saturation(color.rgb, 1.5);

    gl_FragData[0] = color;
}