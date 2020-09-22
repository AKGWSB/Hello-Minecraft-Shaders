#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;

varying vec4 texcoord;

void main() {
    vec4 color = texture2D(colortex0, texcoord.st);
    vec4 bloom = texture2D(colortex1, texcoord.st);

    color.rgb += bloom.rgb;

    gl_FragData[0] = color;
}