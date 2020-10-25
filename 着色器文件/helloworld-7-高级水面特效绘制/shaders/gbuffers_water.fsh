#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

uniform vec3 cameraPosition;

uniform int worldTime;

varying float id;

varying vec3 normal;    // 法向量在眼坐标系下

varying vec4 texcoord;
varying vec4 color;
varying vec4 lightMapCoord;

/* DRAWBUFFERS: 04 */
void main() {
    vec4 light = texture2D(lightmap, lightMapCoord.st); // 光照
    if(id!=10091) {
        gl_FragData[0] = color * texture2D(texture, texcoord.st) * light;   // 不是水面则正常绘制纹理
        gl_FragData[1] = vec4(normal*0.5+0.5, 0.5);   // 法线
    } else {    // 是水面则输出 vec3(0.05, 0.2, 0.3)
        gl_FragData[0] = vec4(vec3(0.05, 0.2, 0.3), 0.5) * light;   // 基色
        gl_FragData[1] = vec4(normal*0.5+0.5, 1);   // 法线
    }
}