#version 120

uniform sampler2D texture;

uniform vec3 cameraPosition;

uniform int worldTime;

varying float id;

varying vec3 normal;    // 法向量在眼坐标系下

varying vec4 texcoord;
varying vec4 color;

/* DRAWBUFFERS: 03 */
void main() {
    if(id!=10091) {
        gl_FragData[0] = color * texture2D(texture, texcoord.st);   // 不是水面则正常绘制纹理
    } else {
        gl_FragData[0] = vec4(vec3(0.05, 0.1, 0.2), 0.5);   // 基色
    }
    gl_FragData[1] = vec4(normal*0.5+0.5, 1);   // 法线
}