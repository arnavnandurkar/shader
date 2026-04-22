#version 330 compatibility

out vec2 lmcoord;
out vec2 texcoord;
out vec3 normal;
out vec4 glcolor;

uniform mat4 gbufferModelViewInverse;
uniform int worldTime;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

normal = gl_NormalMatrix * gl_Normal;
normal = mat3(gbufferModelViewInverse) * normal;
}