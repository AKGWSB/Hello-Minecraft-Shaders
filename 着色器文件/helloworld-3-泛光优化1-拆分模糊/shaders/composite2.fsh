#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;

uniform float viewWidth;
uniform float viewHeight;

varying vec4 texcoord;

/* DRAWBUFFERS: 01 */
void main() {
    // 传递基色
    vec4 color = texture2D(colortex0, texcoord.st);
    gl_FragData[0] = color;

    // 横向模糊
    int radius = 15;
    vec3 sum = texture2D(colortex1, texcoord.st).rgb;
    for(int i=1; i<radius; i++) {
        vec2 offset = vec2(0, i/viewHeight);
        sum += texture2D(colortex1, texcoord.st+offset).rgb;
        sum += texture2D(colortex1, texcoord.st-offset).rgb;
    }
    sum /= (2*radius+1);
    gl_FragData[1] = vec4(sum, 1.0);
}