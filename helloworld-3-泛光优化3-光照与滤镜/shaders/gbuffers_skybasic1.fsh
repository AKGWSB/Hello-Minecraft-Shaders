#version 120

uniform sampler2D texture;
uniform sampler2D colortex3;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform float viewHeight;
uniform float viewWidth;

varying vec4 color;
varying vec4 texcoord;

void main() {
	vec3 skyTexture = texture2D(texture, texcoord.st).rgb;
	//skyTexture
	gl_FragData[0] = vec4(vec3(0.3, 0.4, 0.9), 1.0); 
}