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

void main() {
    vec4 color = texture2D(colortex0, texcoord.st);

    vec4 bloom = vec4(vec3(0), 1);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.0, 0), 2).rgb * pow(7, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.3, 0), 3).rgb * pow(6, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.5, 0), 4).rgb * pow(5, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.6, 0), 5).rgb * pow(4, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.7, 0), 6).rgb * pow(3, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.8, 0), 7).rgb * pow(2, 0.25);
    bloom.rgb += getScaleInverse(colortex1, texcoord.st, vec2(0.9, 0), 8).rgb * pow(1, 0.25);

    bloom.rgb = pow(bloom.rgb, vec3(1/2.2));
    
    color.rgb += bloom.rgb * 0.5;

    gl_FragData[0] = color;
}