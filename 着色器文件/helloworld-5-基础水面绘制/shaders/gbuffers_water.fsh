#version 120

const int noiseTextureResolution = 128;

uniform mat4 gbufferModelViewInverse;

uniform sampler2D texture;
uniform sampler2D noisetex;

uniform vec3 cameraPosition;

uniform int worldTime;

varying float id;

varying vec3 mySkyColor;
varying vec3 normal;    // 法向量在眼坐标系下

varying vec4 texcoord;
varying vec4 color;
varying vec4 positionInViewCoord;   // 眼坐标

/*
 *  @function getWave           : 绘制水面纹理
 *  @param color                : 原水面颜色
 *  @param positionInWorldCoord : 世界坐标（绝对坐标）
 *  @return                     : 叠加纹理后的颜色
 */
vec3 getWave(vec3 color, vec4 positionInWorldCoord) {

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

    // 绘制 “纹理”
    color *= noise2 * 0.6 + 0.4;    // 64开调整颜色亮度

    return color;
}

void main() {
    
    // 计算 "世界坐标"
    vec4 positionInWorldCoord = gbufferModelViewInverse * positionInViewCoord;   // “我的世界坐标”
    positionInWorldCoord.xyz += cameraPosition; // 转为世界坐标（绝对坐标）

    // 绘制明暗相间的水面波浪纹理
    vec3 finalColor = mySkyColor;
    finalColor = getWave(mySkyColor, positionInWorldCoord);

    // 计算视线和法线夹角余弦值
    float cosine = dot(normalize(positionInViewCoord.xyz), normalize(normal));
    cosine = clamp(abs(cosine), 0, 1);
    float factor = pow(1.0 - cosine, 4);    // 透射系数

    // 不是水面则正常绘制
    if(id!=10091) {
        gl_FragData[0] = color * texture2D(texture, texcoord.st);
        return;
    }
    // 是水面则绘制自定义颜色
    gl_FragData[0] = vec4(mix(mySkyColor*0.3, finalColor, factor), 0.75);
}