#version 120

const int shadowMapResolution = 1024;   // 阴影分辨率 默认 1024
const float	sunPathRotation	= -40.0;    // 太阳偏移角 默认 0
const int noiseTextureResolution = 128;     // 噪声图分辨率

uniform sampler2D texture;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadow;
uniform sampler2D shadowtex1;
uniform sampler2D gdepth;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D noisetex;

uniform ivec2 eyeBrightnessSmooth;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;

uniform float near;
uniform float far;  
uniform float viewWidth;
uniform float viewHeight;

uniform int worldTime;
uniform int isEyeInWater;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

varying float isNight;

varying vec3 mySkyColor;
varying vec3 mySunColor;
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
vec4 getShadow(vec4 color, vec4 positionInWorldCoord, float strength) {

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
    
    int radius = 1;
    float sum = pow(radius*2+1, 2);
    float shadowStrength = strength * 0.6 * (1-dis) * (1-0.6*isNight); // 控制昼夜阴影强度
    for(int x=-radius; x<=radius; x++) {
        for(int y=-radius; y<=radius; y++) {
            // 采样偏移
            vec2 offset = vec2(x,y) / shadowMapResolution;
            // 光照图中最近的点的深度
            float closest = texture2D(shadowtex1, positionInSunScreenCoord.xy + offset).x;   
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

/*
 *  @function getBloomSource : 获取泛光原始图像
 *  @param color             : 原图像
 *  @return                  : 提取后的泛光图像
 */
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
        bloom.rgb *= 24 * pow(brightness, 2);
    }
    // 其他方块
    else {
        bloom.rgb *= brightness;
        //bloom.rgb = pow(bloom.rgb, vec3(1.0/2.2));
        //bloom.rgb = pow(bloom.rgb*4 * pow(brightness, 2), vec3(1.0/2.2));
    }
    return bloom;
}

/*
 *  @function drawSky           : 天空绘制
 *  @param color                : 原始颜色
 *  @param positionInViewCoord  : 眼坐标
 *  @param positionInWorldCoord : 我的世界坐标
 *  @return                     : 绘制天空后的颜色
 */
vec3 drawSky(vec3 color, vec4 positionInViewCoord, vec4 positionInWorldCoord) {

    // 距离
    float dis = length(positionInWorldCoord.xyz) / far;

    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005 && dis>0.99999) {
        drawSun = mySunColor * 2 * (1.0-isNight);
    }
    // 绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005 && dis>0.99999) {
        drawMoon = mySunColor * 2 * isNight;
    }
    
    // 雾和太阳颜色混合
    float sunMixFactor = clamp(1.0 - disToSun, 0, 1) * (1.0-isNight);
    vec3 finalColor = mix(mySkyColor, mySunColor, pow(sunMixFactor, 4));

    // 雾和月亮颜色混合
    float moonMixFactor = clamp(1.0 - disToMoon, 0, 1) * isNight;
    finalColor = mix(finalColor, mySunColor, pow(moonMixFactor, 4));

    // 根据距离进行最终颜色的混合
    return mix(color, finalColor, clamp(pow(dis, 3), 0, 1)) + drawSun + drawMoon;
}

vec3 drawSkyFakeReflect(vec4 positionInViewCoord) {
    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 雾和太阳颜色混合
    float sunMixFactor = clamp(1.0 - disToSun, 0, 1) * (1.0-isNight);
    vec3 finalColor = mix(mySkyColor, mySunColor, pow(sunMixFactor, 4));

    // 雾和月亮颜色混合
    float moonMixFactor = clamp(1.0 - disToMoon, 0, 1) * isNight;
    finalColor = mix(finalColor, mySunColor, pow(moonMixFactor, 4));

    return finalColor;
}

vec3 drawSkyFakeSun(vec4 positionInViewCoord) {
    // 眼坐标系中的点到太阳的距离
    float disToSun = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(sunPosition));     // 太阳
    float disToMoon = 1.0 - dot(normalize(positionInViewCoord.xyz), normalize(moonPosition));    // 月亮

    // 绘制圆形太阳
    vec3 drawSun = vec3(0);
    if(disToSun<0.005) {
        drawSun = mySunColor * 2 * (1.0-isNight);
    }
    // 绘制圆形月亮
    vec3 drawMoon = vec3(0);
    if(disToMoon<0.005) {
        drawMoon = mySunColor * 2 * isNight;
    }

    return drawSun + drawMoon;   
}

/*
 *  @function getWave           : 绘制水面纹理
 *  @param positionInWorldCoord : 世界坐标（绝对坐标）
 *  @return                     : 纹理亮暗系数
 */
float getWave(vec4 positionInWorldCoord) {

    // 小波浪
    float speed1 = float(worldTime) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 3;
    coord1.x += speed1;
    coord1.z += speed1 * 0.2;
    float noise1 = texture2D(noisetex, coord1.xz).x;

    // 混合波浪
    float speed2 = float(worldTime) / (noiseTextureResolution * 7);
    vec3 coord2 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord2.x *= 0.5;
    coord2.x -= speed2 * 0.15 + noise1 * 0.05;  // 加入第一个波浪的噪声
    coord2.z -= speed2 * 0.7 - noise1 * 0.05;
    float noise2 = texture2D(noisetex, coord2.xz).x;

    return noise2 * 0.6 + 0.4;

    // 绘制 “纹理”
    //color *= noise2 * 0.6 + 0.4;    // 64开调整颜色亮度

    //return color;
}

/*
 *  @function drawWaterBasic    : 基础水面绘制
 *  @param color                : 原颜色
 *  @param positionInWorldCoord : 我的世界坐标
 *  @param positionInViewCoord  : 眼坐标
 *  @param normal               : 眼坐标系下的法线
 *  @return                     : 绘制水面后的颜色
 *  @explain                    : 因为我太猪B了才会想到在gbuffers_water着色器中绘制水面 导致后续很难继续编程 我爬
 */
vec3 drawWaterBasic(vec3 color, vec4 positionInWorldCoord, vec4 positionInViewCoord, vec3 normal) {
    positionInWorldCoord.xyz += cameraPosition; // 转为世界坐标（绝对坐标）

    // 波浪系数
    float wave = getWave(positionInWorldCoord);
    vec3 finalColor = mySkyColor;
    finalColor *= wave; // 波浪纹理

    /*
    // 按照波浪对法线进行偏移
    vec4 normalInWorldCoord = gbufferModelViewInverse * vec4(normal, 0);
    normalInWorldCoord.x += 0.2 * (wave-0.4);
    vec3 newNormal = normalize((gbufferModelView * normalInWorldCoord).xyz);
    vec3 reflectDirection = reflect(positionInViewCoord.xyz, newNormal);    // 计算反射光线方向

    vec3 finalColor = drawSkyFakeReflect(vec4(reflectDirection, 0)); // 假反射 -- 天空颜色
    finalColor *= wave; // 波浪纹理
    */

    // 透射
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));  // 计算视线和法线夹角余弦值
    cosine = clamp(abs(cosine), 0, 1);
    float factor = pow(1.0 - cosine, 4);    // 透射系数
    finalColor = mix(color, finalColor, factor);    // 透射计算

    /*
    // 假反射 -- 太阳
    finalColor += drawSkyFakeSun(vec4(reflectDirection, 0)); 
    */   

    return finalColor;
}

/*
 *  @function screenDepthToLinerDepth   : 深度缓冲转线性深度
 *  @param screenDepth                  : 深度缓冲中的深度
 *  @return                             : 真实深度 -- 以格为单位
 */
float screenDepthToLinerDepth(float screenDepth) {
    return 2 * near * far / ((far + near) - screenDepth * (far - near));
}

/*
 *  @function getUnderWaterFadeOut  : 计算水下淡出系数
 *  @param d0                       : 深度缓冲0中的原始数值
 *  @param d1                       : 深度缓冲1中的原始数值
 *  @param positionInViewCoord      : 眼坐标包不包含水面均可，因为我们将其当作视线方向向量
 *  @param normal                   : 眼坐标系下的法线
 *  @return                         : 淡出系数
 */
float getUnderWaterFadeOut(float d0, float d1, vec4 positionInViewCoord, vec3 normal) {
    // 转线性深度
    d0 = screenDepthToLinerDepth(d0);
    d1 = screenDepthToLinerDepth(d1);

    // 计算视线和法线夹角余弦值
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));
    cosine = clamp(abs(cosine), 0, 1);

    return clamp(1.0 - (d1 - d0) * cosine * 0.1, 0, 1);
}

/*
 *  @function getCaustics       : 获取焦散亮度缩放倍数
 *  @param positionInWorldCoord : 当前点在 “我的世界坐标系” 下的坐标
 *  @return                     : 焦散亮暗斑纹的亮度增益
 */
float getCaustics(vec4 positionInWorldCoord) {
    positionInWorldCoord.xyz += cameraPosition; // 转为世界坐标（绝对坐标）

    // 波纹1
    float speed1 = float(worldTime) / (noiseTextureResolution * 15);
    vec3 coord1 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord1.x *= 4;
    coord1.x += speed1*2 + coord1.z;
    coord1.z -= speed1;
    float noise1 = texture2D(noisetex, coord1.xz).x;
    noise1 = noise1*2 - 1.0;

    // 波纹2
    float speed2 =  float(worldTime) / (noiseTextureResolution * 15);
    vec3 coord2 = positionInWorldCoord.xyz / noiseTextureResolution;
    coord2.z *= 4;
    coord2.z += speed2*2 + coord2.x;
    coord2.x -= speed2;
    float noise2 = texture2D(noisetex, coord2.xz).x;
    noise2 = noise2*2 - 1.0;

    return noise1 + noise2; // 叠加
}

/* DRAWBUFFERS: 01 */
void main() {

    /*
    float depth = texture2D(depthtex0, texcoord.st).x;
    // 利用深度缓冲建立带深度的ndc坐标
    vec4 positionInNdcCoord = vec4(texcoord.st*2-1, depth*2-1, 1);
    // 逆投影变换 -- ndc坐标转到裁剪坐标
    vec4 positionInClipCoord = gbufferProjectionInverse * positionInNdcCoord;
    // 透视除法 -- 裁剪坐标转到眼坐标
    vec4 positionInViewCoord = vec4(positionInClipCoord.xyz/positionInClipCoord.w, 1.0);
    // 逆 “视图模型” 变换 -- 眼坐标转 “我的世界坐标” 
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;
    */

    // 带水面方块的坐标转换
    float depth0 = texture2D(depthtex0, texcoord.st).x;
    vec4 positionInNdcCoord0 = vec4(texcoord.st*2-1, depth0*2-1, 1);
    vec4 positionInClipCoord0 = gbufferProjectionInverse * positionInNdcCoord0;
    vec4 positionInViewCoord0 = vec4(positionInClipCoord0.xyz/positionInClipCoord0.w, 1.0);
    vec4 positionInWorldCoord0 = gbufferModelViewInverse * positionInViewCoord0;

    // 不带水面方块的坐标转换
    float depth1 = texture2D(depthtex1, texcoord.st).x;
    vec4 positionInNdcCoord1 = vec4(texcoord.st*2-1, depth1*2-1, 1);
    vec4 positionInClipCoord1 = gbufferProjectionInverse * positionInNdcCoord1;
    vec4 positionInViewCoord1 = vec4(positionInClipCoord1.xyz/positionInClipCoord1.w, 1.0);
    vec4 positionInWorldCoord1 = gbufferModelViewInverse * positionInViewCoord1;

    // 计算泛光 -- 弃用
    //color.rgb += getBloom();

    vec4 color = texture2D(texture, texcoord.st);
    float id = texture2D(colortex2, texcoord.st).x;
    vec4 temp = texture2D(colortex3, texcoord.st);
    vec3 normal = temp.xyz * 2 - 1;
    float isWater = temp.w;
    bool isInWater = (depth1>depth0)?(true):(false);    // 当前像素是否在水下
    float underWaterFadeOut = getUnderWaterFadeOut(depth0, depth1, positionInViewCoord0, normal);   // 水下淡出系数

    // 不是发光方块则绘制阴影
    if(id!=10089 && id!=10090) {
        color = getShadow(color, positionInWorldCoord1, underWaterFadeOut);
    }

    // 天空绘制
    color.rgb = drawSky(color.rgb, positionInViewCoord0, positionInWorldCoord0);

    // 焦散
    float caustics = getCaustics(positionInWorldCoord1);    // 亮暗参数  
    // 如果在水下则计算焦散
    if(isInWater || isEyeInWater==1) {
        color.rgb *= 1.0 + caustics*0.25 * underWaterFadeOut;
    }
    
    // 基础水面绘制
    if(isWater) {
        color.rgb = drawWaterBasic(color.rgb, positionInWorldCoord0, positionInViewCoord0, normal);
    }

    gl_FragData[0] = color; // 基色
    gl_FragData[1] = getBloomSource(color); // 传递泛光原图
}