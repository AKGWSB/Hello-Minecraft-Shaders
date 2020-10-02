#version 120

const int shadowMapResolution = 1024;   // 阴影分辨率 默认 1024
const float	sunPathRotation	= -40.0;    // 太阳偏移角 默认 0

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D shadow;
uniform sampler2D gdepth;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform ivec2 eyeBrightnessSmooth;

uniform float far;
uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

varying vec4 texcoord;

vec2 getFishEyeCoord(vec2 positionInNdcCoord) {
    return positionInNdcCoord / (0.15 + 0.85*length(positionInNdcCoord.xy));
}

/*
 * @function getShadow         : getShadow 渲染阴影
 * @param color                : 原始颜色
 * @param positionInWorldCoord : 该点在世界坐标系下的坐标
 * @return                     : 渲染阴影之后的颜色
 */
vec4 getShadow(vec4 color, vec4 positionInWorldCoord) {

    // 我的世界坐标 转 太阳的眼坐标
    vec4 positionInSunViewCoord = shadowModelView * positionInWorldCoord;
    // 太阳的眼坐标 转 太阳的裁剪坐标
    vec4 positionInSunClipCoord = shadowProjection * positionInSunViewCoord;
    // 太阳的裁剪坐标 转 太阳的ndc坐标
    vec4 positionInSunNdcCoord = vec4(positionInSunClipCoord.xyz/positionInSunClipCoord.w, 1.0);

    positionInSunNdcCoord.xy = getFishEyeCoord(positionInSunNdcCoord.xy);

    // 太阳的ndc坐标 转 太阳的屏幕坐标
    vec4 positionInSunScreenCoord = positionInSunNdcCoord * 0.5 + 0.5;

    float currentDepth = positionInSunScreenCoord.z;    // 当前点的深度
    float dis = length(positionInWorldCoord.xyz) / far;

    /*
    float closest = texture2D(shadow, positionInSunScreenCoord.xy).x; 
    // 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
    if(closest+0.0001 <= currentDepth && dis<0.99) {
        color.rgb *= 0.5;   // 涂黑
    }
    */

    float isNight = texture2D(colortex3, texcoord.st).x; 
    
    int radius = 1;
    float sum = pow(radius*2+1, 2);
    float shadowStrength = 0.6 * (1-dis) * (1-0.6*isNight);
    for(int x=-radius; x<=radius; x++) {
        for(int y=-radius; y<=radius; y++) {
            // 采样偏移
            vec2 offset = vec2(x,y) / shadowMapResolution;
            // 光照图中最近的点的深度
            float closest = texture2D(shadow, positionInSunScreenCoord.xy + offset).x;   
            // 如果当前点深度大于光照图中最近的点的深度 说明当前点在阴影中
            if(closest+0.001 <= currentDepth && dis<0.99) {
                sum -= 1; // 涂黑
            }
        }
    }
    sum /= pow(radius*2+1, 2);
    color.rgb *= sum*shadowStrength + (1-shadowStrength);  
    

    return color;
}

/* 
 *  @function getBloomOriginColor : 亮色筛选
 *  @param color                  : 原始像素颜色
 *  @return                       : 筛选后的颜色
 */
vec4 getBloomOriginColor(vec4 color) {
    float brightness = 0.299*color.r + 0.587*color.g + 0.114*color.b;
    if(brightness < 0.5) {
        color.rgb = vec3(0);
    }
    color.rgb *= (brightness-0.5)*2;
    return color;
}

/* 
 *  @function getBloom : 亮色筛选
 *  @return            : 泛光颜色
 */
vec3 getBloom() {
    int radius = 15;
    vec3 sum = vec3(0);
    
    for(int i=-radius; i<=radius; i++) {
        for(int j=-radius; j<=radius; j++) {
            vec2 offset = vec2(i/viewWidth, j/viewHeight);
            sum += getBloomOriginColor(texture2D(texture, texcoord.st+offset)).rgb;
        }
    }
    
    sum /= pow(radius+1, 2);
    return sum*0.3;
}

vec4 getBloomSource(vec4 color) {
    // 绘制泛光
    vec4 bloom = color;
    float id = texture2D(colortex2, texcoord.st).x;
    float brightness = dot(bloom.rgb, vec3(0.2125, 0.7154, 0.0721));
    // 发光方块
    if(id==10089) {
        bloom.rgb *= 7 * vec3(2, 1, 1);
    }
    // 火把 
    else if(id==10090) {
        if(brightness<0.5) {
            bloom.rgb = vec3(0);
        }
        bloom.rgb *= 14 * pow(brightness, 2);
    }
    // 其他 
    else {
        //bloom.rgb *= brightness;
        //bloom.rgb = pow(bloom.rgb, vec3(1.0/2.2)) * 0.5;
    }
    return bloom;
}

/* DRAWBUFFERS: 01 */
void main() {
    //vec4 color = texture2D(shadow, texcoord.st);
    vec4 color = texture2D(texture, texcoord.st);

    float depth = texture2D(depthtex0, texcoord.st).x;
    
    // 利用深度缓冲建立带深度的ndc坐标
    vec4 positionInNdcCoord = vec4(texcoord.st*2-1, depth*2-1, 1);

    // 逆投影变换 -- ndc坐标转到裁剪坐标
    vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;

    // 透视除法 -- 裁剪坐标转到眼坐标
    vec4 positionInViewCoord = vec4(positionInClipCoord.xyz/positionInClipCoord.w, 1.0);

    // 逆 “视图模型” 变换 -- 眼坐标转 “我的世界坐标” 
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;

    // 计算泛光 -- 弃用
    //color.rgb += getBloom();

    // 不是发光方块则绘制阴影
    float id = texture2D(colortex2, texcoord.st).x;
    if(id!=10089 && id!=10090) {
        color = getShadow(color, positionInWorldCoord);
    }

    gl_FragData[0] = color; // 基色
    gl_FragData[1] = getBloomSource(color); // 传递泛光原图
}